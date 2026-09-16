import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/global_state.dart';
import '../utils/app_logger.dart';

/// النتيجة المحتملة لعملية حذف الحساب
class DeleteAccountResult {
  final bool success;
  final bool isActiveTrip;
  final String message;
  final String? scope;

  const DeleteAccountResult({
    required this.success,
    this.isActiveTrip = false,
    required this.message,
    this.scope,
  });
}

/// خدمة حذف الحساب المستقلة وتفريغ البيانات (DeleteAccountService)
/// تدعم الحذف المتخصص (كابتن فقط، راكب فقط، أو الحساب بالكامل) وتوثيق الداشبورد
class DeleteAccountService {
  DeleteAccountService._internal();
  static final DeleteAccountService instance = DeleteAccountService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isDeleting = false;

  /// إرجاع ما إذا كانت عملية الحذف جارية الآن لمنع التنفيذ المزدوج
  bool get isDeleting => _isDeleting;

  /// التحقق مما إذا كان لدى المستخدم رحلة نشطة حالياً
  Future<bool> hasActiveTrip(String userId) async {
    // 1. فحص حالة الرحلة المحلية في GlobalState
    final state = GlobalState.instance;
    final isLocalActive = state.rideStatus == RideStatus.searching ||
        state.rideStatus == RideStatus.driverBidding ||
        state.rideStatus == RideStatus.driverOnWay ||
        state.rideStatus == RideStatus.arrived ||
        state.rideStatus == RideStatus.tripStarted;

    if (isLocalActive) {
      return true;
    }

    // 2. الاستعلام المباشر من قاعدة بيانات Supabase في جدول ride_requests
    try {
      final activeStatuses = [
        'pending',
        'searching',
        'bidding',
        'driver_bidding',
        'accepted',
        'driver_on_way',
        'arrived',
        'in_progress',
        'trip_started'
      ];

      final response = await _supabase
          .from('ride_requests')
          .select('id, status')
          .or('passenger_id.eq.$userId,driver_id.eq.$userId')
          .filter('status', 'in', activeStatuses)
          .maybeSingle();

      if (response != null) {
        return true;
      }
    } catch (e) {
      debugPrint('[DeleteAccountService] Error checking active trips: $e');
    }

    return false;
  }

  /// فحص ما إذا كان المستخدم يمتلك حساب كابتن مسجل أو معتمد
  Future<bool> hasDriverAccount() async {
    final state = GlobalState.instance;
    if (state.verificationStatus == DriverVerificationStatus.verified ||
        state.verificationStatus == DriverVerificationStatus.submitted ||
        state.currentRole == UserRole.driver) {
      return true;
    }

    final userId = state.userUid ?? _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final dRes = await _supabase
          .from('drivers')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      return dRes != null;
    } catch (_) {
      return false;
    }
  }

  /// تنفيذ عملية حذف الحساب والبيانات التابعة له بشكل احترافي وآمن
  /// [scope]: 'driver' (كابتن فقط) | 'rider' (راكب فقط) | 'both' (الحساب بالكامل)
  Future<DeleteAccountResult> deleteAccount({
    required bool isArabic,
    String scope = 'both',
    String? reason,
  }) async {
    // 1. منع تنفيذ الحذف أكثر من مرة في نفس الوقت
    if (_isDeleting) {
      return DeleteAccountResult(
        success: false,
        message: isArabic
            ? 'جاري تنفيذ طلب حذف الحساب بالفعل، يرجى الانتظار...'
            : 'Account deletion is already in progress, please wait...',
      );
    }

    _isDeleting = true;
    final userId = GlobalState.instance.userUid ?? _supabase.auth.currentUser?.id;

    if (userId == null || userId.isEmpty) {
      _isDeleting = false;
      return DeleteAccountResult(
        success: false,
        message: isArabic
            ? 'تعذر العثور على هوية المستخدم. يرجى إعادة تسجيل الدخول والتجربة مجدداً.'
            : 'User ID not found. Please sign in again and retry.',
      );
    }

    try {
      AppLogger.rideLog('DeleteAccount', 'Starting account deletion procedure (scope: $scope) for user', passengerId: userId);

      // 2. التحقق من وجود رحلة جارية ومنع الحذف إذا وجدت
      final activeTrip = await hasActiveTrip(userId);
      if (activeTrip) {
        _isDeleting = false;
        return DeleteAccountResult(
          success: false,
          isActiveTrip: true,
          message: isArabic
              ? 'لا يمكن حذف الحساب أثناء وجود رحلة جارية. يرجى إنهاء أو إلغاء الرحلة أولاً.'
              : 'Cannot delete account while a trip is active. Please complete or cancel the trip first.',
        );
      }

      // 3. استدعاء الدالة الآمنة (RPC) delete_user_account في Supabase
      Map<String, dynamic>? rpcMap;
      try {
        final rpcRes = await _supabase.rpc('delete_user_account', params: {
          'p_scope': scope,
          'p_reason': reason,
        });
        if (rpcRes is Map) {
          rpcMap = Map<String, dynamic>.from(rpcRes);
        }
      } catch (e) {
        debugPrint('[DeleteAccountService] RPC delete_user_account error: $e');
      }

      final isSuccess = rpcMap != null && rpcMap['success'] == true;
      final effectiveScope = (rpcMap?['scope'] ?? scope).toString();
      final serverMessage = rpcMap?['message']?.toString();

      if (!isSuccess && rpcMap?['is_active_trip'] == true) {
        _isDeleting = false;
        return DeleteAccountResult(
          success: false,
          isActiveTrip: true,
          message: serverMessage ?? (isArabic ? 'توجد رحلة نشطة حالياً' : 'Active trip in progress'),
        );
      }

      // 4. معالجة الحالة المحلية بناءً على النطاق المنفذ
      if (effectiveScope == 'driver') {
        // حذف حساب الكابتن فقط: يظل المستخدم مسجلاً كراكب
        try {
          GlobalState.instance.stopDriverLocationTracking();
        } catch (_) {}

        GlobalState.instance.verificationStatus = DriverVerificationStatus.unregistered;
        GlobalState.instance.currentRole = UserRole.rider;
        GlobalState.instance.driverAddress = null;
        GlobalState.instance.driverRejectionReason = null;
        GlobalState.instance.notify();

        _isDeleting = false;
        AppLogger.rideLog('DeleteAccount', 'Driver account removed successfully. Switched to rider.', passengerId: userId);

        return DeleteAccountResult(
          success: true,
          scope: 'driver',
          message: serverMessage ?? (isArabic
              ? 'تم حذف حساب الكابتن بنجاح. حسابك الآن يعمل كراكب فقط.'
              : 'Driver account deleted successfully. You are now a rider only.'),
        );
      } else if (effectiveScope == 'rider') {
        // حذف بيانات الراكب فقط
        GlobalState.instance.passengerWalletBalance = 0.0;
        GlobalState.instance.walletBalance = 0.0;
        GlobalState.instance.notify();

        _isDeleting = false;
        return DeleteAccountResult(
          success: true,
          scope: 'rider',
          message: serverMessage ?? (isArabic
              ? 'تم حذف بيانات حساب الراكب بنجاح.'
              : 'Rider account data deleted successfully.'),
        );
      } else {
        // حذف الحساب بالكامل (Both)
        try {
          GlobalState.instance.stopDriverLocationTracking();
        } catch (_) {}

        // مسح جميع البيانات المحلية (SharedPreferences) مع الحفاظ على لغة التطبيق
        try {
          final prefs = await SharedPreferences.getInstance();
          final langCode = prefs.getString('selected_language_code');
          await prefs.clear();
          if (langCode != null) {
            await prefs.setString('selected_language_code', langCode);
          }
        } catch (e) {
          debugPrint('[DeleteAccountService] Local prefs clear error: $e');
        }

        // تسجيل الخروج من Supabase Auth
        try {
          await _supabase.auth.signOut();
        } catch (e) {
          debugPrint('[DeleteAccountService] Auth signOut error: $e');
        }

        // إعادة ضبط حالة التطبيق بالكامل
        GlobalState.instance.reset();

        _isDeleting = false;
        AppLogger.rideLog('DeleteAccount', 'Entire account deleted successfully for user', passengerId: userId);

        return DeleteAccountResult(
          success: true,
          scope: 'both',
          message: serverMessage ?? (isArabic ? 'تم حذف الحساب بالكامل بنجاح.' : 'Account deleted successfully.'),
        );
      }
    } catch (e, stackTrace) {
      _isDeleting = false;
      AppLogger.error('DeleteAccountService', 'Failed to delete account for user $userId', e, stackTrace);
      return DeleteAccountResult(
        success: false,
        message: isArabic
            ? 'حدث خطأ أثناء تنفيذ عملية حذف الحساب. يرجى المحاولة لاحقاً.'
            : 'An error occurred while deleting account. Please try again later.',
      );
    }
  }
}

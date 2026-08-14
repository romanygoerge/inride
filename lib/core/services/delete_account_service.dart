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

  const DeleteAccountResult({
    required this.success,
    this.isActiveTrip = false,
    required this.message,
  });
}

/// خدمة حذف الحساب المستقلة وتفريغ البيانات (DeleteAccountService)
/// تلتزم بأحدث معايير الأمان وتجربة المستخدم وتطبيق حذف الحساب بشكل نهائي
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

  /// تنفيذ عملية حذف الحساب والبيانات التابعة له بشكل احترافي وآمن
  Future<DeleteAccountResult> deleteAccount({required bool isArabic}) async {
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
      AppLogger.rideLog('DeleteAccount', 'Starting account deletion procedure for user', passengerId: userId);

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

      // 3. المحاولة الأولى: استدعاء الدالة الآمنة (RPC) delete_own_account في Supabase
      bool rpcSuccess = false;
      try {
        final rpcRes = await _supabase.rpc('delete_own_account');
        if (rpcRes != null && (rpcRes['success'] == true || rpcRes == true)) {
          rpcSuccess = true;
          debugPrint('[DeleteAccountService] RPC delete_own_account succeeded.');
        }
      } catch (e) {
        debugPrint('[DeleteAccountService] RPC delete_own_account not available or failed: $e. Falling back to explicit table deletions.');
      }

      // 4. في حالة عدم وجود الـ RPC أو فشلها، تنفيذ حذف التبيعات خطوة بخطوة بالترتيب الصحيح
      if (!rpcSuccess) {
        // أ. إيقاف تتبع الموقع إن كان كابتن
        try {
          GlobalState.instance.stopDriverLocationTracking();
        } catch (_) {}

        // ب. حذف الإشعارات الخاصة بالمستخدم
        try {
          await _supabase.from('notifications').delete().eq('user_id', userId);
        } catch (e) {
          debugPrint('[DeleteAccountService] Error deleting notifications: $e');
        }

        // ج. حذف سجل الأجهزة و Push Notification Tokens
        try {
          await _supabase.from('user_fcm_tokens').delete().eq('user_id', userId);
        } catch (_) {}
        try {
          await _supabase.from('device_tokens').delete().eq('user_id', userId);
        } catch (_) {}

        // د. حذف العناوين المحفوظة
        try {
          await _supabase.from('saved_addresses').delete().eq('user_id', userId);
        } catch (e) {
          debugPrint('[DeleteAccountService] Error deleting saved_addresses: $e');
        }

        // هـ. حذف محادثات ورسائل الدعم الفني
        try {
          await _supabase.from('support_messages').delete().eq('sender_id', userId);
          await _supabase.from('support_chats').delete().eq('user_id', userId);
        } catch (e) {
          debugPrint('[DeleteAccountService] Error deleting support chats: $e');
        }

        // و. حذف بيانات الكابتن إن وجدت (الموقع، الوثائق، المركبة، سجل السائق والراكب)
        try {
          await _supabase.from('driver_locations').delete().or('driver_id.eq.$userId,user_id.eq.$userId');
        } catch (_) {}
        try {
          await _supabase.from('driver_documents').delete().or('driver_id.eq.$userId,user_id.eq.$userId');
        } catch (_) {}
        try {
          await _supabase.from('vehicles').delete().or('driver_id.eq.$userId,user_id.eq.$userId');
        } catch (_) {}
        try {
          await _supabase.from('drivers').delete().or('id.eq.$userId,user_id.eq.$userId');
        } catch (_) {}
        try {
          await _supabase.from('passengers').delete().or('id.eq.$userId,user_id.eq.$userId');
        } catch (_) {}

        // ز. حذف الحساب الشخصي من جدول users / profiles
        await _supabase.from('users').delete().eq('id', userId);
        try {
          await _supabase.from('profiles').delete().eq('id', userId);
        } catch (_) {}

        // ح. تسجل خروج المستخدم من Supabase Auth
        try {
          await _supabase.auth.signOut();
        } catch (e) {
          debugPrint('[DeleteAccountService] Auth signOut error: $e');
        }
      }

      // 5. مسح جميع البيانات المحلية (SharedPreferences & Session Cache)
      try {
        final prefs = await SharedPreferences.getInstance();
        final langCode = prefs.getString('selected_language_code'); // الحفاظ على لغة التطبيق المفضل للمستخدم
        await prefs.clear();
        if (langCode != null) {
          await prefs.setString('selected_language_code', langCode);
        }
      } catch (e) {
        debugPrint('[DeleteAccountService] Local prefs clear error: $e');
      }

      // 6. إعادة ضبط حالة التطبيق بالكامل (GlobalState)
      GlobalState.instance.reset();

      _isDeleting = false;
      AppLogger.rideLog('DeleteAccount', 'Account deletion completed successfully for user', passengerId: userId);

      return DeleteAccountResult(
        success: true,
        message: isArabic ? 'تم حذف الحساب بنجاح.' : 'Account deleted successfully.',
      );
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

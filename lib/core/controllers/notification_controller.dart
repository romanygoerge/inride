import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import '../state/global_state.dart';

class NotificationController extends ChangeNotifier {
  final NotificationRepository _repository = NotificationRepository();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _userId;

  StreamSubscription<List<NotificationModel>>? _notificationsSubscription;
  StreamSubscription<int>? _unreadCountSubscription;

  List<NotificationModel> get notifications {
    final role = GlobalState.instance.currentRole;
    return _notifications.where((n) => n.matchesRole(role)).toList();
  }

  int get unreadCount {
    final role = GlobalState.instance.currentRole;
    return _notifications.where((n) => !n.isRead && n.matchesRole(role)).length;
  }

  bool get isLoading => _isLoading;

  void init(String userId) {
    if (_userId == userId) return;
    
    _userId = userId;
    _isLoading = true;
    notifyListeners();

    _cancelSubscriptions();
    _syncWithAdminNotifications(userId);

    _notificationsSubscription = _repository.getNotificationsStream(userId).listen(
      (list) {
        _notifications = list;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        debugPrint("Error listening to notifications: $error");
        _isLoading = false;
        notifyListeners();
      },
    );

    _unreadCountSubscription = _repository.getUnreadCountStream(userId).listen(
      (_) {
        notifyListeners();
      },
      onError: (error) {
        debugPrint("Error listening to unread count: $error");
      },
    );
  }

  Future<void> _syncWithAdminNotifications(String userId) async {
    final role = GlobalState.instance.currentRole;
    String? city;
    try {
      if (role == UserRole.rider) {
        city = GlobalState.instance.passengerAddress;
      } else {
        final docRes = await _supabase.from('drivers').select().eq('id', userId).maybeSingle();
        if (docRes != null) {
          city = docRes['city'] ?? docRes['address'];
        }
      }
    } catch (e) {
      debugPrint("Error fetching user city for notifications sync: $e");
    }

    await _repository.syncAdminNotifications(userId, role, city);
  }

  Future<void> markAsRead(String notificationId) async {
    if (_userId == null) return;
    try {
      await _repository.markAsRead(_userId!, notificationId);
    } catch (e) {
      debugPrint("Error marking notification read: $e");
    }
  }

  Future<void> markAllAsRead() async {
    if (_userId == null) return;
    try {
      await _repository.markAllAsRead(_userId!);
    } catch (e) {
      debugPrint("Error marking all read: $e");
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    if (_userId == null) return;
    try {
      await _repository.deleteNotification(_userId!, notificationId);
    } catch (e) {
      debugPrint("Error deleting notification: $e");
    }
  }

  Future<void> deleteAllNotifications() async {
    if (_userId == null) return;
    try {
      await _repository.deleteAllNotifications(_userId!);
    } catch (e) {
      debugPrint("Error deleting all notifications: $e");
    }
  }

  void _cancelSubscriptions() {
    _notificationsSubscription?.cancel();
    _notificationsSubscription = null;
    _unreadCountSubscription?.cancel();
    _unreadCountSubscription = null;
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}

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

  /// General notifications (excluding chat/message notifications) for the bell icon & notifications page
  List<NotificationModel> get notifications {
    final role = GlobalState.instance.currentRole;
    return _notifications.where((n) => n.matchesRole(role) && !n.isMessageNotification).toList();
  }

  /// Unread count for general notifications (bell badge)
  int get unreadCount {
    final role = GlobalState.instance.currentRole;
    return _notifications.where((n) => !n.isRead && n.matchesRole(role) && !n.isMessageNotification).length;
  }

  /// Message and chat notifications exclusively for the Messages Center
  List<NotificationModel> get messageNotifications {
    final role = GlobalState.instance.currentRole;
    return _notifications.where((n) => n.matchesRole(role) && n.isMessageNotification).toList();
  }

  /// Unread count for message and chat notifications (messages icon badge)
  int get unreadMessagesCount {
    final role = GlobalState.instance.currentRole;
    return _notifications.where((n) => !n.isRead && n.matchesRole(role) && n.isMessageNotification).length;
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
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
    try {
      await _repository.markAsRead(_userId!, notificationId);
    } catch (e) {
      debugPrint("Error marking notification read: $e");
    }
  }

  Future<void> markAllAsRead() async {
    if (_userId == null) return;
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isMessageNotification) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
    notifyListeners();
    try {
      await _repository.markAllAsRead(_userId!);
    } catch (e) {
      debugPrint("Error marking all read: $e");
    }
  }

  /// Marks all chat and message notifications as read
  Future<void> markAllMessagesAsRead() async {
    if (_userId == null) return;
    bool hasUnread = false;
    for (int i = 0; i < _notifications.length; i++) {
      if (_notifications[i].isMessageNotification && !_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        unawaited(_repository.markAsRead(_userId!, _notifications[i].id));
        hasUnread = true;
      }
    }
    if (hasUnread) {
      notifyListeners();
    }
  }

  /// Marks message notifications for a specific room or conversation as read
  Future<void> markMessagesForRoomAsRead(String roomId) async {
    if (_userId == null || roomId.isEmpty) return;
    bool hasUnread = false;
    for (int i = 0; i < _notifications.length; i++) {
      if (_notifications[i].isMessageNotification && !_notifications[i].isRead) {
        final rId = _notifications[i].data['roomId']?.toString() ??
            _notifications[i].data['room_id']?.toString() ??
            _notifications[i].data['trip_id']?.toString() ??
            _notifications[i].data['conversation_id']?.toString();
        if (rId == roomId) {
          _notifications[i] = _notifications[i].copyWith(isRead: true);
          unawaited(_repository.markAsRead(_userId!, _notifications[i].id));
          hasUnread = true;
        }
      }
    }
    if (hasUnread) {
      notifyListeners();
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    if (_userId == null) return;
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();
    try {
      await _repository.deleteNotification(_userId!, notificationId);
    } catch (e) {
      debugPrint("Error deleting notification: $e");
    }
  }

  Future<void> deleteAllNotifications() async {
    if (_userId == null) return;
    _notifications.clear();
    notifyListeners();
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

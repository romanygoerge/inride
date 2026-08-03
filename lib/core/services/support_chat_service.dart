import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/global_state.dart';
import 'app_notification_service.dart';

class SupportChatMessage {
  final String id;
  final String conversationId;
  final String userId;
  final String senderId;
  final String? receiverId;
  final String senderType; // 'admin', 'rider', 'driver'
  final String message;
  final String status; // 'sent', 'delivered', 'read'
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final bool isAdmin;

  SupportChatMessage({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.senderId,
    this.receiverId,
    required this.senderType,
    required this.message,
    required this.status,
    required this.createdAt,
    this.deliveredAt,
    this.readAt,
    required this.isAdmin,
  });

  factory SupportChatMessage.fromMap(Map<String, dynamic> map) {
    final msgText = (map['message'] as String?)?.isNotEmpty == true
        ? (map['message'] as String)
        : ((map['text'] as String?) ?? '');
    
    final bool isAdminFlag = map['is_admin'] == true || map['sender_type'] == 'admin';
    final String sType = (map['sender_type'] as String?) ?? (isAdminFlag ? 'admin' : 'rider');
    final String convId = (map['conversation_id'] as String?) ?? (map['user_id'] as String?) ?? '';
    final String uId = (map['user_id'] as String?) ?? convId;

    return SupportChatMessage(
      id: (map['id'] as String?) ?? '',
      conversationId: convId,
      userId: uId,
      senderId: (map['sender_id'] as String?) ?? uId,
      receiverId: map['receiver_id'] as String?,
      senderType: sType,
      message: msgText,
      status: (map['status'] as String?) ?? 'sent',
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      deliveredAt: map['delivered_at'] != null ? DateTime.tryParse(map['delivered_at']) : null,
      readAt: map['read_at'] != null ? DateTime.tryParse(map['read_at']) : null,
      isAdmin: isAdminFlag,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'user_id': userId,
      'sender_id': senderId,
      if (receiverId != null) 'receiver_id': receiverId,
      'sender_type': senderType,
      'message': message,
      'text': message,
      'status': status,
      'is_admin': isAdmin,
      'created_at': createdAt.toIso8601String(),
      if (deliveredAt != null) 'delivered_at': deliveredAt!.toIso8601String(),
      if (readAt != null) 'read_at': readAt!.toIso8601String(),
    };
  }
}

class SupportChatService {
  static final SupportChatService instance = SupportChatService._internal();
  factory SupportChatService() => instance;
  SupportChatService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;
  String? _activeUserId;
  bool _isChatPageActive = false;

  final Set<String> _processedMessageIds = {};
  final _messagesController = StreamController<List<SupportChatMessage>>.broadcast();
  List<SupportChatMessage> _currentMessages = [];
  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  Stream<List<SupportChatMessage>> get messagesStream => _messagesController.stream;
  List<SupportChatMessage> get currentMessages => List.unmodifiable(_currentMessages);
  int get unreadCount => unreadCountNotifier.value;

  void _updateUnreadCount() {
    final count = _currentMessages.where((m) => m.isAdmin && m.status != 'read').length;
    unreadCountNotifier.value = count;
  }

  static String _generateUuid() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // Version 4
    values[8] = (values[8] & 0x3f) | 0x80; // Variant RFC4122
    String toHex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${toHex(values.sublist(0, 4))}-${toHex(values.sublist(4, 6))}-${toHex(values.sublist(6, 8))}-${toHex(values.sublist(8, 10))}-${toHex(values.sublist(10, 16))}';
  }

  /// Initialize Realtime channel for current user conversation
  Future<void> initializeForUser(String userId) async {
    if (userId.isEmpty || userId == 'anonymous_user') return;

    if (_activeUserId == userId && _realtimeChannel != null) {
      debugPrint('[SupportChat] Channel already initialized for user: $userId');
      return;
    }

    _activeUserId = userId;
    await disposeChannel();

    debugPrint('[SupportChat] Initializing Realtime channel for user: $userId');

    // 1. Initial message sync from database
    await syncMessages();

    // 2. Setup Realtime Subscription with single active channel pattern
    final channelName = 'support_realtime_$userId';
    _realtimeChannel = _supabase.channel(channelName);

    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'support_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        _handleRealtimePayload(payload);
      },
    ).subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint('[SupportChat] Realtime Connected to channel: $channelName');
      } else if (status != RealtimeSubscribeStatus.subscribed) {
        debugPrint('[SupportChat] Realtime Disconnected from channel: $channelName status=$status error=$error');
        _attemptReconnect();
      }
    });
  }

  void setChatPageActive(bool active) {
    _isChatPageActive = active;
    debugPrint('[SupportChat] Chat Page active state changed: $active');
    if (active && _activeUserId != null) {
      markAllMessagesAsRead();
    }
  }

  /// Handle incoming Postgres changes payload
  void _handleRealtimePayload(PostgresChangePayload payload) {
    try {
      final record = payload.newRecord;
      if (record.isEmpty) return;

      final msg = SupportChatMessage.fromMap(record);
      
      // Deduplicate messages by ID
      if (_processedMessageIds.contains(msg.id)) {
        // If update event, update existing message in list
        final index = _currentMessages.indexWhere((m) => m.id == msg.id);
        if (index != -1) {
          _currentMessages[index] = msg;
          _notifyListeners();
        }
        return;
      }

      _processedMessageIds.add(msg.id);
      _currentMessages.insert(0, msg);
      _notifyListeners();

      debugPrint('[SupportChat] Support Message Delivered: id=${msg.id}, sender=${msg.senderType}');

      // If message is from Admin
      if (msg.isAdmin) {
        if (_isChatPageActive) {
          _markMessageAsDeliveredAndRead(msg.id);
        } else {
          AppNotificationService.instance.showLocalNotification(
            id: msg.id.hashCode,
            title: 'الدعم الفني',
            body: msg.message,
            data: {
              'type': 'support_chat',
              'conversation_id': _activeUserId ?? '',
              'message_id': msg.id,
            },
          );
        }
      }
    } catch (e) {
      debugPrint('[SupportChat] Error processing realtime payload: $e');
    }
  }

  /// Synchronize messages from database
  Future<void> syncMessages() async {
    final userId = _activeUserId;
    if (userId == null) return;

    try {
      final chatRes = await _supabase
          .from('support_chats')
          .select('status')
          .eq('id', userId)
          .maybeSingle();

      if (chatRes != null && chatRes['status'] == 'resolved') {
        _currentMessages = [];
        _processedMessageIds.clear();
        _notifyListeners();
        debugPrint('[SupportChat] Ticket resolved by admin, hiding messages on client');
        return;
      }

      final List<dynamic> response = await _supabase
          .from('support_messages')
          .select('*')
          .or('user_id.eq.$userId,conversation_id.eq.$userId')
          .order('created_at', ascending: false);

      _currentMessages = response.map((item) => SupportChatMessage.fromMap(item as Map<String, dynamic>)).toList();
      _processedMessageIds.clear();
      for (final msg in _currentMessages) {
        _processedMessageIds.add(msg.id);
      }

      _notifyListeners();
      debugPrint('[SupportChat] Message Sync completed: count=${_currentMessages.length}');

      if (_isChatPageActive) {
        markAllMessagesAsRead();
      }
    } catch (e) {
      debugPrint('[SupportChat] Message Sync failed: $e');
    }
  }

  /// Send message to Support
  Future<bool> sendMessage(String text) async {
    final userId = _activeUserId ?? GlobalState.instance.userUid;
    if (userId == null || userId == 'anonymous_user' || text.trim().isEmpty) return false;

    final userRole = GlobalState.instance.currentRole;
    final senderTypeStr = userRole == UserRole.driver ? 'driver' : 'rider';
    final msgId = _generateUuid();
    final now = DateTime.now();

    final newMessage = SupportChatMessage(
      id: msgId,
      conversationId: userId,
      userId: userId,
      senderId: userId,
      senderType: senderTypeStr,
      message: text.trim(),
      status: 'sent',
      createdAt: now,
      isAdmin: false,
    );

    // Optimistic UI update
    _currentMessages.insert(0, newMessage);
    _processedMessageIds.add(msgId);
    _notifyListeners();

    try {
      // 1. Ensure support_chats conversation metadata exists first
      await _supabase.from('support_chats').upsert({
        'id': userId,
        'user_id': userId,
        'user_type': senderTypeStr,
        'status': 'open',
        'last_message': text.trim(),
        'last_message_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }).catchError((err) {
        debugPrint('[SupportChat] Non-critical warning upserting support_chats: $err');
      });

      // 2. Insert message into Supabase
      try {
        await _supabase.from('support_messages').insert({
          'id': msgId,
          'conversation_id': userId,
          'user_id': userId,
          'sender_id': userId,
          'sender_type': senderTypeStr,
          'message': text.trim(),
          'text': text.trim(),
          'status': 'sent',
          'is_admin': false,
          'created_at': now.toIso8601String(),
        });
      } catch (insertErr) {
        debugPrint('[SupportChat] Retry inserting simplified message object: $insertErr');
        await _supabase.from('support_messages').insert({
          'id': msgId,
          'conversation_id': userId,
          'user_id': userId,
          'sender_type': senderTypeStr,
          'message': text.trim(),
          'text': text.trim(),
          'status': 'sent',
          'is_admin': false,
          'created_at': now.toIso8601String(),
        });
      }

      // 3. Insert notification for Admin in admin_notifications table
      await _supabase.from('admin_notifications').insert({
        'id': _generateUuid(),
        'user_id': userId,
        'user_name': GlobalState.instance.userName ?? 'مستخدم',
        'title': 'رسالة دعم جديدة',
        'body': text.trim(),
        'type': 'support_chat',
        'is_read': false,
        'created_at': now.toIso8601String(),
      }).catchError((err) {
        debugPrint('[SupportChat] Non-critical warning inserting admin_notifications: $err');
      });

      return true;
    } catch (e) {
      debugPrint('[SupportChat] Error sending support message: $e');
      return false;
    }
  }

  /// Mark single message delivered and read
  Future<void> _markMessageAsDeliveredAndRead(String msgId) async {
    final nowStr = DateTime.now().toIso8601String();
    try {
      await _supabase.from('support_messages').update({
        'status': 'read',
        'delivered_at': nowStr,
        'read_at': nowStr,
      }).eq('id', msgId);

      debugPrint('[SupportChat] Support Message Read: id=$msgId');
    } catch (e) {
      // Fallback try simple status update if detailed columns don't exist yet
      try {
        await _supabase.from('support_messages').update({
          'status': 'read',
        }).eq('id', msgId);
      } catch (_) {}
    }
  }

  /// Mark all unread admin messages as read
  Future<void> markAllMessagesAsRead() async {
    final userId = _activeUserId;
    if (userId == null) return;

    final nowStr = DateTime.now().toIso8601String();
    try {
      await _supabase.from('support_messages').update({
        'status': 'read',
        'delivered_at': nowStr,
        'read_at': nowStr,
      }).eq('user_id', userId).eq('is_admin', true).neq('status', 'read');

      // Reset unread_user_count on conversation
      await _supabase.from('support_chats').update({
        'unread_user_count': 0,
      }).eq('id', userId);

      for (int i = 0; i < _currentMessages.length; i++) {
        if (_currentMessages[i].isAdmin) {
          _currentMessages[i] = SupportChatMessage(
            id: _currentMessages[i].id,
            conversationId: _currentMessages[i].conversationId,
            userId: _currentMessages[i].userId,
            senderId: _currentMessages[i].senderId,
            receiverId: _currentMessages[i].receiverId,
            senderType: _currentMessages[i].senderType,
            message: _currentMessages[i].message,
            status: 'read',
            createdAt: _currentMessages[i].createdAt,
            deliveredAt: _currentMessages[i].deliveredAt,
            readAt: DateTime.now(),
            isAdmin: true,
          );
        }
      }
      unreadCountNotifier.value = 0;
      _notifyListeners();

      debugPrint('[SupportChat] Unread Count Updated: reset for user $userId');
    } catch (e) {
      debugPrint('[SupportChat] Error marking messages read: $e');
    }
  }

  Future<void> _attemptReconnect() async {
    final userId = _activeUserId;
    if (userId == null) return;
    await Future.delayed(const Duration(seconds: 3));
    if (_activeUserId == userId) {
      debugPrint('[SupportChat] Attempting channel reconnect for user: $userId');
      await initializeForUser(userId);
    }
  }

  Future<void> disposeChannel() async {
    if (_realtimeChannel != null) {
      debugPrint('[SupportChat] Realtime Disconnected: removing channel');
      await _supabase.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
  }

  void _notifyListeners() {
    _updateUnreadCount();
    if (!_messagesController.isClosed) {
      _messagesController.add(List.unmodifiable(_currentMessages));
    }
  }
}

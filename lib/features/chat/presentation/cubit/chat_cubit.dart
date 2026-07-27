import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_state.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/services/notification_service.dart';

class ChatCubit extends Cubit<ChatState> {
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _typingSubscription;

  ChatCubit() : super(ChatInitial());

  void loadChatRoom(String tripId, String myId, String partnerId) {
    emit(ChatLoading());
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();

    // 1. Listen to messages stream
    _messagesSubscription = _supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('request_id', tripId)
        .listen((msgList) {
      final sortedDocs = List<Map<String, dynamic>>.from(msgList);
      sortedDocs.sort((a, b) {
        final aTime = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
        final bTime = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      final List<Map<String, dynamic>> messages = sortedDocs.map((data) {
        return {
          'id': data['id'],
          'text': data['text'] ?? '',
          'senderId': data['sender_id'] ?? data['senderId'] ?? '',
          'isSeen': data['is_seen'] ?? data['isSeen'] ?? false,
          'isDelivered': data['is_delivered'] ?? data['isDelivered'] ?? true,
          'createdAt': DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
        };
      }).toList();

      final isPartnerTyping = state is ChatLoaded ? (state as ChatLoaded).partnerIsTyping : false;
      emit(ChatLoaded(messages: messages, partnerIsTyping: isPartnerTyping));
    }, onError: (e) {
      emit(ChatError(e.toString()));
    });

    // 2. Listen to partner's typing status
    _typingSubscription = _supabase
        .from('typing_indicators')
        .stream(primaryKey: ['id'])
        .eq('request_id', tripId)
        .listen((list) {
      bool partnerTyping = false;
      for (var row in list) {
        if ((row['user_id'] == partnerId || row['userId'] == partnerId) && row['is_typing'] == true) {
          partnerTyping = true;
          break;
        }
      }

      if (state is ChatLoaded) {
        final current = state as ChatLoaded;
        emit(ChatLoaded(messages: current.messages, partnerIsTyping: partnerTyping));
      }
    });
  }

  Future<void> sendMessage(String tripId, String senderId, String text) async {
    try {
      final msgRes = await _supabase.from('chat_messages').insert({
        'request_id': tripId,
        'sender_id': senderId,
        'text': text,
        'created_at': DateTime.now().toIso8601String(),
      }).select('id').single();

      final messageId = msgRes['id'];

      try {
        final reqRes = await _supabase.from('ride_requests').select().eq('id', tripId).maybeSingle();
        if (reqRes != null) {
          final reqData = Map<String, dynamic>.from(reqRes);
          final String passengerId = reqData['passenger_id'] ?? reqData['passengerId'] ?? '';
          final String driverId = reqData['driver_id'] ?? reqData['driverId'] ?? '';
          final String partnerId = senderId == passengerId ? driverId : passengerId;
          
          if (partnerId.isNotEmpty) {
            final senderRes = await _supabase.from('users').select('name').eq('id', senderId).maybeSingle();
            final senderName = senderRes != null ? (senderRes['name'] ?? 'مستخدم') : 'مستخدم';
            
            unawaited(NotificationService.instance.sendNotification(
              recipientId: partnerId,
              title: 'رسالة جديدة من $senderName 💬',
              body: text,
              type: 'chat_message',
              data: {
                'id': messageId,
                'tripId': tripId,
                'partnerId': senderId,
                'partnerName': senderName,
              },
            ));
          }
        }
      } catch (e) {
        debugPrint("Failed to send chat notification: $e");
      }
    } catch (_) {}
  }

  Future<void> updateTypingStatus(String tripId, String myId, bool isTyping) async {
    try {
      await _supabase.from('typing_indicators').upsert({
        'request_id': tripId,
        'user_id': myId,
        'is_typing': isTyping,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  void leaveChatRoom(String tripId, String myId) {
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    updateTypingStatus(tripId, myId, false);
    emit(ChatInitial());
  }

  @override
  Future<void> close() {
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    return super.close();
  }
}

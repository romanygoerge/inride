import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/chat_room.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../models/chat_room_model.dart';
import '../models/chat_message_model.dart';

class ChatRepositoryImpl implements ChatRepository {
  final SupabaseClient _supabase;

  ChatRepositoryImpl(this._supabase);

  @override
  Stream<List<ChatRoom>> getChatRoomsStream(String userId) {
    final controller = StreamController<List<ChatRoom>>.broadcast();

    Future<void> fetchData() async {
      try {
        final res = await _supabase
            .from('chat_rooms')
            .select('*, passenger:passenger_id(name, avatar_url), driver:driver_id(name, avatar_url), trip:trip_id(*)')
            .or('passenger_id.eq.$userId,driver_id.eq.$userId')
            .order('updated_at', ascending: false);

        final list = (res as List<dynamic>)
            .map((r) => ChatRoomModel.fromMap(r as Map<String, dynamic>, userId))
            .toList();
        
        if (!controller.isClosed) {
          controller.add(list);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    // Initial load
    fetchData();

    // Listen to realtime changes on chat_rooms table
    final channel = _supabase.channel('realtime_rooms_$userId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'chat_rooms',
      callback: (payload) {
        fetchData();
      },
    ).subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint('[ChatRooms] Realtime subscribed');
      }
    });

    controller.onCancel = () {
      channel.unsubscribe();
      controller.close();
    };

    return controller.stream;
  }

  @override
  Stream<List<ChatMessage>> getMessagesStream(String roomId) {
    final controller = StreamController<List<ChatMessage>>.broadcast();
    final String currentUserId = _supabase.auth.currentUser?.id ?? '';

    Future<void> fetchData() async {
      try {
        final res = await _supabase
            .from('messages')
            .select('*, reply_to:reply_to_message_id(text), attachments(*), message_reads(*)')
            .eq('room_id', roomId)
            .order('created_at', ascending: false);

        final list = (res as List<dynamic>)
            .map((m) => ChatMessageModel.fromMap(m as Map<String, dynamic>, currentUserId))
            .toList();

        if (!controller.isClosed) {
          controller.add(list);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    // Initial load
    fetchData();

    // Listen to realtime changes on messages
    final channel = _supabase.channel('realtime_msgs_$roomId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: roomId,
      ),
      callback: (payload) {
        fetchData();
      },
    ).subscribe();

    controller.onCancel = () {
      channel.unsubscribe();
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<String> getOrCreateSupportRoom(String userId) async {
    try {
      final res = await _supabase.rpc('get_or_create_support_room', params: {
        'p_user_id': userId,
      });
      return res as String;
    } catch (e) {
      debugPrint('[ChatRepo] Error in getOrCreateSupportRoom: $e');
      rethrow;
    }
  }

  @override
  Future<String> getRoomIdForTrip(String tripId) async {
    try {
      final res = await _supabase
          .from('chat_rooms')
          .select('id')
          .eq('trip_id', tripId)
          .maybeSingle();
      if (res != null && res['id'] != null) {
        return res['id'] as String;
      }

      // Auto-create chat room for trip if not created by DB trigger yet
      final currentUserId = _supabase.auth.currentUser?.id;
      final newRoom = await _supabase.from('chat_rooms').insert({
        'type': 'trip',
        'trip_id': tripId,
        'status': 'active',
        if (currentUserId != null) 'passenger_id': currentUserId,
      }).select('id').maybeSingle();

      if (newRoom != null && newRoom['id'] != null) {
        return newRoom['id'] as String;
      }

      return tripId;
    } catch (e) {
      debugPrint('[ChatRepo] Error in getRoomIdForTrip: $e');
      return tripId;
    }
  }

  @override
  Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required String text,
    String? replyToMessageId,
  }) async {
    try {
      await _supabase.from('messages').insert({
        'room_id': roomId,
        'sender_id': senderId,
        'text': text,
        if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      });
    } catch (e) {
      debugPrint('[ChatRepo] Error sending message: $e');
      rethrow;
    }
  }

  @override
  Future<void> sendAttachment({
    required String roomId,
    required String senderId,
    required String text,
    required String filePath,
    required String fileName,
    String? replyToMessageId,
  }) async {
    try {
      // 1. Upload file to Supabase Storage
      final String fileExt = fileName.split('.').last;
      final String storagePath = 'chat_rooms/$roomId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      await _supabase.storage.from('chat-attachments').upload(
        storagePath,
        File(filePath),
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );

      // 2. Generate secure signed URL valid for 7 days (expiresIn in seconds)
      final signedUrl = await _supabase.storage
          .from('chat-attachments')
          .createSignedUrl(storagePath, 7 * 24 * 60 * 60);

      // 3. Create message in DB
      final msgRes = await _supabase.from('messages').insert({
        'room_id': roomId,
        'sender_id': senderId,
        'text': text,
        if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      }).select('id').single();

      final String messageId = msgRes['id'] as String;

      // 4. Save attachment record
      await _supabase.from('attachments').insert({
        'message_id': messageId,
        'file_path': signedUrl,
        'file_name': fileName,
        'mime_type': 'image/jpeg',
      });
    } catch (e) {
      debugPrint('[ChatRepo] Error sending attachment: $e');
      rethrow;
    }
  }

  @override
  Future<void> markMessagesAsRead(String roomId, String userId) async {
    try {
      // Get all unread messages in room sent by other users
      final unreadMsgs = await _supabase
          .from('messages')
          .select('id')
          .eq('room_id', roomId)
          .neq('sender_id', userId);

      if (unreadMsgs.isNotEmpty) {
        final List<Map<String, dynamic>> readsToInsert = unreadMsgs.map((msg) {
          return {
            'message_id': msg['id'],
            'user_id': userId,
          };
        }).toList();

        await _supabase.from('message_reads').upsert(readsToInsert);
      }
    } catch (e) {
      debugPrint('[ChatRepo] Error marking read: $e');
    }
  }

  @override
  Future<void> updateTypingStatus(String roomId, String userId, bool isTyping) async {
    try {
      await _supabase.from('typing_indicators').upsert({
        'request_id': roomId, // using typing indicators table (or request_id column mapping room_id)
        'user_id': userId,
        'is_typing': isTyping,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  @override
  Stream<bool> getTypingIndicatorStream(String roomId, String partnerId) {
    final controller = StreamController<bool>.broadcast();

    // Listen to changes on typing_indicators
    final channel = _supabase.channel('typing_$roomId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'typing_indicators',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'request_id',
        value: roomId,
      ),
      callback: (payload) {
        final record = payload.newRecord;
        if (record.isNotEmpty) {
          final String uId = record['user_id'] ?? '';
          final bool isTyping = record['is_typing'] == true;
          if (uId == partnerId) {
            controller.add(isTyping);
          }
        }
      },
    ).subscribe();

    controller.onCancel = () {
      channel.unsubscribe();
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    try {
      await _supabase.from('messages').update({
        'is_deleted': true,
        'text': 'هذه الرسالة تم حذفها من قبل المسؤول 🗑️',
      }).eq('id', messageId);
    } catch (e) {
      debugPrint('[ChatRepo] Error deleting message: $e');
      rethrow;
    }
  }

  @override
  Future<void> archiveRoom(String roomId) async {
    try {
      await _supabase.from('chat_rooms').update({
        'status': 'archived',
      }).eq('id', roomId);
    } catch (e) {
      debugPrint('[ChatRepo] Error archiving room: $e');
      rethrow;
    }
  }

  @override
  Future<void> closeRoom(String roomId) async {
    try {
      await _supabase.from('chat_rooms').update({
        'status': 'closed',
      }).eq('id', roomId);

      await _supabase.from('support_tickets').update({
        'status': 'resolved',
      }).eq('chat_room_id', roomId);
    } catch (e) {
      debugPrint('[ChatRepo] Error closing room: $e');
      rethrow;
    }
  }
}

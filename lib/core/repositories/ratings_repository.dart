import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/rating_model.dart';
import '../models/rating_stats_model.dart';

abstract class RatingsRepository {
  Future<bool> submitTripRating({
    required String tripId,
    required String toUserId,
    required int rating,
    String? review,
    required String role,
    String? senderName,
    String? receiverName,
  });

  Future<List<RatingModel>> getUserRatings({
    required String userId,
    int limit = 20,
    int offset = 0,
  });

  Future<RatingStatsModel> getUserRatingStats(String userId);

  Stream<List<RatingModel>> streamUserRatings(String userId);
}

class RatingsRepositoryImpl implements RatingsRepository {
  final SupabaseClient _supabase;

  RatingsRepositoryImpl({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<bool> submitTripRating({
    required String tripId,
    required String toUserId,
    required int rating,
    String? review,
    required String role,
    String? senderName,
    String? receiverName,
  }) async {
    try {
      final response = await _supabase.rpc(
        'submit_trip_rating',
        params: {
          'p_trip_id': tripId,
          'p_to_user_id': toUserId,
          'p_rating': rating,
          'p_review': review,
          'p_role': role,
          'p_sender_name': senderName,
          'p_receiver_name': receiverName,
        },
      );

      if (response != null && response['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error submitting trip rating: $e');
      // Fallback direct insert if RPC fails or table backup
      try {
        final currentUserId = _supabase.auth.currentUser?.id;
        if (currentUserId == null) return false;

        await _supabase.from('ratings').insert({
          'trip_id': tripId,
          'from_user_id': currentUserId,
          'to_user_id': toUserId,
          'sender_name': senderName,
          'receiver_name': receiverName,
          'role': role,
          'rating': rating,
          'review': review,
          'created_at': DateTime.now().toIso8601String(),
        });
        return true;
      } catch (fallbackError) {
        debugPrint('Fallback rating submission error: $fallbackError');
        rethrow;
      }
    }
  }

  @override
  Future<List<RatingModel>> getUserRatings({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final data = await _supabase
          .from('ratings')
          .select()
          .eq('to_user_id', userId)
          .eq('is_hidden', false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (data as List)
          .map((json) => RatingModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching user ratings: $e');
      return [];
    }
  }

  @override
  Future<RatingStatsModel> getUserRatingStats(String userId) async {
    try {
      final userData = await _supabase
          .from('users')
          .select('rating, total_rating, rating_count, average_rating, star_5_count, star_4_count, star_3_count, star_2_count, star_1_count')
          .eq('id', userId)
          .maybeSingle();

      if (userData != null) {
        return RatingStatsModel.fromJson(userData);
      }
      return const RatingStatsModel();
    } catch (e) {
      debugPrint('Error fetching user rating stats: $e');
      return const RatingStatsModel();
    }
  }

  @override
  Stream<List<RatingModel>> streamUserRatings(String userId) {
    return _supabase
        .from('ratings')
        .stream(primaryKey: ['id'])
        .eq('to_user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data
            .where((json) => json['is_hidden'] != true)
            .map((json) => RatingModel.fromJson(json))
            .toList());
  }
}

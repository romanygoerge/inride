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
      // Fallback direct insert if RPC fails
      try {
        final currentUserId = _supabase.auth.currentUser?.id;
        if (currentUserId == null) return false;

        final ratingId = '${tripId}_$currentUserId';
        final Map<String, dynamic> payload = {
          'id': ratingId,
          'sender_id': currentUserId,
          'receiver_id': toUserId,
          'receiver_role': role,
          'rating': rating.toDouble(),
          'comment': (review != null && review.isNotEmpty) ? review : 'بدون تعليق',
          'created_at': DateTime.now().toIso8601String(),
        };
        if (tripId.isNotEmpty) {
          payload['request_id'] = tripId;
        }

        debugPrint('[RatingsRepo] Fallback insert payload: $payload');
        await _supabase.from('ratings').upsert(payload);
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
          .eq('receiver_id', userId)
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
      // Get user's rating from users table
      final userData = await _supabase
          .from('users')
          .select('rating')
          .eq('id', userId)
          .maybeSingle();

      // Calculate real stats from ratings table
      final ratingsData = await _supabase
          .from('ratings')
          .select('rating')
          .eq('receiver_id', userId);

      final ratingsList = List<Map<String, dynamic>>.from(ratingsData as List);
      
      if (ratingsList.isNotEmpty) {
        double total = 0;
        int star5 = 0, star4 = 0, star3 = 0, star2 = 0, star1 = 0;
        for (var row in ratingsList) {
          final val = (row['rating'] as num?)?.toDouble() ?? 0;
          total += val;
          if (val >= 4.5) {
            star5++;
          } else if (val >= 3.5) {
            star4++;
          } else if (val >= 2.5) {
            star3++;
          } else if (val >= 1.5) {
            star2++;
          } else {
            star1++;
          }
        }
        final avg = total / ratingsList.length;
        return RatingStatsModel(
          averageRating: double.parse(avg.toStringAsFixed(1)),
          ratingCount: ratingsList.length,
          star5Count: star5,
          star4Count: star4,
          star3Count: star3,
          star2Count: star2,
          star1Count: star1,
        );
      }

      final dbRating = (userData?['rating'] as num?)?.toDouble() ?? 0.0;
      return RatingStatsModel(averageRating: dbRating, ratingCount: 0);
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
        .eq('receiver_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data
            .map((json) => RatingModel.fromJson(json))
            .toList());
  }
}

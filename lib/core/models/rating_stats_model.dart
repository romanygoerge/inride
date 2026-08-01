import 'package:flutter/foundation.dart';

@immutable
class RatingStatsModel {
  final double averageRating;
  final int ratingCount;
  final int totalRating;
  final int star5Count;
  final int star4Count;
  final int star3Count;
  final int star2Count;
  final int star1Count;

  const RatingStatsModel({
    this.averageRating = 5.0,
    this.ratingCount = 0,
    this.totalRating = 0,
    this.star5Count = 0,
    this.star4Count = 0,
    this.star3Count = 0,
    this.star2Count = 0,
    this.star1Count = 0,
  });

  factory RatingStatsModel.fromJson(Map<String, dynamic> json) {
    final count = (json['rating_count'] as num?)?.toInt() ?? 0;
    final total = (json['total_rating'] as num?)?.toInt() ?? 0;
    final rawAvg = (json['average_rating'] as num?)?.toDouble() ??
        (json['rating'] as num?)?.toDouble() ??
        5.0;

    return RatingStatsModel(
      averageRating: count > 0 ? (total > 0 ? total / count : rawAvg) : rawAvg,
      ratingCount: count,
      totalRating: total,
      star5Count: (json['star_5_count'] as num?)?.toInt() ?? 0,
      star4Count: (json['star_4_count'] as num?)?.toInt() ?? 0,
      star3Count: (json['star_3_count'] as num?)?.toInt() ?? 0,
      star2Count: (json['star_2_count'] as num?)?.toInt() ?? 0,
      star1Count: (json['star_1_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Calculates percentage for a given star (1-5)
  double getStarPercentage(int star) {
    if (ratingCount <= 0) {
      return star == 5 ? 100.0 : 0.0;
    }
    int starCount = 0;
    switch (star) {
      case 5:
        starCount = star5Count;
        break;
      case 4:
        starCount = star4Count;
        break;
      case 3:
        starCount = star3Count;
        break;
      case 2:
        starCount = star2Count;
        break;
      case 1:
        starCount = star1Count;
        break;
    }
    return (starCount / ratingCount) * 100.0;
  }

  /// Uber Display Rule: Hide numerical rating if rating_count < 5
  String formatDisplayRating({String newDriverLabel = 'سائق جديد', String noRatingsLabel = 'جديد (أقل من 5 تقييمات)'}) {
    if (ratingCount < 5) {
      return ratingCount == 0 ? noRatingsLabel : newDriverLabel;
    }
    return '⭐ ${averageRating.toStringAsFixed(2)} ($ratingCount)';
  }

  bool get isNewUser => ratingCount < 5;
}

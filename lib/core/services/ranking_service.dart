import '../models/driver_model.dart';
import '../models/offer_score.dart';

class RankingService {
  final OfferScore weights;

  RankingService({OfferScore? weights}) : weights = weights ?? const OfferScore();

  double computeScore(DriverModel driver, double distanceKm) {
    // Normalize distance: closer = higher score
    final distanceScore = 1 / (distanceKm + 0.1); // avoid div by zero
    // Rating assumed out of 5
    final ratingScore = (driver.rating ?? 5.0) / 5.0;
    // Completion rate: use completed trips (placeholder max 2000)
    final completionScore = (driver.completedTrips ?? 0) / 2000.0;
    // Last active: placeholder as 1 (could be timestamp diff)
    final lastActiveScore = 1.0;
    // Availability: isAvailable true =1 else 0
    final availabilityScore = driver.isAvailable ? 1.0 : 0.0;

    // Weighted sum
    return weights.distanceWeight * distanceScore +
        weights.ratingWeight * ratingScore +
        weights.completionRateWeight * completionScore +
        weights.lastActiveWeight * lastActiveScore +
        weights.availabilityWeight * availabilityScore;
  }
}

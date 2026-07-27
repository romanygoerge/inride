class RideOffer {
  final String id;
  final String driverId;
  final String passengerId;
  final double price;
  final Duration eta;
  final DateTime timestamp;
  final OfferStatus status; // pending, accepted, rejected, countered

  RideOffer({
    required this.id,
    required this.driverId,
    required this.passengerId,
    required this.price,
    required this.eta,
    required this.timestamp,
    this.status = OfferStatus.pending,
  });
}

enum OfferStatus { pending, accepted, rejected, countered }

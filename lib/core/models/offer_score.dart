class OfferScore {
  final double distanceWeight;
  final double ratingWeight;
  final double responseSpeedWeight;
  final double completionRateWeight;
  final double lastActiveWeight;
  final double availabilityWeight;

  const OfferScore({
    this.distanceWeight = 0.3,
    this.ratingWeight = 0.25,
    this.responseSpeedWeight = 0.15,
    this.completionRateWeight = 0.1,
    this.lastActiveWeight = 0.1,
    this.availabilityWeight = 0.1,
  });
}

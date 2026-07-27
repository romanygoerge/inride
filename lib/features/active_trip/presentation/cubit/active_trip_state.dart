import '../../../../core/state/global_state.dart' show DriverOffer, RideStatus;

abstract class ActiveTripState {
  const ActiveTripState();
}

class ActiveTripInitial extends ActiveTripState {}

class ActiveTripLoading extends ActiveTripState {}

class ActiveTripInProgress extends ActiveTripState {
  final String requestId;
  final RideStatus status;
  final double? driverLatitude;
  final double? driverLongitude;
  final double progress;
  final DriverOffer driverOffer;

  const ActiveTripInProgress({
    required this.requestId,
    required this.status,
    required this.driverOffer,
    this.driverLatitude,
    this.driverLongitude,
    this.progress = 0.0,
  });
}

class ActiveTripCompleted extends ActiveTripState {
  final double price;
  final String driverName;

  const ActiveTripCompleted({required this.price, required this.driverName});
}

class ActiveTripCancelled extends ActiveTripState {
  final String reason;

  const ActiveTripCancelled(this.reason);
}

class ActiveTripError extends ActiveTripState {
  final String message;

  const ActiveTripError(this.message);
}

import '../../../../core/models/ride_request_model.dart';
import '../../../../core/state/global_state.dart' show DriverOffer;

abstract class RideMatchingState {
  const RideMatchingState();
}

class RideMatchingInitial extends RideMatchingState {}

class RideMatchingLoading extends RideMatchingState {}

class RideSearching extends RideMatchingState {
  final String requestId;
  final RideRequestModel request;

  const RideSearching({required this.requestId, required this.request});
}

class DriverBidding extends RideMatchingState {
  final String requestId;
  final RideRequestModel request;
  final List<DriverOffer> offers;

  const DriverBidding({
    required this.requestId,
    required this.request,
    required this.offers,
  });
}

class DriverAccepted extends RideMatchingState {
  final String requestId;
  final RideRequestModel request;
  final DriverOffer acceptedOffer;

  const DriverAccepted({
    required this.requestId,
    required this.request,
    required this.acceptedOffer,
  });
}

class RideMatchingCancelled extends RideMatchingState {}

class RideMatchingExpired extends RideMatchingState {}

class RideMatchingError extends RideMatchingState {
  final String message;

  const RideMatchingError(this.message);
}

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/repositories/ride_repository.dart';
import '../../../../core/state/global_state.dart' show DriverOffer, RideStatus;
import '../../../../core/services/driver_location_service.dart';
import 'active_trip_state.dart';

class ActiveTripCubit extends Cubit<ActiveTripState> {
  final RideRepository _rideRepository;
  StreamSubscription? _rideSubscription;
  StreamSubscription? _driverLocationSubscription;

  ActiveTripCubit(this._rideRepository) : super(ActiveTripInitial());

  void startPassengerTracking(String requestId, DriverOffer offer) {
    emit(ActiveTripLoading());
    _rideSubscription?.cancel();
    _driverLocationSubscription?.cancel();

    _rideSubscription = _rideRepository.streamRideRequest(requestId).listen((request) {
      if (request == null) return;

      RideStatus activeStatus = RideStatus.driverOnWay;
      if (request.status == 'Accepted') {
        activeStatus = RideStatus.driverOnWay;
      } else if (request.status == 'DriverArriving') {
        activeStatus = RideStatus.arrived;
      } else if (request.status == 'TripStarted') {
        activeStatus = RideStatus.tripStarted;
      } else if (request.status == 'Completed') {
        emit(ActiveTripCompleted(price: offer.price, driverName: offer.driver.name));
        _rideSubscription?.cancel();
        _driverLocationSubscription?.cancel();
        return;
      } else if (request.status == 'Cancelled') {
        emit(const ActiveTripCancelled('تم إلغاء الرحلة'));
        _rideSubscription?.cancel();
        _driverLocationSubscription?.cancel();
        return;
      }

      // If active progress, update status
      if (state is ActiveTripInProgress) {
        final current = state as ActiveTripInProgress;
        emit(ActiveTripInProgress(
          requestId: requestId,
          status: activeStatus,
          driverOffer: offer,
          driverLatitude: current.driverLatitude,
          driverLongitude: current.driverLongitude,
          progress: current.progress,
        ));
      } else {
        emit(ActiveTripInProgress(
          requestId: requestId,
          status: activeStatus,
          driverOffer: offer,
        ));
      }
    });

    _driverLocationSubscription = _rideRepository.streamDriverLocation(offer.driverId).listen((data) {
      if (data != null && state is ActiveTripInProgress) {
        final current = state as ActiveTripInProgress;
        final double? lat = (data['current_latitude'] ?? data['currentLatitude'] as num?)?.toDouble();
        final double? lng = (data['current_longitude'] ?? data['currentLongitude'] as num?)?.toDouble();

        emit(ActiveTripInProgress(
          requestId: requestId,
          status: current.status,
          driverOffer: offer,
          driverLatitude: lat ?? current.driverLatitude,
          driverLongitude: lng ?? current.driverLongitude,
          progress: current.progress,
        ));
      }
    });
  }

  Future<void> driverAcceptRide(String requestId, String driverId, DriverOffer offer) async {
    emit(ActiveTripLoading());
    try {
      await _rideRepository.updateRideStatus(requestId, 'Accepted', driverId: driverId);
      await _rideRepository.updateDriverStatus(driverId: driverId, isOnline: true, isAvailable: false);
      
      // Start location updates broadcast for the driver
      await DriverLocationService.instance.startLocationUpdates(driverId);
      
      emit(ActiveTripInProgress(
        requestId: requestId,
        status: RideStatus.driverOnWay,
        driverOffer: offer,
      ));

      _rideSubscription?.cancel();
      _rideSubscription = _rideRepository.streamRideRequest(requestId).listen((request) {
        if (request == null) return;
        if (request.status == 'Cancelled') {
          emit(const ActiveTripCancelled('تم الإلغاء'));
          _rideSubscription?.cancel();
          DriverLocationService.instance.stopLocationUpdates(driverId);
        }
      });
    } catch (e) {
      emit(ActiveTripError(e.toString()));
    }
  }

  Future<void> driverArrive(String requestId) async {
    if (state is ActiveTripInProgress) {
      final current = state as ActiveTripInProgress;
      try {
        await _rideRepository.updateRideStatus(requestId, 'DriverArriving');
        emit(ActiveTripInProgress(
          requestId: requestId,
          status: RideStatus.arrived,
          driverOffer: current.driverOffer,
          driverLatitude: current.driverLatitude,
          driverLongitude: current.driverLongitude,
        ));
      } catch (e) {
        emit(ActiveTripError(e.toString()));
      }
    }
  }

  Future<void> driverStartTrip(String requestId) async {
    if (state is ActiveTripInProgress) {
      final current = state as ActiveTripInProgress;
      try {
        await _rideRepository.updateRideStatus(requestId, 'TripStarted');
        emit(ActiveTripInProgress(
          requestId: requestId,
          status: RideStatus.tripStarted,
          driverOffer: current.driverOffer,
          driverLatitude: current.driverLatitude,
          driverLongitude: current.driverLongitude,
        ));
      } catch (e) {
        emit(ActiveTripError(e.toString()));
      }
    }
  }

  Future<void> driverCompleteTrip(String requestId, String driverId, double fare) async {
    if (state is ActiveTripInProgress) {
      final current = state as ActiveTripInProgress;
      try {
        await _rideRepository.updateRideStatus(requestId, 'Completed');
        await _rideRepository.updateDriverStatus(driverId: driverId, isOnline: true, isAvailable: true);
        await DriverLocationService.instance.stopLocationUpdates(driverId);

        emit(ActiveTripCompleted(price: fare, driverName: current.driverOffer.driver.name));
      } catch (e) {
        emit(ActiveTripError(e.toString()));
      }
    }
  }

  Future<void> cancelRide(String requestId, {String cancelledBy = 'passenger', String reason = 'تم الإلغاء'}) async {
    try {
      await _rideRepository.cancelRideRequest(requestId, reason, cancelledBy: cancelledBy);
      emit(const ActiveTripCancelled('تم إلغاء الرحلة'));
    } catch (e) {
      emit(ActiveTripError(e.toString()));
    }
  }

  void reset() {
    _rideSubscription?.cancel();
    _driverLocationSubscription?.cancel();
    emit(ActiveTripInitial());
  }

  @override
  Future<void> close() {
    _rideSubscription?.cancel();
    _driverLocationSubscription?.cancel();
    return super.close();
  }
}

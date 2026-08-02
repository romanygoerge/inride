import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/repositories/ride_repository.dart';
import '../../../../core/state/global_state.dart' show DriverInfo, DriverOffer;
import '../../../../core/utils/map_coordinates_helper.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/app_logger.dart';
import 'ride_matching_state.dart';

class RideMatchingCubit extends Cubit<RideMatchingState> {
  final RideRepository _rideRepository;
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription? _rideSubscription;

  RideMatchingCubit(this._rideRepository) : super(RideMatchingInitial());

  Future<void> requestRide({
    required String passengerId,
    required String fromAddress,
    required String toAddress,
    required double offeredFare,
    required String vehicleType,
    String paymentMethod = 'كاش',
    int passengerCount = 1,
  }) async {
    emit(RideMatchingLoading());
    AppLogger.rideLog('RideMatchingCubit', 'Creating new ride request', passengerId: passengerId);

    try {
      final startLatLng = MapCoordinatesHelper.getLatLngForAddress(fromAddress);
      final endLatLng = MapCoordinatesHelper.getLatLngForAddress(toAddress);
      
      final distance = LocationService.instance.calculateDistance(
        startLatLng.latitude,
        startLatLng.longitude,
        endLatLng.latitude,
        endLatLng.longitude,
      );

      final requestId = await _rideRepository.createRideRequest(
        passengerId: passengerId,
        pickupLat: startLatLng.latitude,
        pickupLng: startLatLng.longitude,
        pickupAddress: fromAddress,
        destLat: endLatLng.latitude,
        destLng: endLatLng.longitude,
        destAddress: toAddress,
        vehicleType: vehicleType,
        offeredFare: offeredFare,
        distance: distance,
        paymentMethod: paymentMethod,
        passengerCount: passengerCount,
      );

      _listenToRideRequest(requestId, offeredFare, vehicleType);
    } catch (e, stack) {
      AppLogger.error('RideMatchingCubit', 'Error creating ride request', e, stack);
      emit(RideMatchingError(e.toString()));
    }
  }

  void _listenToRideRequest(String requestId, double offeredFare, String vehicleType) {
    _rideSubscription?.cancel();
    _rideSubscription = _rideRepository.streamRideRequest(requestId).listen((request) async {
      if (request == null) {
        emit(RideMatchingInitial());
        return;
      }

      if (request.status == 'Pending' || request.status == 'Searching') {
        emit(RideSearching(requestId: requestId, request: request));
        _queryDrivers(requestId, request, offeredFare, vehicleType);
      } else if (request.status == 'Accepted') {
        final driverUserDoc = await _supabase.from('users').select().eq('id', request.driverId!).maybeSingle();
        final driverDoc = await _supabase.from('drivers').select().eq('id', request.driverId!).maybeSingle();

        final uMap = driverUserDoc != null ? Map<String, dynamic>.from(driverUserDoc) : {};
        final dMap = driverDoc != null ? Map<String, dynamic>.from(driverDoc) : {};

        final driverName = uMap['name'] ?? 'سائق';
        final ratingCount = (uMap['rating_count'] ?? uMap['total_ratings'] as num?)?.toInt() ?? 0;
        final rating = (uMap['rating'] as num?)?.toDouble() ?? 0.0;
        final vName = dMap['vehicle_name'] ?? dMap['vehicleName'] ?? 'سيارة';
        final vNum = dMap['vehicle_number'] ?? dMap['vehicleNumber'] ?? '';

        final offer = DriverOffer(
          driverId: request.driverId!,
          driver: DriverInfo(
            name: driverName,
            rating: rating,
            ratingCount: ratingCount,
            vehicleType: request.vehicleType == 'scooter' ? 'اسكوتر' : (request.vehicleType == 'motorcycle' ? 'موتوسيكل' : 'عربية'),
            vehicleName: vName,
            vehicleColor: 'فضي',
            licensePlate: vNum,
            avatar: uMap['avatar_url'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200',
          ),
          price: request.offeredFare,
          etaMinutes: 3,
        );

        emit(DriverAccepted(requestId: requestId, request: request, acceptedOffer: offer));
      } else if (request.status == 'Cancelled') {
        emit(RideMatchingCancelled());
      } else if (request.status == 'Expired') {
        emit(RideMatchingExpired());
      }
    });
  }

  Future<void> _queryDrivers(String requestId, request, double offeredFare, String vehicleType) async {
    final startLatLng = MapCoordinatesHelper.getLatLngForAddress(request.pickupAddress);
    final drivers = await _rideRepository.searchAvailableDrivers(
      pickupLat: startLatLng.latitude,
      pickupLng: startLatLng.longitude,
      vehicleType: vehicleType,
      maxRangeKm: 15.0,
    );

    if (drivers.isNotEmpty && state is RideSearching) {
      final offers = drivers.map((d) {
        return DriverOffer(
          driverId: d['driverId'],
          driver: DriverInfo(
            name: d['driverName'],
            rating: (d['rating'] as num?)?.toDouble() ?? 0.0,
            ratingCount: (d['ratingCount'] as num?)?.toInt() ?? 0,
            vehicleType: vehicleType == 'scooter' ? 'اسكوتر' : (vehicleType == 'motorcycle' ? 'موتوسيكل' : 'عربية'),
            vehicleName: d['vehicle'].model,
            vehicleColor: d['vehicle'].color,
            licensePlate: d['vehicle'].numberPlate,
            avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=200',
          ),
          price: offeredFare,
          etaMinutes: ((d['distance'] as double) * 2).round() + 2,
        );
      }).toList();

      emit(DriverBidding(requestId: requestId, request: request, offers: offers));
    }
  }

  Future<void> acceptOffer(String requestId, DriverOffer offer) async {
    emit(RideMatchingLoading());
    try {
      await _rideRepository.acceptRideRequest(requestId: requestId, driverId: offer.driverId, offeredFare: offer.price);
    } catch (e, stack) {
      AppLogger.error('RideMatchingCubit', 'Error accepting offer', e, stack);
      emit(RideMatchingError(e.toString()));
    }
  }

  Future<void> cancelRide(String requestId, {String cancelledBy = 'passenger', String reason = 'تم الإلغاء بواسطة العميل'}) async {
    try {
      await _rideRepository.cancelRideRequest(requestId, reason, cancelledBy: cancelledBy);
      _rideSubscription?.cancel();
      emit(RideMatchingCancelled());
    } catch (e, stack) {
      AppLogger.error('RideMatchingCubit', 'Error cancelling ride', e, stack);
      emit(RideMatchingError(e.toString()));
    }
  }

  void reset() {
    _rideSubscription?.cancel();
    emit(RideMatchingInitial());
  }

  @override
  Future<void> close() {
    _rideSubscription?.cancel();
    return super.close();
  }
}

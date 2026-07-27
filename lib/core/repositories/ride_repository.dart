import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ride_request_model.dart';
import '../models/driver_model.dart';
import '../models/vehicle_model.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../models/ride_offer.dart';
import '../utils/map_coordinates_helper.dart';
import '../utils/vehicle_helper.dart';
import '../utils/uuid_generator.dart';
import '../utils/app_logger.dart';

class RideRepository {
  static final RideRepository instance = RideRepository._internal();
  factory RideRepository() => instance;
  RideRepository._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Creates a new ride request in Supabase Database with a valid v4 UUID
  Future<String> createRideRequest({
    required String passengerId,
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double destLat,
    required double destLng,
    required String destAddress,
    required String vehicleType,
    required double offeredFare,
    required double distance,
    required String paymentMethod,
    String serviceType = 'ride',
    String? packageDescription,
    String? deliveryNotes,
    int passengerCount = 1,
    bool isDeliveryLocationConfirmed = true,
    String? recipientPhone,
    String? recipientRegion,
    String? recipientStreet,
    String? recipientBuilding,
    String? recipientFloor,
    String? recipientLandmark,
    String? recipientToken,
  }) async {
    final requestId = UuidGenerator.v4();

    final newRequest = RideRequestModel(
      requestId: requestId,
      passengerId: passengerId,
      pickupLatitude: pickupLat,
      pickupLongitude: pickupLng,
      pickupAddress: pickupAddress,
      destinationLatitude: destLat,
      destinationLongitude: destLng,
      destinationAddress: destAddress,
      vehicleType: vehicleType,
      offeredFare: offeredFare,
      distance: distance,
      status: 'Pending',
      createdAt: DateTime.now(),
      paymentMethod: paymentMethod,
      serviceType: serviceType,
      packageDescription: packageDescription,
      deliveryNotes: deliveryNotes,
      passengerCount: passengerCount,
      isDeliveryLocationConfirmed: isDeliveryLocationConfirmed,
      recipientPhone: recipientPhone,
      recipientRegion: recipientRegion,
      recipientStreet: recipientStreet,
      recipientBuilding: recipientBuilding,
      recipientFloor: recipientFloor,
      recipientLandmark: recipientLandmark,
      recipientToken: recipientToken,
    );

    final map = newRequest.toDatabaseMap();
    await _supabase.from('ride_requests').upsert(map);
    debugPrint('[TripLifecycle] Created ride request: $requestId for passenger: $passengerId');
    return requestId;
  }

  /// Search for available drivers within range of pickup matching vehicle type.
  Future<List<Map<String, dynamic>>> searchAvailableDrivers({
    required double pickupLat,
    required double pickupLng,
    required String vehicleType,
    required double maxRangeKm,
  }) async {
    AppLogger.rideLog('SearchDrivers', 'Searching for eligible drivers within $maxRangeKm km', extra: {
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'vehicleType': vehicleType,
    });

    try {
      final response = await _supabase
          .from('drivers')
          .select()
          .eq('is_online', true);

      final List<Map<String, dynamic>> nearbyDrivers = [];
      int scannedCount = 0;
      int qualifiedCount = 0;

      for (var driverData in (response as List)) {
        scannedCount++;
        final driverMap = Map<String, dynamic>.from(driverData);
        final driverId = driverMap['id'] ?? driverMap['uid'];
        if (driverId == null) continue;

        final driverModel = DriverModel.fromMap(driverMap, driverId);

        final bool isOnline = driverMap['is_online'] ?? driverMap['isOnline'] ?? false;
        final bool isAvailable = driverMap['is_available'] ?? driverMap['isAvailable'] ?? true;
        final String verificationStatus = driverMap['verification_status'] ?? driverMap['verificationStatus'] ?? 'verified';

        if (!isOnline || !isAvailable || verificationStatus == 'rejected') {
          AppLogger.driverCheckLog(driverId.toString(), false, 'Online/Available/Verification check failed', details: {
            'isOnline': isOnline,
            'isAvailable': isAvailable,
            'verificationStatus': verificationStatus,
          });
          continue;
        }

        double? driverLat = driverModel.currentLatitude ?? (driverMap['current_latitude'] as num?)?.toDouble();
        double? driverLng = driverModel.currentLongitude ?? (driverMap['current_longitude'] as num?)?.toDouble();

        if (driverLat == null || driverLng == null) {
          final devLoc = MapCoordinatesHelper.deviceLocation;
          if (devLoc != null) {
            driverLat = devLoc.latitude;
            driverLng = devLoc.longitude;
          } else {
            AppLogger.driverCheckLog(driverId.toString(), false, 'Location coordinates null and no device fallback');
            continue;
          }
        }

        double distance = LocationService.instance.calculateDistance(
          pickupLat,
          pickupLng,
          driverLat,
          driverLng,
        );

        if (distance > maxRangeKm) {
          AppLogger.driverCheckLog(driverId.toString(), false, 'Distance out of range ($distance km > $maxRangeKm km)');
          continue;
        }

        String driverVehicleType = driverMap['vehicle_category'] ?? driverMap['vehicle_type'] ?? driverMap['vehicleCategory'] ?? driverMap['vehicleType'] ?? driverMap['vehicle_name'] ?? '';
        VehicleModel? vehicle;

        if (driverModel.vehicleId != null && driverModel.vehicleId.toString().isNotEmpty) {
          try {
            final vehicleRes = await _supabase
                .from('vehicles')
                .select()
                .eq('id', driverModel.vehicleId!)
                .maybeSingle();
            if (vehicleRes != null) {
              final vMap = Map<String, dynamic>.from(vehicleRes);
              vehicle = VehicleModel.fromMap(vMap, vMap['id']);
              driverVehicleType = vMap['vehicle_category'] ?? vMap['type'] ?? vehicle.type;
            }
          } catch (e) {
            AppLogger.error('SearchDrivers', 'Error fetching vehicle record for driver $driverId', e);
          }
        }

        vehicle ??= VehicleModel(
          id: driverModel.vehicleId ?? UuidGenerator.v4(),
          driverId: driverId,
          model: driverMap['vehicle_name'] ?? 'مركبة',
          numberPlate: driverMap['vehicle_number'] ?? '',
          color: 'فضي',
          type: driverVehicleType.isNotEmpty ? driverVehicleType : 'car',
        );

        if (VehicleHelper.isVehicleTypeMatching(driverVehicleType, vehicleType)) {
          qualifiedCount++;
          String name = 'سائق';
          double rating = 5.0;

          try {
            final userRes = await _supabase.from('users').select().eq('id', driverId).maybeSingle();
            if (userRes != null) {
              final uMap = Map<String, dynamic>.from(userRes);
              name = uMap['name'] ?? 'سائق';
              rating = (uMap['rating'] as num?)?.toDouble() ?? 5.0;
            }
          } catch (e) {
            AppLogger.error('SearchDrivers', 'Error fetching user record for driver $driverId', e);
          }

          nearbyDrivers.add({
            'driverId': driverId,
            'driverName': name,
            'rating': rating,
            'distance': distance,
            'driver': driverModel,
            'vehicle': vehicle,
          });
          AppLogger.driverCheckLog(driverId.toString(), true, 'Qualified driver added', details: {
            'distance': distance,
            'vehicleType': driverVehicleType,
          });
        } else {
          AppLogger.driverCheckLog(driverId.toString(), false, 'Vehicle type mismatch ($driverVehicleType vs $vehicleType)');
        }
      }

      nearbyDrivers.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      AppLogger.rideLog('SearchDrivers', 'Finished driver search: Scanned $scannedCount, Qualified $qualifiedCount, Returned ${nearbyDrivers.length}');
      return nearbyDrivers;
    } catch (e, stack) {
      AppLogger.error('SearchDrivers', 'Error executing searchAvailableDrivers', e, stack);
      return [];
    }
  }

  /// Listen to a specific ride request updates in real-time
  Stream<RideRequestModel?> streamRideRequest(String requestId) {
    AppLogger.streamLog('RideRequest', 'Subscribing to stream for requestId: $requestId');
    return _supabase
        .from('ride_requests')
        .stream(primaryKey: ['id'])
        .eq('id', requestId)
        .map((dataList) {
      if (dataList.isEmpty) return null;
      final map = Map<String, dynamic>.from(dataList.first);
      final model = RideRequestModel.fromMap(map, requestId);
      AppLogger.streamLog('RideRequest', 'Received update: status=${model.status}, driverId=${model.driverId}');
      return model;
    });
  }

  /// Atomic ride request acceptance via Supabase RPC function `accept_ride_request`.
  /// Uses PostgreSQL row-level locks (FOR UPDATE) to prevent race conditions & double acceptance.
  Future<Map<String, dynamic>> acceptRideRequest({
    required String requestId,
    required String driverId,
    double? offeredFare,
  }) async {
    AppLogger.rideLog('RideAccept', 'Initiating atomic acceptance RPC call', requestId: requestId, driverId: driverId);
    try {
      final response = await _supabase.rpc('accept_ride_request', params: {
        'p_request_id': requestId,
        'p_driver_id': driverId,
        'p_offered_fare': offeredFare,
      });

      final Map<String, dynamic> result = response is Map<String, dynamic>
          ? response
          : Map<String, dynamic>.from(response as Map);

      final bool success = result['success'] == true;
      final String code = result['code'] ?? '';
      final String message = result['message'] ?? '';

      AppLogger.rideLog('RideAccept', 'RPC response received', requestId: requestId, driverId: driverId, extra: result);

      if (!success) {
        throw Exception(message.isNotEmpty ? message : 'تعذر قبول الرحلة ($code)');
      }

      return result;
    } catch (e, stack) {
      AppLogger.error('RideAccept', 'RPC accept failed or unavailable, checking fallback...', e, stack);
      if (e.toString().contains('function') || e.toString().contains('not found') || e.toString().contains('42883')) {
        AppLogger.rideLog('RideAccept', 'RPC function accept_ride_request missing, performing safe manual update fallback', requestId: requestId, driverId: driverId);
        return await _fallbackAcceptRideRequest(requestId: requestId, driverId: driverId, offeredFare: offeredFare);
      }
      rethrow;
    }
  }

  /// Safe manual fallback for accepting ride requests
  Future<Map<String, dynamic>> _fallbackAcceptRideRequest({
    required String requestId,
    required String driverId,
    double? offeredFare,
  }) async {
    final reqRes = await _supabase.from('ride_requests').select().eq('id', requestId).maybeSingle();
    if (reqRes == null) {
      throw Exception('طلب الرحلة غير موجود');
    }
    final String currentStatus = reqRes['status'] ?? 'Pending';
    if (currentStatus != 'Pending' && currentStatus != 'Searching') {
      throw Exception('عفواً، هذه الرحلة لم تعد متاحة أو تم قبولها من كابتن آخر');
    }

    final updateData = <String, dynamic>{
      'status': 'Accepted',
      'driver_id': driverId,
    };
    if (offeredFare != null) {
      updateData['offered_fare'] = offeredFare;
    }

    await _supabase.from('ride_requests').update(updateData).eq('id', requestId);

    // Update driver status to unavailable
    await _supabase.from('drivers').update({
      'is_available': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', driverId);

    // Update offer status
    final passengerId = reqRes['passenger_id'] ?? reqRes['passengerId'] ?? '';
    if (passengerId.toString().isNotEmpty) {
      await sendOffer(
        driverId: driverId,
        passengerId: passengerId.toString(),
        requestId: requestId,
        price: offeredFare ?? ((reqRes['offered_fare'] as num?)?.toDouble() ?? 0.0),
        eta: const Duration(minutes: 3),
      );
    }

    return {
      'success': true,
      'code': 'SUCCESS_FALLBACK',
      'message': 'تم قبول الرحلة بنجاح',
      'passenger_id': passengerId,
    };
  }

  /// Update the status of a ride request using ONLY valid PostgreSQL columns
  Future<void> updateRideStatus(String requestId, String status, {String? driverId}) async {
    final updateData = <String, dynamic>{'status': status};
    if (driverId != null) {
      updateData['driver_id'] = driverId;
    }
    await _supabase.from('ride_requests').update(updateData).eq('id', requestId);
    AppLogger.rideLog('RideStatus', 'Updated status to $status', requestId: requestId, driverId: driverId);
  }

  /// Direct REST API fetch of active pending ride requests
  /// Direct REST API fetch of active pending ride requests
  Future<List<RideRequestModel>> fetchPendingRequests() async {
    try {
      final res = await _supabase
          .from('ride_requests')
          .select()
          .inFilter('status', ['Pending', 'Searching', 'pending', 'searching'])
          .order('created_at', ascending: false)
          .limit(50);

      final requests = (res as List)
          .map((data) => RideRequestModel.fromMap(Map<String, dynamic>.from(data), data['id']))
          .where((req) {
            final st = req.status.trim().toLowerCase();
            final isPendingOrSearching = st == 'pending' || st == 'searching';
            final isConfirmed = req.serviceType != 'delivery' || req.isDeliveryLocationConfirmed;
            // Freshness check: created within the last 2 hours
            final isFresh = DateTime.now().difference(req.createdAt).abs().inHours < 2;
            return isPendingOrSearching && isConfirmed && isFresh;
          })
          .toList();

      AppLogger.rideLog('FetchPending', 'Returned ${requests.length} pending requests out of ${(res as List).length} fetched rows');
      return requests;
    } catch (e, stack) {
      AppLogger.error('FetchPending', 'Error fetching pending requests', e, stack);
      return [];
    }
  }

  /// Stream of active pending requests for drivers
  Stream<List<RideRequestModel>> streamPendingRequests() {
    AppLogger.streamLog('PendingRequests', 'Subscribing for online drivers');
    return _supabase
        .from('ride_requests')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((dataList) {
      final pendingRequests = dataList
          .map((data) => RideRequestModel.fromMap(Map<String, dynamic>.from(data), data['id']))
          .where((req) {
            final st = req.status.trim().toLowerCase();
            final isPendingOrSearching = st == 'pending' || st == 'searching';
            final isConfirmed = req.serviceType != 'delivery' || req.isDeliveryLocationConfirmed;
            final isFresh = DateTime.now().difference(req.createdAt).abs().inHours < 2;
            return isPendingOrSearching && isConfirmed && isFresh;
          })
          .toList();
      AppLogger.streamLog('PendingRequests', 'Emitted ${pendingRequests.length} active pending requests from total ${dataList.length} rows');
      return pendingRequests;
    });
  }

  /// Driver updates their online/offline state using ONLY valid PostgreSQL columns
  Future<void> updateDriverStatus({
    required String driverId,
    required bool isOnline,
    required bool isAvailable,
    double? lat,
    double? lng,
  }) async {
    final updateData = <String, dynamic>{
      'is_online': isOnline,
      'is_available': isAvailable,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (lat != null) updateData['current_latitude'] = lat;
    if (lng != null) updateData['current_longitude'] = lng;

    await _supabase.from('drivers').update(updateData).eq('id', driverId);
    debugPrint('[DriverStatus] Updated driver $driverId status: isOnline=$isOnline, isAvailable=$isAvailable, lat=$lat, lng=$lng');
  }

  /// Listen to driver position in real-time
  Stream<Map<String, dynamic>?> streamDriverLocation(String driverId) {
    debugPrint('[Realtime] Subscribing to driver location stream for $driverId');
    return _supabase
        .from('drivers')
        .stream(primaryKey: ['id'])
        .eq('id', driverId)
        .map((list) {
      if (list.isEmpty) return null;
      final data = Map<String, dynamic>.from(list.first);
      debugPrint('[Realtime] Received driver location update for $driverId: lat=${data['current_latitude']}, lng=${data['current_longitude']}');
      return data;
    });
  }

  /// Cancel a ride request using ONLY valid PostgreSQL columns
  Future<void> cancelRideRequest(
    String requestId,
    String reason, {
    String cancelledBy = 'passenger',
  }) async {
    try {
      debugPrint('[TripLifecycle] Initiating cancelRideRequest for $requestId by $cancelledBy (reason: $reason)');
      
      final reqRes = await _supabase.from('ride_requests').select().eq('id', requestId).maybeSingle();
      if (reqRes == null) return;
      final currentStatus = reqRes['status'] as String?;
      if (currentStatus == 'Cancelled' || currentStatus == 'Completed') return;

      await _supabase.from('ride_requests').update({
        'status': 'Cancelled',
        'cancelled_by': cancelledBy,
        'cancel_reason': reason,
        'cancellation_reason': reason,
        'cancelled_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      final passengerId = reqRes['passenger_id'] ?? reqRes['passengerId'];
      final driverId = reqRes['driver_id'] ?? reqRes['driverId'];

      // Restore driver availability if driver was assigned
      if (driverId != null && driverId.toString().isNotEmpty) {
        try {
          await _supabase.from('drivers').update({
            'is_available': true,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', driverId.toString());
          AppLogger.rideLog('RideCancel', 'Restored driver $driverId availability to true');
        } catch (e) {
          AppLogger.error('RideCancel', 'Failed to restore driver availability', e);
        }
      }

      final targetRecipient = cancelledBy == 'driver' ? passengerId : driverId;

      if (targetRecipient != null && targetRecipient.toString().isNotEmpty) {
        unawaited(NotificationService.instance.sendNotification(
          recipientId: targetRecipient.toString(),
          title: 'تم إلغاء الرحلة ❌',
          body: cancelledBy == 'driver' ? 'قام الكابتن بإلغاء الرحلة.' : 'قام الراكب بإلغاء الرحلة.',
          type: 'cancel_trip',
          data: {
            'requestId': requestId,
            'tripId': requestId,
            'cancelledBy': cancelledBy,
            'reason': reason,
          },
        ));
      }
    } catch (e) {
      debugPrint('[TripLifecycle] Error in cancelRideRequest: $e');
    }
  }

  /// Expire a ride request due to timeout
  Future<void> markRideRequestAsExpired(String requestId) async {
    try {
      final reqRes = await _supabase.from('ride_requests').select('passenger_id').eq('id', requestId).maybeSingle();
      await _supabase.from('ride_requests').update({
        'status': 'Expired',
        'expired_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);
      debugPrint('[TripLifecycle] Marked ride request $requestId as Expired');

      if (reqRes != null && reqRes['passenger_id'] != null) {
        final passengerId = reqRes['passenger_id'].toString();
        unawaited(NotificationService.instance.sendNotification(
          recipientId: passengerId,
          title: 'انتهت فترة البحث ⏱️',
          body: 'لم يتم العثور على كابتن متاح حالياً. يمكنك إعادة طلب الرحلة.',
          type: 'ride_expired',
          data: {
            'requestId': requestId,
            'tripId': requestId,
          },
        ));
      }
    } catch (e) {
      debugPrint('[TripLifecycle] Error in markRideRequestAsExpired: $e');
    }
  }

  /// Streams nearby online and available drivers within given radius safely
  Stream<List<Map<String, dynamic>>> streamNearbyDrivers({
    required double lat,
    required double lng,
    required double radiusInKm,
    String collectionName = 'Drivers',
  }) {
    debugPrint('[Realtime] Subscribing to streamNearbyDrivers for lat=$lat, lng=$lng, radius=$radiusInKm');
    return _supabase
        .from('drivers')
        .stream(primaryKey: ['id'])
        .map((list) {
      return list.map((item) => Map<String, dynamic>.from(item)).where((driver) {
        final bool isOnline = driver['is_online'] ?? driver['isOnline'] ?? false;
        final bool isAvailable = driver['is_available'] ?? driver['isAvailable'] ?? true;
        if (!isOnline || !isAvailable) return false;

        double? dLat = ((driver['current_latitude'] ?? driver['currentLatitude']) as num?)?.toDouble();
        double? dLng = ((driver['current_longitude'] ?? driver['currentLongitude']) as num?)?.toDouble();
        
        if (dLat == null || dLng == null) {
          final devLoc = MapCoordinatesHelper.deviceLocation;
          if (devLoc != null) {
            dLat = devLoc.latitude;
            dLng = devLoc.longitude;
          } else {
            return false;
          }
        }

        final distance = LocationService.instance.calculateDistance(lat, lng, dLat, dLng);
        return distance <= radiusInKm;
      }).toList();
    });
  }

  /// Update the pickup photo URL of a ride request
  Future<void> updatePickupPhoto(String requestId, String photoUrl) async {
    await _supabase.from('ride_requests').update({
      'pickup_photo_url': photoUrl,
    }).eq('id', requestId);
    debugPrint('[TripLifecycle] Updated pickup photo for $requestId');
  }

  /// Update the delivery photo URL of a ride request
  Future<void> updateDeliveryPhoto(String requestId, String photoUrl) async {
    await _supabase.from('ride_requests').update({
      'delivery_photo_url': photoUrl,
    }).eq('id', requestId);
    debugPrint('[TripLifecycle] Updated delivery photo for $requestId');
  }

  /// Sends a ride offer from driver to passenger with valid v4 UUID and PostgreSQL columns
  Future<String> sendOffer({
    required String driverId,
    required String passengerId,
    required String requestId,
    required double price,
    required Duration eta,
  }) async {
    final offerId = UuidGenerator.v4();

    String validPassengerId = passengerId.trim();
    if (validPassengerId.isEmpty) {
      try {
        final reqRes = await _supabase.from('ride_requests').select('passenger_id').eq('id', requestId).maybeSingle();
        if (reqRes != null && reqRes['passenger_id'] != null) {
          validPassengerId = reqRes['passenger_id'].toString().trim();
        }
      } catch (e) {
        debugPrint('[sendOffer] Error resolving passenger_id: $e');
      }
    }

    final driverRes = await _supabase.from('drivers').select().eq('id', driverId).maybeSingle();
    final driverMap = driverRes != null ? Map<String, dynamic>.from(driverRes) : {};

    final userRes = await _supabase.from('users').select().eq('id', driverId).maybeSingle();
    final userMap = userRes != null ? Map<String, dynamic>.from(userRes) : {};

    final vehicleId = driverMap['vehicle_id'] ?? driverMap['vehicleId'];
    Map<String, dynamic> vehicleMap = {};
    if (vehicleId != null && vehicleId.toString().trim().isNotEmpty) {
      final vRes = await _supabase.from('vehicles').select().eq('id', vehicleId.toString().trim()).maybeSingle();
      if (vRes != null) vehicleMap = Map<String, dynamic>.from(vRes);
    }

    final offer = RideOffer(
      id: offerId,
      driverId: driverId,
      passengerId: validPassengerId,
      driverName: userMap['name'] ?? 'سائق',
      driverAvatar: userMap['avatar_url'] ?? '',
      driverRating: (userMap['rating'] as num?)?.toDouble() ?? 5.0,
      vehicleType: vehicleMap['type'] ?? 'car',
      vehicleName: vehicleMap['model'] ?? '',
      licensePlate: vehicleMap['number_plate'] ?? '',
      price: price,
      eta: eta,
      timestamp: DateTime.now(),
      status: OfferStatus.pending,
      requestId: requestId,
    ).toDatabaseMap();

    await _supabase.from('ride_offers').upsert(offer);
    debugPrint('[TripLifecycle] Driver $driverId sent offer $offerId ($price EGP) for request $requestId');
    return offerId;
  }

  /// Stream the latest offer for a specific ride request
  Stream<RideOffer?> streamRideOffer(String requestId) {
    debugPrint('[Realtime] Subscribing to streamRideOffer for requestId: $requestId');
    return _supabase
        .from('ride_offers')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)
        .map((list) {
      if (list.isEmpty) return null;
      final sortedList = List<Map<String, dynamic>>.from(list);
      sortedList.sort((a, b) {
        final aTime = DateTime.tryParse(a['created_at'] ?? a['timestamp'] ?? '') ?? DateTime(1970);
        final bTime = DateTime.tryParse(b['created_at'] ?? b['timestamp'] ?? '') ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
      final map = sortedList.first;
      final offer = RideOffer.fromMap(map);
      debugPrint('[Realtime] Received offer update: offerId=${offer.id}, status=${offer.status}, price=${offer.price}');
      return offer;
    });
  }



  /// Respond to an existing offer (accept, reject, counter)
  Future<void> respondToOffer({
    required String offerId,
    required String response,
    double? counterPrice,
  }) async {
    final updateData = <String, dynamic>{'status': response};
    if (response == 'countered' && counterPrice != null) {
      updateData['price'] = counterPrice;
    }
    await _supabase.from('ride_offers').update(updateData).eq('id', offerId);
    debugPrint('[TripLifecycle] Responded to offer $offerId with status $response');

    try {
      final docRes = await _supabase.from('ride_offers').select().eq('id', offerId).maybeSingle();
      if (docRes != null) {
        final data = Map<String, dynamic>.from(docRes);
        final driverId = data['driver_id'] ?? data['driverId'];
        final requestId = data['request_id'] ?? data['requestId'];
        if (driverId != null && driverId.toString().isNotEmpty) {
          if (response == 'rejected') {
            unawaited(NotificationService.instance.sendNotification(
              recipientId: driverId.toString(),
              title: 'تم رفض العرض ❌',
              body: 'قام الراكب برفض عرض السعر المقدم.',
              type: 'reject_offer',
              data: {
                'offerId': offerId,
                'requestId': requestId ?? '',
                'tripId': requestId ?? '',
              },
            ));
          } else if (response == 'countered' && counterPrice != null) {
            unawaited(NotificationService.instance.sendNotification(
              recipientId: driverId.toString(),
              title: 'عرض مضاد من الراكب 💰',
              body: 'اقترح الراكب سعراً جديداً: ${counterPrice.round()} ج.م',
              type: 'new_offer',
              data: {
                'offerId': offerId,
                'price': counterPrice.toString(),
                'requestId': requestId ?? '',
                'tripId': requestId ?? '',
              },
            ));
          }
        }
      }
    } catch (e) {
      debugPrint("[TripLifecycle] Error sending push notification on respondToOffer: $e");
    }
  }
}

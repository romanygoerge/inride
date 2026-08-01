import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:inride_app/core/models/place_location.dart';
import 'package:inride_app/core/services/route_provider.dart';
import 'package:inride_app/core/services/route_service.dart';
import 'package:inride_app/core/repositories/route_repository.dart';



// Mock Route Provider for deterministic test execution
class MockRouteProvider implements RouteProvider {
  @override
  Future<Map<String, dynamic>> fetchRoute(LatLng start, LatLng end) async {
    // Generate deterministic route response based on start and end coordinates
    final distance = 5420.0; // 5.42 km
    final duration = 720.0;  // 12 mins (720 seconds)

    return {
      'routes': [
        {
          'geometry': {
            'coordinates': [
              [start.longitude, start.latitude],
              [(start.longitude + end.longitude) / 2, (start.latitude + end.latitude) / 2],
              [end.longitude, end.latitude],
            ],
          },
          'distance': distance,
          'duration': duration,
          'legs': [
            {
              'steps': [
                {
                  'maneuver': {
                    'location': [start.longitude, start.latitude],
                    'type': 'depart',
                    'modifier': 'straight',
                  },
                  'distance': distance,
                  'duration': duration,
                  'name': 'شارع النيل',
                },
                {
                  'maneuver': {
                    'location': [end.longitude, end.latitude],
                    'type': 'arrive',
                    'modifier': 'straight',
                  },
                  'distance': 0.0,
                  'duration': 0.0,
                  'name': 'الجامعة الأمريكية',
                },
              ],
            },
          ],
        },
      ],
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRouteProvider mockProvider;
  late RouteRepository routeRepo;
  late RouteService routeService;

  setUp(() {
    mockProvider = MockRouteProvider();
    routeRepo = RouteRepository(provider: mockProvider);
    routeService = RouteService(repository: routeRepo);
  });

  group('Destination Selection & Route Consistency Tests', () {
    const origin = LatLng(30.0130, 31.2080); // Nile Street, Giza
    const destinationCoords = LatLng(30.0263, 31.4913); // AUC, New Cairo

    final freshSearchLocation = PlaceLocation(
      placeId: 'place_12345',
      latitude: destinationCoords.latitude,
      longitude: destinationCoords.longitude,
      placeName: 'الجامعة الأمريكية بالقاهرة',
      formattedAddress: 'الجامعة الأمريكية بالقاهرة، القاهرة الجديدة',
      timestamp: DateTime.now(),
    );

    final historySearchLocation = PlaceLocation(
      placeId: 'place_12345',
      latitude: destinationCoords.latitude,
      longitude: destinationCoords.longitude,
      placeName: 'الجامعة الأمريكية بالقاهرة',
      formattedAddress: 'الجامعة الأمريكية بالقاهرة، القاهرة الجديدة',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
    );

    test('Fresh Search and Search History locations contain identical location data', () {
      expect(freshSearchLocation.latitude, equals(historySearchLocation.latitude));
      expect(freshSearchLocation.longitude, equals(historySearchLocation.longitude));
      expect(freshSearchLocation.formattedAddress, equals(historySearchLocation.formattedAddress));
      expect(freshSearchLocation.isDuplicateOf(historySearchLocation), isTrue);
    });

    test('Fresh Search route and History route calculation produce 100% IDENTICAL metrics', () async {
      // 1. Fresh Search Route Calculation
      routeRepo.clearCache();
      final freshRoute = await routeService.getRoute(origin, LatLng(freshSearchLocation.latitude, freshSearchLocation.longitude));

      // 2. History Route Calculation
      routeRepo.clearCache();
      final historyRoute = await routeService.getRoute(origin, LatLng(historySearchLocation.latitude, historySearchLocation.longitude));

      // 3. Assertions (Requirement 11 & 12)
      expect(freshRoute.distance, equals(historyRoute.distance));
      expect(freshRoute.duration, equals(historyRoute.duration));
      expect(freshRoute.points.length, equals(historyRoute.points.length));

      for (int i = 0; i < freshRoute.points.length; i++) {
        expect(freshRoute.points[i].latitude, equals(historyRoute.points[i].latitude));
        expect(freshRoute.points[i].longitude, equals(historyRoute.points[i].longitude));
      }
    });

    test('Search History deduplication merges duplicates by placeId or normalized address/coords', () {
      final loc1 = PlaceLocation(
        placeId: 'loc_abc',
        latitude: 30.0444,
        longitude: 31.2357,
        placeName: 'ميدان التحرير',
        formattedAddress: 'ميدان التحرير، وسط البلد',
        timestamp: DateTime.now(),
      );

      final loc2 = PlaceLocation(
        placeId: 'loc_abc',
        latitude: 30.0444,
        longitude: 31.2357,
        placeName: 'ميدان التحرير',
        formattedAddress: 'ميدان التحرير، وسط البلد',
        timestamp: DateTime.now().add(const Duration(minutes: 5)),
      );

      expect(loc1.isDuplicateOf(loc2), isTrue);
    });
  });
}

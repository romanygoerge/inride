import 'package:latlong2/latlong.dart';
import '../services/route_provider.dart';

class RouteRepository {
  final RouteProvider _provider;
  final Map<String, Map<String, dynamic>> _cache = {};

  RouteRepository({required RouteProvider provider}) : _provider = provider;

  Future<Map<String, dynamic>> getRoute(LatLng start, LatLng end) async {
    // Generate a simple cache key based on coordinates with 5 decimal places (~1.1 meter accuracy)
    final key = '${start.latitude.toStringAsFixed(5)},${start.longitude.toStringAsFixed(5)}->'
        '${end.latitude.toStringAsFixed(5)},${end.longitude.toStringAsFixed(5)}';

    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    try {
      final routeData = await _provider.fetchRoute(start, end);
      _cache[key] = routeData;
      return routeData;
    } catch (e) {
      // Return cached route if network fails, or rethrow
      rethrow;
    }
  }

  void clearCache() {
    _cache.clear();
  }
}

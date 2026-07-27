import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

abstract class RouteProvider {
  Future<Map<String, dynamic>> fetchRoute(LatLng start, LatLng end);
}

class OSRMRouteProvider implements RouteProvider {
  final http.Client _client;

  OSRMRouteProvider({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<Map<String, dynamic>> fetchRoute(LatLng start, LatLng end) async {
    final url = 'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson&steps=true';

    final response = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch route from OSRM: ${response.statusCode} - ${response.body}');
    }
  }
}

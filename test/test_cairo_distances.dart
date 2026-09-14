// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:inride_app/core/data/sadat_city_geo_data.dart';

void main() {
  test('test cairo distances', () {
    final places = SadatCityGeoData.getAllPlaces();
    final harmal = places.firstWhere((p) => p.placeName.contains('هرمل'));
    final sevenStars = places.firstWhere((p) => p.placeName.contains('سفن ستارز'));
    final shami = places.firstWhere((p) => p.placeName.contains('الشامي (فرع 1)'));

    print('Harmal: ${harmal.latitude}, ${harmal.longitude}');
    print('Seven Stars: ${sevenStars.latitude}, ${sevenStars.longitude}');
    print('Shami: ${shami.latitude}, ${shami.longitude}');

    final cairo = [
      [30.0444, 31.2357, 'Cairo Center (Tahrir)'],
      [30.0130, 31.2080, 'Dokki'],
      [30.0074, 31.2089, 'Giza'],
      [30.0760, 31.2850, 'Nasr City'],
      [30.0600, 31.3200, 'Heliopolis'],
      [30.0100, 31.1400, 'Haram / Faisal'],
      [30.0300, 31.0000, '6th of October'],
    ];

    for (final c in cairo) {
      final lat = c[0] as double;
      final lng = c[1] as double;
      final name = c[2] as String;
      final dHarmal = SadatCityGeoData.calculateDistance(lat, lng, harmal.latitude, harmal.longitude);
      final dSeven = SadatCityGeoData.calculateDistance(lat, lng, sevenStars.latitude, sevenStars.longitude);
      final dShami = SadatCityGeoData.calculateDistance(lat, lng, shami.latitude, shami.longitude);
      print('$name ($lat, $lng):');
      print('  Harmal: ${dHarmal.toStringAsFixed(1)} km');
      print('  Seven Stars: ${dSeven.toStringAsFixed(1)} km');
      print('  Shami: ${dShami.toStringAsFixed(1)} km');
    }
  });
}

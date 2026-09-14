// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:inride_app/core/data/sadat_city_geo_data.dart';

void main() {
  test('SadatCityGeoData contains master database and searches accurately with distance', () {
    final all = SadatCityGeoData.getAllPlaces();
    print('Total places in SadatCityGeoData: ${all.length}');
    expect(all.length, greaterThanOrEqualTo(480));

    final testQueries = [
      'زهران',
      'الشامي',
      'طلبات مارت',
      'ولاء الوكيل',
      'حديد عز',
      'الجوهرة',
      'مستشفى السادات',
      'مرور السادات',
      'جامعة السادات',
      'دار مصر',
      'سكن مصر',
      'الموقف الاقليمي',
      'بازوكا',
      'بنك مصر',
      'كشري افندينا',
      'سيتي مول'
    ];

    for (final q in testQueries) {
      final results = SadatCityGeoData.searchLocal(
        query: q,
        userLat: 30.3789,
        userLng: 30.5182,
        limit: 3,
      );
      print('\nQuery: "$q" -> Found ${results.length} results:');
      for (final r in results) {
        print('  - ${r.placeName} | ${r.category} | ${r.localizedDistance} (${r.distanceKm} km) | ${r.formattedAddress}');
        expect(r.distanceKm, isNotNull);
        expect(r.distanceKm! >= 0, isTrue);
      }
      expect(results, isNotEmpty, reason: 'Search for "$q" should find matches');
    }
  });
}

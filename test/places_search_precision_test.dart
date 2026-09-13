import 'package:flutter_test/flutter_test.dart';
import 'package:inride_app/core/data/sadat_city_geo_data.dart';

void main() {
  group('Search Precision and Multi-Governorate Fallback Tests', () {
    test('Searching for "مطعم الشامي" never returns random Sadat restaurants', () {
      final results = SadatCityGeoData.searchLocal(
        query: 'مطعم الشامي',
        userLat: 30.3800,
        userLng: 30.5200,
        limit: 15,
      );

      final returnedNames = results.map((r) => r.placeName).toList();

      // None of the unrelated Sadat restaurants should ever appear
      expect(returnedNames.any((n) => n.contains('ماكدونالدز')), isFalse);
      expect(returnedNames.any((n) => n.contains('برجر كينج')), isFalse);
      expect(returnedNames.any((n) => n.contains('واحة السادات')), isFalse);
      expect(returnedNames.any((n) => n.contains('طشة')), isFalse);
      expect(returnedNames.any((n) => n.contains('أسماك بحري')), isFalse);
      expect(returnedNames.any((n) => n.contains('الشبراوي')), isFalse);
      expect(returnedNames.any((n) => n.contains('هارت أتاك')), isFalse);

      // Any returned results MUST match 'الشام'
      for (final r in results) {
        expect(
          r.placeName.contains('الشام') || (r.aliases.any((a) => a.contains('الشام'))),
          isTrue,
        );
      }
    });

    test('Searching for pure category "مطعم" returns restaurants', () {
      final results = SadatCityGeoData.searchLocal(
        query: 'مطعم',
        userLat: 30.3800,
        userLng: 30.5200,
        limit: 5,
      );

      expect(results.isNotEmpty, isTrue);
      for (final r in results) {
        expect(r.category, equals('restaurant'));
      }
    });

    test('Searching for specific place "طشة" only returns Tasheh', () {
      final results = SadatCityGeoData.searchLocal(
        query: 'طشة',
        userLat: 30.3800,
        userLng: 30.5200,
        limit: 5,
      );

      expect(results.isNotEmpty, isTrue);
      expect(results.first.placeName, contains('طشة'));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:inride_app/core/data/sadat_city_geo_data.dart';

void main() {
  const double userLat = 30.3789;
  const double userLng = 30.5182;

  test('Sadat City Smart Search returns expected results for common queries', () {
    final testCases = {
      'مستشفى': 'مستشفى',
      'جامعة': 'جامعة',
      'صيدلية': 'صيدلية',
      'مول': 'مول',
      'موقف السادات': 'موقف',
      'الحي السابع': 'السابعة',
      'الحي الخامس': 'الخامسة',
      'جامعة مدينة السادات': 'جامعة مدينة السادات',
      'مستشفى السادات المركزي': 'مستشفى السادات المركزي',
      'كارفور': 'كارفور',
      'كنيسة': 'كنيسة',
      'مسجد': 'مسجد',
    };

    for (final entry in testCases.entries) {
      final query = entry.key;
      final expectedSubstring = entry.value;

      final results = SadatCityGeoData.searchLocal(
        query: query,
        userLat: userLat,
        userLng: userLng,
        limit: 5,
      );

      expect(results.isNotEmpty, true, reason: 'Expected results for query "$query"');

      final matchesExpected = results.any((r) =>
          r.placeName.contains(expectedSubstring) ||
          r.formattedAddress.contains(expectedSubstring));
      expect(matchesExpected, true,
          reason: 'Expected one of the top results for "$query" to match "$expectedSubstring"');
    }
  });

  test('Newly added landmarks from user queries are accurately matched', () {
    // 1. Seven Stars Mall
    final mallResults = SadatCityGeoData.searchLocal(
      query: 'مول سفن ستارز السادات',
      userLat: userLat,
      userLng: userLng,
      limit: 3,
    );
    expect(mallResults.isNotEmpty, true);
    expect(mallResults.first.placeName.contains('سفن ستارز'), true);

    // 2. Al-Riyada University
    final riyadaResults = SadatCityGeoData.searchLocal(
      query: 'جامعة الريادة للعلوم والتكنولوجيا',
      userLat: userLat,
      userLng: userLng,
      limit: 3,
    );
    expect(riyadaResults.isNotEmpty, true);
    expect(riyadaResults.first.placeName.contains('الريادة'), true);

    // 3. Virgin Mary Church in Ebni Baitak
    final churchResults = SadatCityGeoData.searchLocal(
      query: 'كنيسة العذراء مريم',
      userLat: userLat,
      userLng: userLng,
      limit: 3,
    );
    expect(churchResults.isNotEmpty, true);
    expect(churchResults.any((r) => r.placeName.contains('العذراء')), true);

    // 4. Distinguished District (الحي المتميز)
    final motamayezResults = SadatCityGeoData.searchLocal(
      query: 'الحي المتميز',
      userLat: userLat,
      userLng: userLng,
      limit: 3,
    );
    expect(motamayezResults.isNotEmpty, true);
    expect(motamayezResults.first.placeName.contains('المتميز'), true);

    // 5. Zeytoun District (حي الزيتون)
    final zaytounResults = SadatCityGeoData.searchLocal(
      query: 'حي الزيتون',
      userLat: userLat,
      userLng: userLng,
      limit: 3,
    );
    expect(zaytounResults.isNotEmpty, true);
    expect(zaytounResults.first.placeName.contains('الزيتون'), true);
  });

  test('Fuzzy Search & Typo tolerance handles misspellings, sound-alikes, and numbers', () {
    // Typo 1: 'سفن سترز' instead of 'سفن ستارز'
    final typoMall = SadatCityGeoData.searchLocal(
      query: 'سفن سترز',
      userLat: userLat,
      userLng: userLng,
      limit: 3,
    );
    expect(typoMall.isNotEmpty, true, reason: 'Expected fuzzy match for "سفن سترز"');
    expect(typoMall.first.placeName.contains('سفن ستارز'), true);

    // Typo 2: 'رياده' instead of 'الريادة'
    final typoRiyada = SadatCityGeoData.searchLocal(
      query: 'رياده',
      userLat: userLat,
      userLng: userLng,
      limit: 3,
    );
    expect(typoRiyada.isNotEmpty, true);
    expect(typoRiyada.first.placeName.contains('الريادة'), true);

    // Typo 3: 'العزراء' with 'ز' instead of 'ذ'
    final typoChurch = SadatCityGeoData.searchLocal(
      query: 'كنيسة العزراء',
      userLat: userLat,
      userLng: userLng,
      limit: 3,
    );
    expect(typoChurch.isNotEmpty, true);
    expect(typoChurch.any((r) => r.placeName.contains('العذراء')), true);

    // Typo 4: 'مستسفي' with 'س' instead of 'ش'
    final typoHosp = SadatCityGeoData.searchLocal(
      query: 'مستسفي',
      userLat: userLat,
      userLng: userLng,
      limit: 3,
    );
    expect(typoHosp.isNotEmpty, true);
    expect(typoHosp.any((r) => r.placeName.contains('مستشفى')), true);

    // Numeric query: 'الحي 7' matches Zone 7
    final numZone7 = SadatCityGeoData.searchLocal(
      query: 'الحي 7',
      userLat: userLat,
      userLng: userLng,
      limit: 3,
    );
    expect(numZone7.isNotEmpty, true);
    expect(numZone7.first.placeId, 'SDT_AREA_007');
    expect(numZone7.first.placeName.contains('7') || numZone7.first.formattedAddress.contains('السابعة'), true);

    // Numeric query with Hindi numerals: 'منطقة ٥' matches Zone 5
    final numZone5 = SadatCityGeoData.searchLocal(
      query: 'منطقة ٥',
      userLat: userLat,
      userLng: userLng,
      limit: 3,
    );
    expect(numZone5.isNotEmpty, true);
    expect(numZone5.first.placeId, 'SDT_AREA_005');
    expect(numZone5.first.placeName.contains('5') || numZone5.first.formattedAddress.contains('الخامسة'), true);

    // Without definite article: 'متميز' matches 'الحي المتميز'
    final strippedArticle = SadatCityGeoData.searchLocal(
      query: 'متميز',
      userLat: userLat,
      userLng: userLng,
      limit: 3,
    );
    expect(strippedArticle.isNotEmpty, true);
    expect(strippedArticle.first.placeName.contains('المتميز') || strippedArticle.first.placeName.contains('المميز'), true);

    // Typo 5: 'الزتون' instead of 'الزيتون'
    final typoZaytoun = SadatCityGeoData.searchLocal(
      query: 'الزتون',
      userLat: userLat,
      userLng: userLng,
      limit: 3,
    );
    expect(typoZaytoun.isNotEmpty, true);
    expect(typoZaytoun.first.placeName.contains('الزيتون'), true);
  });

  test('Distances are accurate and within Sadat City range (< 15km), not 100+ km', () {
    final results = SadatCityGeoData.searchLocal(
      query: 'مول سفن ستارز',
      userLat: userLat,
      userLng: userLng,
      limit: 1,
    );

    expect(results.isNotEmpty, true);
    final place = results.first;
    expect(place.distanceKm != null, true);
    expect(place.distanceKm! < 10.0, true, reason: 'Distance in Sadat City should be < 10km, got ${place.distanceKm} km');
    expect(place.localizedDistance.contains('كم') || place.localizedDistance.contains('م'), true);
  });

  test('Unrelated / nonsense queries return zero results (no unwanted default places)', () {
    final results = SadatCityGeoData.searchLocal(
      query: 'xyz987qwerty12345',
      userLat: userLat,
      userLng: userLng,
      limit: 10,
    );

    expect(results.isEmpty, true, reason: 'Nonsense queries must return empty list');
  });

  test('Bounding box check for Sadat City works correctly', () {
    // Inside Sadat City
    expect(SadatCityGeoData.isInSadatCity(30.3789, 30.5182), true); // Center
    expect(SadatCityGeoData.isInSadatCity(30.3842, 30.5238), true); // Commerce Faculty
    expect(SadatCityGeoData.isInSadatCity(30.4630, 30.6010), true); // Kafr Dawoud

    // Outside Sadat City
    expect(SadatCityGeoData.isInSadatCity(31.2001, 29.8999), false); // Alexandria
    expect(SadatCityGeoData.isInSadatCity(15.3695, 44.1638), false); // Yemen
  });

  test('Comprehensive Sadat City Residential Districts & Special Areas matching', () {
    final queries = {
      'الروضة': 'SDT_DIST_RAWDA',
      'حي الروضة': 'SDT_DIST_RAWDA',
      'الفردوس': 'SDT_DIST_FARDOUS',
      'النرجس': 'SDT_DIST_NARJIS',
      'الريحان': 'SDT_DIST_RAYHAN',
      'الزيتون': 'SDT_DIST_ZAYTOUN',
      'البنفسج': 'SDT_DIST_BANAFSAJ',
      'النخيل': 'SDT_DIST_NAKHEEL',
      'الكوثر': 'SDT_DIST_KAWTHAR',
      'الزهور': 'SDT_DIST_ZOHOUR',
      'النور': 'SDT_DIST_NOUR',
      'الأشجار': 'SDT_DIST_ASHGAR',
      'الياقوت': 'SDT_DIST_YAQOUT',
      'الورود': 'SDT_DIST_WOROUD',
      'الحي المتميز': 'SDT_DIST_MOTAMAYEZ',
      'الحي المميز': 'SDT_DIST_MOTAMAYEZ',
      'الشريط المميز': 'SDT_AREA_MOTAMAYEZ_STRIP',
      'المنطقة الذهبية': 'SDT_AREA_GOLDEN_ZONE',
      'المربع الذهبي': 'SDT_AREA_GOLDEN_ZONE',
      'منطقة الفيلات': 'SDT_AREA_VILLAS',
      'البراميتر': 'SDT_AREA_PARAMETER',
      'المحور المركزي': 'SDT_AREA_CENTRAL_AXIS',
      'بيت الوطن': 'SDT_AREA_BEIT_WATAN_A',
      'ابني بيتك': 'SDT_AREA_EBNY_BETAK',
      'المنطقة 3': 'SDT_AREA_003',
      'المنطقة 14': 'SDT_AREA_014',
      'المنطقة 22': 'SDT_AREA_022',
      'المنطقة 36': 'SDT_AREA_036',
      'صناعية 1': 'SDT_IND_001',
      'منطقة المطورين': 'SDT_IND_DEVELOPERS',
    };

    for (final entry in queries.entries) {
      final q = entry.key;
      final expectedId = entry.value;
      final results = SadatCityGeoData.searchLocal(
        query: q,
        userLat: userLat,
        userLng: userLng,
        limit: 3,
      );
      expect(results.isNotEmpty, true, reason: 'Expected results for "$q"');
      expect(results.any((r) => r.placeId == expectedId), true, reason: 'Expected $expectedId in results for "$q"');
      expect(results.first.coordinatesVerified, true);
      expect(results.first.city, 'مدينة السادات');
    }
  });

  test('Typing patterns and abbreviations for Zone 21 resolve to SDT_AREA_021', () {
    final queries21 = [
      '21',
      'منطقة 21',
      'المنطقة 21',
      'المنطقه 21',
      'منطقة21',
      'المنطقة الحادية والعشرون',
      'الحادية والعشرين',
    ];

    for (final q in queries21) {
      final results = SadatCityGeoData.searchLocal(
        query: q,
        userLat: userLat,
        userLng: userLng,
        limit: 3,
      );
      expect(results.isNotEmpty, true, reason: 'Expected results for "$q"');
      expect(results.first.placeId, 'SDT_AREA_021', reason: 'Expected SDT_AREA_021 for "$q"');
      expect(results.first.coordinatesVerified, true);
    }
  });

  test('Comprehensive 25 Categories Intent Search returns actual Sadat City places', () {
    // 1. Supermarkets & Grocery
    final supermarketQueries = ['سوبر ماركت', 'سوبرماركت', 'ماركت', 'بقالة', 'هايبر', 'مواد غذائية'];
    for (final q in supermarketQueries) {
      final res = SadatCityGeoData.searchLocal(query: q, userLat: userLat, userLng: userLng, limit: 5);
      expect(res.isNotEmpty, true, reason: 'Expected results for $q');
      expect(res.any((p) => p.category == 'supermarket'), true, reason: 'Expected supermarket for $q');
      expect(res.first.distanceKm! < 15.0, true);
    }

    // 2. Restaurants
    final restaurantQueries = ['مطاعم', 'مطعم', 'مشويات', 'بيتزا', 'كريب'];
    for (final q in restaurantQueries) {
      final res = SadatCityGeoData.searchLocal(query: q, userLat: userLat, userLng: userLng, limit: 5);
      expect(res.isNotEmpty, true, reason: 'Expected results for $q');
      expect(res.any((p) => p.category == 'restaurant'), true, reason: 'Expected restaurant for $q');
    }

    // 3. Cafes
    final cafeQueries = ['كافيهات', 'كافيه', 'قهوة', 'كوفي شوب'];
    for (final q in cafeQueries) {
      final res = SadatCityGeoData.searchLocal(query: q, userLat: userLat, userLng: userLng, limit: 5);
      expect(res.isNotEmpty, true, reason: 'Expected results for $q');
      expect(res.any((p) => p.category == 'cafe'), true);
    }

    // 4. Pharmacies
    final pharmacyQueries = ['صيدليات', 'صيدلية', 'علاج', 'دواء'];
    for (final q in pharmacyQueries) {
      final res = SadatCityGeoData.searchLocal(query: q, userLat: userLat, userLng: userLng, limit: 5);
      expect(res.isNotEmpty, true, reason: 'Expected results for $q');
      expect(res.any((p) => p.category == 'pharmacy' || p.placeName.contains('صيدلية')), true);
    }

    // 5. Clothing & Fashion
    final clothesRes = SadatCityGeoData.searchLocal(query: 'ملابس', userLat: userLat, userLng: userLng, limit: 5);
    expect(clothesRes.isNotEmpty, true);
    expect(clothesRes.any((p) => p.category == 'clothing'), true);

    // 6. Mobile & Electronics
    final mobileRes = SadatCityGeoData.searchLocal(query: 'موبايلات', userLat: userLat, userLng: userLng, limit: 5);
    expect(mobileRes.isNotEmpty, true);
    expect(mobileRes.any((p) => p.category == 'electronics'), true);

    // 7. Butchers & Meat
    final butcherRes = SadatCityGeoData.searchLocal(query: 'جزارات', userLat: userLat, userLng: userLng, limit: 5);
    expect(butcherRes.isNotEmpty, true);
    expect(butcherRes.any((p) => p.category == 'butcher'), true);

    // 8. Bakeries
    final bakeryRes = SadatCityGeoData.searchLocal(query: 'مخابز', userLat: userLat, userLng: userLng, limit: 5);
    expect(bakeryRes.isNotEmpty, true);
    expect(bakeryRes.any((p) => p.category == 'bakery'), true);

    // 9. Automotive & Car repair
    final autoRes = SadatCityGeoData.searchLocal(query: 'قطع غيار', userLat: userLat, userLng: userLng, limit: 5);
    expect(autoRes.isNotEmpty, true);
    expect(autoRes.any((p) => p.category == 'automotive'), true);

    // 10. Maintenance & Workshops
    final maintRes = SadatCityGeoData.searchLocal(query: 'صيانة', userLat: userLat, userLng: userLng, limit: 5);
    expect(maintRes.isNotEmpty, true);
    expect(maintRes.any((p) => p.category == 'maintenance'), true);

    // 11. Gas stations
    final gasRes = SadatCityGeoData.searchLocal(query: 'بنزين', userLat: userLat, userLng: userLng, limit: 5);
    expect(gasRes.isNotEmpty, true);
    expect(gasRes.any((p) => p.category == 'gas_station' || p.placeName.contains('وقود')), true);

    // 12. Factories & Industrial
    final factoryRes = SadatCityGeoData.searchLocal(query: 'مصانع', userLat: userLat, userLng: userLng, limit: 5);
    expect(factoryRes.isNotEmpty, true);
    expect(factoryRes.any((p) => p.category == 'factory' || p.placeType == 'industrial_area'), true);

    // 13. Government
    final govRes = SadatCityGeoData.searchLocal(query: 'حكومي', userLat: userLat, userLng: userLng, limit: 5);
    expect(govRes.isNotEmpty, true);
    expect(govRes.any((p) => p.category == 'government'), true);

    // 14. Transport
    final transportRes = SadatCityGeoData.searchLocal(query: 'مواقف', userLat: userLat, userLng: userLng, limit: 5);
    expect(transportRes.isNotEmpty, true);
    expect(transportRes.any((p) => p.category == 'transport' || p.placeName.contains('موقف')), true);
  });

  test('Exact store names and shops inside malls are matched with verified metadata', () {
    // 1. Exact shop name: 'شعلان' (Both branches in Zone 1 & Central Axis verified)
    final shaalan = SadatCityGeoData.searchLocal(query: 'شعلان', userLat: userLat, userLng: userLng, limit: 3);
    expect(shaalan.isNotEmpty, true);
    expect(shaalan.first.placeName.contains('شعلان'), true);
    expect(shaalan.any((p) => p.placeId == 'SDT_SHP_SUP_001'), true);
    expect(shaalan.any((p) => p.placeId == 'SDT_SHP_SUP_001_B'), true);

    // 2. Exact restaurant: 'البرنس'
    final prince = SadatCityGeoData.searchLocal(query: 'البرنس', userLat: userLat, userLng: userLng, limit: 3);
    expect(prince.isNotEmpty, true);
    expect(prince.any((p) => p.placeName.contains('البرنس') && p.category == 'restaurant'), true);

    // 3. Exact pharmacy: 'العزبي'
    final ezaby = SadatCityGeoData.searchLocal(query: 'العزبي', userLat: userLat, userLng: userLng, limit: 3);
    expect(ezaby.isNotEmpty, true);
    expect(ezaby.first.placeName.contains('العزبي'), true);
    expect(ezaby.any((p) => p.placeId == 'SDT_SHP_PHM_001_A' || p.placeId == 'SDT_SHP_PHM_001_B'), true);

    // 4. Shop inside mall: Brand Store inside City Mall
    final brandStore = SadatCityGeoData.searchLocal(query: 'براند ستور', userLat: userLat, userLng: userLng, limit: 3);
    expect(brandStore.isNotEmpty, true);
    expect(brandStore.first.mallName, 'سيتي مول');
    expect(brandStore.first.category, 'clothing');

    // 5. Searching mall name returns shops inside that mall
    final cityMallShops = SadatCityGeoData.searchLocal(query: 'سيتي مول', userLat: userLat, userLng: userLng, limit: 5);
    expect(cityMallShops.isNotEmpty, true);
    expect(cityMallShops.any((p) => p.mallName == 'سيتي مول'), true);

    // 6. Major industrial factory: 'سيراميكا رويال'
    final royal = SadatCityGeoData.searchLocal(query: 'سيراميكا رويال', userLat: userLat, userLng: userLng, limit: 3);
    expect(royal.isNotEmpty, true);
    expect(royal.first.category, 'factory');
    expect(royal.first.district, 'المنطقة الصناعية الثانية');
  });
}


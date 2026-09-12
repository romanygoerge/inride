import 'package:flutter_test/flutter_test.dart';
import 'package:inride_app/core/utils/map_coordinates_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapCoordinatesHelper.extractCoordinatesFromText tests', () {
    test('parses direct decimal coordinates', () async {
      final res = await MapCoordinatesHelper.extractCoordinatesFromText('30.3852, 30.5123');
      expect(res, isNotNull);
      expect(res!.latitude, closeTo(30.3852, 0.0001));
      expect(res.longitude, closeTo(30.5123, 0.0001));
    });

    test('parses Google Maps @lat,lng format', () async {
      final res = await MapCoordinatesHelper.extractCoordinatesFromText('https://www.google.com/maps/@30.38521,30.51234,17z');
      expect(res, isNotNull);
      expect(res!.latitude, closeTo(30.38521, 0.0001));
      expect(res.longitude, closeTo(30.51234, 0.0001));
    });

    test('parses Google Maps ?q=lat,lng format', () async {
      final res = await MapCoordinatesHelper.extractCoordinatesFromText('https://www.google.com/maps?q=30.3852,30.5123');
      expect(res, isNotNull);
      expect(res!.latitude, closeTo(30.3852, 0.0001));
      expect(res.longitude, closeTo(30.5123, 0.0001));
    });

    test('parses Google Maps protobuf !3d/!4d format', () async {
      final res = await MapCoordinatesHelper.extractCoordinatesFromText('https://www.google.com/maps/place/Sadat/data=!3d30.38521!4d30.51234');
      expect(res, isNotNull);
      expect(res!.latitude, closeTo(30.38521, 0.0001));
      expect(res.longitude, closeTo(30.51234, 0.0001));
    });

    test('parses Apple Maps ?ll=lat,lng format', () async {
      final res = await MapCoordinatesHelper.extractCoordinatesFromText('http://maps.apple.com/?ll=30.3852,30.5123&q=Marker');
      expect(res, isNotNull);
      expect(res!.latitude, closeTo(30.3852, 0.0001));
      expect(res.longitude, closeTo(30.5123, 0.0001));
    });

    test('parses DMS format from pin info', () async {
      final res = await MapCoordinatesHelper.extractCoordinatesFromText('30°23\'06.7"N 30°30\'44.3"E');
      expect(res, isNotNull);
      expect(res!.latitude, closeTo(30.38519, 0.001));
      expect(res.longitude, closeTo(30.5123, 0.001));
    });

    test('parses multi-line Arabic shared text from Google Maps', () async {
      final res = await MapCoordinatesHelper.extractCoordinatesFromText(
        'موقع تمت مشاركته بالقرب من المنطقة الأولى، السادات\nhttps://www.google.com/maps?q=30.3852,30.5123',
      );
      expect(res, isNotNull);
      expect(res!.latitude, closeTo(30.3852, 0.0001));
      expect(res.longitude, closeTo(30.5123, 0.0001));
    });
  });
}

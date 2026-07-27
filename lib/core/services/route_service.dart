import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../repositories/route_repository.dart';
import '../models/route_model.dart';

class RouteService {
  final RouteRepository _repository;

  RouteService({required RouteRepository repository}) : _repository = repository;

  Future<RouteModel> getRoute(LatLng start, LatLng end) async {
    try {
      final json = await _repository.getRoute(start, end);
      
      final routes = json['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        return RouteModel.empty();
      }

      final route = routes[0];
      final geometry = route['geometry'];
      final coordinates = geometry['coordinates'] as List;
      
      final List<LatLng> points = coordinates.map((coord) {
        final list = coord as List;
        return LatLng(list[1].toDouble(), list[0].toDouble());
      }).toList();

      final distance = (route['distance'] as num).toDouble();
      final duration = (route['duration'] as num).toDouble();

      final legs = route['legs'] as List?;
      final List<RouteStep> steps = [];

      if (legs != null && legs.isNotEmpty) {
        final rawSteps = legs[0]['steps'] as List?;
        if (rawSteps != null) {
          for (int s = 0; s < rawSteps.length; s++) {
            final step = rawSteps[s];
            final maneuver = step['maneuver'];
            final location = maneuver['location'] as List;
            final position = LatLng(location[1].toDouble(), location[0].toDouble());
            final stepDistance = (step['distance'] as num).toDouble();
            final stepDuration = (step['duration'] as num).toDouble();
            final streetName = step['name'] as String? ?? '';
            final type = maneuver['type'] as String? ?? 'turn';
            final modifier = maneuver['modifier'] as String?;

            // Extract turn angle from OSRM bearing data
            final bearingBefore = (maneuver['bearing_before'] as num?)?.toDouble() ?? 0.0;
            final bearingAfter = (maneuver['bearing_after'] as num?)?.toDouble() ?? 0.0;
            double maneuverDegree = (bearingAfter - bearingBefore) % 360;
            if (maneuverDegree > 180) maneuverDegree -= 360;
            if (maneuverDegree < -180) maneuverDegree += 360;

            // Extract roundabout exit number
            final exitNumber = maneuver['exit'] as int?;

            // Determine the next street name (from the subsequent step)
            String nextStreetName = '';
            if (s + 1 < rawSteps.length) {
              nextStreetName = rawSteps[s + 1]['name'] as String? ?? '';
            }

            final index = _findClosestPointIndex(points, position);
            final instruction = _generateArabicInstruction(
              type, modifier, streetName, stepDistance,
              exitNumber: exitNumber,
              nextStreetName: nextStreetName,
            );

            steps.add(RouteStep(
              position: position,
              distance: stepDistance,
              duration: stepDuration,
              streetName: streetName,
              nextStreetName: nextStreetName,
              instruction: instruction,
              maneuverType: type,
              maneuverModifier: modifier ?? '',
              pointIndex: index,
              maneuverDegree: maneuverDegree,
              exitNumber: exitNumber,
            ));
          }
        }
      }

      // If no steps parsed, create default depart/arrive steps
      if (steps.isEmpty) {
        steps.add(RouteStep(
          position: start,
          distance: distance,
          duration: duration,
          streetName: '',
          instruction: 'تحرك نحو وجهتك مباشرة',
          maneuverType: 'depart',
          maneuverModifier: '',
          pointIndex: 0,
        ));
        steps.add(RouteStep(
          position: end,
          distance: 0.0,
          duration: 0.0,
          streetName: '',
          instruction: 'لقد وصلت لوجهتك',
          maneuverType: 'arrive',
          maneuverModifier: '',
          pointIndex: points.length - 1,
        ));
      }

      return RouteModel(
        points: points,
        distance: distance,
        duration: duration,
        steps: steps,
      );
    } catch (e) {
      debugPrint('[RouteService] Error parsing route: $e');
      // Fallback straight line
      final points = [start, end];
      final steps = [
        RouteStep(
          position: start,
          distance: 1000.0,
          duration: 120.0,
          streetName: '',
          instruction: 'اتبع الخط المباشر على الخريطة',
          maneuverType: 'depart',
          maneuverModifier: '',
          pointIndex: 0,
        ),
        RouteStep(
          position: end,
          distance: 0,
          duration: 0,
          streetName: '',
          instruction: 'وصلت للوجهة',
          maneuverType: 'arrive',
          maneuverModifier: '',
          pointIndex: 1,
        ),
      ];
      return RouteModel(
        points: points,
        distance: 1000.0,
        duration: 120.0,
        steps: steps,
      );
    }
  }

  int _findClosestPointIndex(List<LatLng> points, LatLng target) {
    int closestIndex = 0;
    double minDistance = double.maxFinite;
    for (int i = 0; i < points.length; i++) {
      final dist = _distanceSq(points[i], target);
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  double _distanceSq(LatLng p1, LatLng p2) {
    final dy = p1.latitude - p2.latitude;
    final dx = p1.longitude - p2.longitude;
    return dy * dy + dx * dx;
  }

  /// Generates a comprehensive Arabic navigation instruction from OSRM maneuver data.
  String _generateArabicInstruction(
    String type,
    String? modifier,
    String streetName,
    double distance, {
    int? exitNumber,
    String nextStreetName = '',
  }) {
    final distStr = distance > 999 
        ? '${(distance / 1000).toStringAsFixed(1)} كم' 
        : '${distance.round()} متر';
        
    final street = streetName.isEmpty ? '' : 'شارع $streetName';
    final nextStreet = nextStreetName.isEmpty ? '' : nextStreetName;

    switch (type) {
      case 'depart':
        if (street.isNotEmpty) {
          return 'ابدأ التحرك باتجاه $street';
        }
        return 'ابدأ التحرك نحو وجهتك';

      case 'arrive':
        if (modifier == 'left') return 'وصلت إلى الوجهة، على يسارك';
        if (modifier == 'right') return 'وصلت إلى الوجهة، على يمينك';
        return 'وصلت إلى وجهتك';

      case 'turn':
        final dir = _translateModifier(modifier);
        final target = nextStreet.isNotEmpty ? 'إلى شارع $nextStreet' : (street.isNotEmpty ? 'في $street' : '');
        return 'بعد $distStr انعطف $dir $target'.trim();

      case 'new name':
      case 'continue':
        if (street.isNotEmpty) {
          return 'بعد $distStr استمر في $street';
        }
        return 'بعد $distStr استمر للأمام';

      case 'roundabout':
      case 'rotary':
        final exitStr = _translateExitNumber(exitNumber);
        if (exitStr != null) {
          final target = nextStreet.isNotEmpty ? 'نحو شارع $nextStreet' : '';
          return 'بعد $distStr ادخل الدوار وخذ المخرج $exitStr $target'.trim();
        }
        return 'بعد $distStr ادخل الدوار واستمر';

      case 'roundabout turn':
        final dir = _translateModifier(modifier);
        return 'بعد $distStr عند الدوار اتجه $dir';

      case 'merge':
        final dir = _translateModifier(modifier);
        final target = street.isNotEmpty ? 'نحو $street' : '';
        return 'بعد $distStr اندمج $dir في الطريق $target'.trim();

      case 'on ramp':
      case 'ramp':
        final target = street.isNotEmpty ? 'نحو $street' : '';
        return 'بعد $distStr اسلك المدخل $target'.trim();

      case 'off ramp':
        final target = street.isNotEmpty ? 'نحو $street' : '';
        return 'بعد $distStr اسلك المخرج $target'.trim();

      case 'fork':
        final dir = _translateModifier(modifier);
        final target = street.isNotEmpty ? 'نحو $street' : '';
        return 'بعد $distStr تفرع $dir $target'.trim();

      case 'end of road':
        final dir = _translateModifier(modifier);
        return 'بعد $distStr نهاية الطريق، اتجه $dir';

      case 'notification':
        return street.isNotEmpty ? 'ملاحظة: $street' : 'استمر في طريقك';

      default:
        if (modifier != null) {
          final dir = _translateModifier(modifier);
          final target = street.isNotEmpty ? 'نحو $street' : '';
          return 'بعد $distStr اتجه $dir $target'.trim();
        }
        return 'بعد $distStr تابع في المسار';
    }
  }

  String _translateModifier(String? modifier) {
    switch (modifier) {
      case 'left':
        return 'يساراً';
      case 'right':
        return 'يميناً';
      case 'slight left':
        return 'قليلاً لليسار';
      case 'slight right':
        return 'قليلاً لليمين';
      case 'sharp left':
        return 'يساراً بشكل حاد';
      case 'sharp right':
        return 'يميناً بشكل حاد';
      case 'straight':
        return 'مباشرة للأمام';
      case 'uturn':
        return 'بالدوران للخلف';
      default:
        return 'للأمام';
    }
  }

  /// Translates exit number to ordinal Arabic.
  String? _translateExitNumber(int? exitNumber) {
    if (exitNumber == null) return null;
    switch (exitNumber) {
      case 1: return 'الأول';
      case 2: return 'الثاني';
      case 3: return 'الثالث';
      case 4: return 'الرابع';
      case 5: return 'الخامس';
      case 6: return 'السادس';
      default: return 'رقم $exitNumber';
    }
  }
}

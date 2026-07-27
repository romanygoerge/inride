import 'package:flutter/foundation.dart';

/// Professional Logger for InRide Application
/// Standardized logging across all ride flow phases:
/// - Ride Creation
/// - Driver Search & Qualifications
/// - Request Dispatching & Receipt
/// - Ride Acceptance & RPC Locking
/// - Stream Lifecycle & Exceptions
class AppLogger {
  static const String _tag = '[InRide]';

  /// Log ride lifecycle events
  static void rideLog(
    String stage,
    String message, {
    String? requestId,
    String? driverId,
    String? passengerId,
    Map<String, dynamic>? extra,
  }) {
    final buffer = StringBuffer('$_tag [$stage]');
    if (requestId != null && requestId.isNotEmpty) {
      buffer.write(' [Req: $requestId]');
    }
    if (driverId != null && driverId.isNotEmpty) {
      buffer.write(' [Drv: $driverId]');
    }
    if (passengerId != null && passengerId.isNotEmpty) {
      buffer.write(' [Pax: $passengerId]');
    }
    buffer.write(' -> $message');

    if (extra != null && extra.isNotEmpty) {
      buffer.write(' | Data: $extra');
    }

    debugPrint(buffer.toString());
  }

  /// Log driver qualification evaluation steps
  static void driverCheckLog(
    String driverId,
    bool passed,
    String reason, {
    Map<String, dynamic>? details,
  }) {
    final status = passed ? '✅ QUALIFIED' : '❌ DISQUALIFIED';
    debugPrint('$_tag [DriverCheck] Driver $driverId -> $status ($reason)${details != null ? ' | Details: $details' : ''}');
  }

  /// Log error exceptions with full details & stack trace
  static void error(
    String stage,
    String message,
    dynamic error, [
    StackTrace? stackTrace,
  ]) {
    debugPrint('🚨 $_tag ERROR [$stage] -> $message: $error');
    if (stackTrace != null) {
      debugPrint('Stack Trace:\n$stackTrace');
    }
  }

  /// Log Realtime stream events
  static void streamLog(String streamName, String event, {dynamic data}) {
    debugPrint('⚡ $_tag [Stream:$streamName] -> $event${data != null ? ' | Data: $data' : ''}');
  }
}

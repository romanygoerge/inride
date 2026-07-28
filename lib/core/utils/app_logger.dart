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

  /// Driver Registration Event
  static void driverRegistrationLog(String message, {String? driverId, Map<String, dynamic>? extra}) {
    debugPrint('📝 $_tag [DriverRegistration] ${driverId != null ? "[Driver: $driverId] " : ""}$message ${extra != null ? "| Data: $extra" : ""}');
  }

  /// Document Upload Event
  static void documentUploadLog(String docType, String status, {String? url}) {
    debugPrint('📤 $_tag [DocumentUpload] $docType -> $status ${url != null ? "($url)" : ""}');
  }

  /// Approval Event
  static void approvalLog(String driverId, String status, {String? reason}) {
    debugPrint('✅ $_tag [DriverApproval] Driver: $driverId -> Status: $status ${reason != null ? "| Reason: $reason" : ""}');
  }

  /// Push Notification Event
  static void pushNotificationLog(String recipientId, String title, String body, {bool success = true}) {
    debugPrint('${success ? "🔔" : "❌"} $_tag [PushNotification] Recipient: $recipientId | Title: "$title" | Body: "$body"');
  }

  /// Logout Event
  static void logoutLog(String userId, String status) {
    debugPrint('🚪 $_tag [Logout] User: $userId -> $status');
  }

  /// Session Restore Event
  static void sessionRestoreLog(String userId, {required bool isOffline, String? role}) {
    debugPrint('🔄 $_tag [SessionRestore] User: $userId | Role: $role | OfflineMode: $isOffline');
  }

  /// Offline Detection Event
  static void offlineLog(String message) {
    debugPrint('📶 $_tag [OfflineDetection] $message');
  }

  /// Supabase Error Event
  static void supabaseErrorLog(String context, dynamic error, [StackTrace? stackTrace]) {
    debugPrint('💥 $_tag [SupabaseError:$context] -> $error');
    if (stackTrace != null) debugPrint('Stack: $stackTrace');
  }
}


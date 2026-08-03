/// Custom Exceptions for Admin Authentication Workflow
library;

/// Base exception for admin authentication failures
class AdminAuthException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AdminAuthException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'AdminAuthException: $message ${code != null ? '($code)' : ''}';
}

/// Thrown when an authenticated user is not registered in the `admins` table or `is_active` is false
class AccessDeniedException extends AdminAuthException {
  const AccessDeniedException([
    super.message = 'Access Denied: You do not have administrator permissions or your account has been deactivated.',
    String? code = 'ACCESS_DENIED',
  ]) : super(code: code);
}

/// Thrown when user credentials (email or password) are invalid
class InvalidCredentialsException extends AdminAuthException {
  const InvalidCredentialsException([
    super.message = 'Invalid email address or password. Please check your credentials.',
    String? code = 'INVALID_CREDENTIALS',
  ]) : super(code: code);
}

/// Thrown when the user session has expired or is invalid
class SessionExpiredException extends AdminAuthException {
  const SessionExpiredException([
    super.message = 'Your session has expired. Please log in again to continue.',
    String? code = 'SESSION_EXPIRED',
  ]) : super(code: code);
}

/// Thrown when network connectivity fails
class NetworkException extends AdminAuthException {
  const NetworkException([
    super.message = 'Network error. Please check your internet connection and try again.',
    String? code = 'NETWORK_ERROR',
  ]) : super(code: code);
}



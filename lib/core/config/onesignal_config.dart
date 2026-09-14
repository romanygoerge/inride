/// OneSignal Client Push Notification Configuration
/// All REST API master keys are strictly managed on the backend server (fcm_backend / Vercel API)
/// to comply with Security Standards and prevent exposing private credentials in Flutter client.
class OneSignalConfig {
  /// OneSignal Public App ID (Used exclusively for client SDK initialization)
  static String get appId => _appIdOverride ?? const String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '388d1944-0b83-4942-8f80-b12584def7d7',
  );

  static String? _appIdOverride;

  /// Set Public App ID dynamically at runtime if needed
  static void setAppId(String? appId) {
    if (appId != null && appId.isNotEmpty) _appIdOverride = appId;
  }

  /// Backend Push Server URL for dispatching push notifications securely
  static String get backendPushUrl => const String.fromEnvironment(
    'BACKEND_PUSH_URL',
    defaultValue: 'https://inride-push-backend.vercel.app/api',
  );

  /// Secret Header Key used between Flutter client and Backend Push Server
  static String get backendSecretKey => const String.fromEnvironment(
    'APP_PUSH_SECRET_KEY',
    defaultValue: 'inride_secure_push_secret_2026_prod',
  );

  /// Check if client App ID is configured
  static bool get isAppConfigured =>
      appId.isNotEmpty && appId != 'YOUR_ONESIGNAL_APP_ID';

  /// Legacy getter compatibility
  static bool get isConfigured => isAppConfigured;
}

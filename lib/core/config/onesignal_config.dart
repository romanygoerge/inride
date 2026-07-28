/// OneSignal Client Push Notification Configuration
/// Note: REST API master keys are handled securely by backend server (fcm_backend)
/// to comply with Security Requirements and prevent exposing private credentials in Flutter client.
class OneSignalConfig {
  /// OneSignal Public App ID
  static String get appId => _appIdOverride ?? const String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '388d1944-0b83-4942-8f80-b12584def7d7',
  );

  static String? _appIdOverride;
  static String? _restApiKeyOverride;

  /// OneSignal REST API Key
  static String get restApiKey => _restApiKeyOverride ?? const String.fromEnvironment(
    'ONESIGNAL_REST_API_KEY',
    defaultValue: 'os_v2_app_999999999999999999999999',
  );

  /// Set App ID & REST API Key dynamically at runtime if needed
  static void setCredentials({String? appId, String? restApiKey}) {
    if (appId != null && appId.isNotEmpty) _appIdOverride = appId;
    if (restApiKey != null && restApiKey.isNotEmpty) _restApiKeyOverride = restApiKey;
  }

  /// Direct OneSignal REST API endpoint
  static const String directOneSignalApiUrl = 'https://api.onesignal.com/notifications';

  /// Backend Push Server URL for dispatching push notifications securely
  static String get backendPushUrl => const String.fromEnvironment(
    'BACKEND_PUSH_URL',
    defaultValue: 'https://inride-push-backend.vercel.app/api',
  );

  /// Check if client App ID is configured
  static bool get isAppConfigured =>
      appId.isNotEmpty && appId != 'YOUR_ONESIGNAL_APP_ID';

  /// Legacy getter compatibility for debug page
  static bool get isConfigured => isAppConfigured;
}

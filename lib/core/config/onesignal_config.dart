/// OneSignal Push Notification Configuration
class OneSignalConfig {
  /// OneSignal App ID
  static const String appId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '388d1944-0b83-4942-8f80-b12584def7d7',
  );

  /// OneSignal REST API Key
  static const String restApiKey = String.fromEnvironment(
    'ONESIGNAL_REST_API_KEY',
    defaultValue: 'YOUR_ONESIGNAL_REST_API_KEY',
  );

  /// هل الإعدادات مجهزة
  static bool get isConfigured =>
      appId != 'YOUR_ONESIGNAL_APP_ID' &&
      restApiKey != 'YOUR_ONESIGNAL_REST_API_KEY' &&
      restApiKey.isNotEmpty;
}

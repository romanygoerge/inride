/// Meta / Facebook App & Events Configuration
/// Keeps credentials safe and configurable via environment variables or runtime overrides.
/// No private App Secrets should ever be committed to the client-side code.
class MetaConfig {
  /// Meta / Facebook App ID
  /// Pass via `--dart-define=META_APP_ID=...` or update in strings.xml / Info.plist
  static String get appId => _appIdOverride ?? const String.fromEnvironment(
    'META_APP_ID',
    defaultValue: '2257620351655440',
  );

  /// Meta Client Token (public client token from App Settings -> Advanced)
  /// Pass via `--dart-define=META_CLIENT_TOKEN=...` or update in strings.xml / Info.plist
  static String get clientToken => _clientTokenOverride ?? const String.fromEnvironment(
    'META_CLIENT_TOKEN',
    defaultValue: '6b4d59c741c1b5b5bd1016d26d75f003',
  );

  /// App Display Name
  static const String appName = 'inRide';

  static String? _appIdOverride;
  static String? _clientTokenOverride;

  /// Set App ID dynamically at runtime if loaded from remote config
  static void setAppId(String? id) {
    if (id != null && id.isNotEmpty) _appIdOverride = id;
  }

  /// Set Client Token dynamically at runtime
  static void setClientToken(String? token) {
    if (token != null && token.isNotEmpty) _clientTokenOverride = token;
  }

  /// Whether the SDK has been configured with real IDs
  static bool get isConfigured =>
      appId.isNotEmpty &&
      appId != 'YOUR_FACEBOOK_APP_ID' &&
      clientToken.isNotEmpty &&
      clientToken != 'YOUR_FACEBOOK_CLIENT_TOKEN';
}

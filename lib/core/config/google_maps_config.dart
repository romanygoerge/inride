/// Google Maps & Places Service Configuration
/// Google Maps API Web Service keys must NEVER be stored inside Flutter client APK/IPA.
/// All text searches and geocoding queries are proxied via secure Backend / Supabase Edge Functions.
class GoogleMapsConfig {
  /// Optional client API key override (only if restricted by Android/iOS Bundle ID in Native SDKs)
  static const String apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');

  /// Backend Places Proxy URL (Keeps Google API Key strictly on the server)
  static String get backendPlacesProxyUrl => const String.fromEnvironment(
    'BACKEND_PLACES_PROXY_URL',
    defaultValue: 'https://inride-5efp.vercel.app/api/places-search',
  );

  /// Always true since the secure backend proxy handles place queries
  static bool get isConfigured => true;
}


import 'dart:math';

/// Utility class for generating RFC 4122 compliant v4 UUID strings.
class UuidGenerator {
  static final Random _random = Random.secure();

  /// Generates a random v4 UUID string (e.g. "f47ac10b-58cc-4372-a567-0e02b2c3d479").
  static String v4() {
    final List<int> bytes = List<int>.generate(16, (_) => _random.nextInt(256));

    // Set version to 4 (0100)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Set variant to IETF (10xx)
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final String hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}

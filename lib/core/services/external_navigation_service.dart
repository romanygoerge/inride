import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:google_fonts/google_fonts.dart';

class ExternalNavigationService {
  /// Opens the default or best available external navigation app (Google Maps/Apple Maps)
  /// pointing to the given [latitude] and [longitude].
  static Future<void> launchNavigation(
    BuildContext context,
    double latitude,
    double longitude, {
    bool isHeadingToPickup = false,
  }) async {
    // 1. Android Specific Permissions for overlay if heading to pickup
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && isHeadingToPickup) {
      final bool status = await FlutterOverlayWindow.isPermissionGranted();
      if (!status) {
        await FlutterOverlayWindow.requestPermission();
      }
    }

    // 2. Check availability on iOS
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {

      final bool hasGoogleMaps = await canLaunchUrl(Uri.parse('comgooglemaps://'));
      final bool hasWaze = await canLaunchUrl(Uri.parse('waze://'));
      final bool hasAppleMaps = true; // Apple Maps is always present on iOS

      final List<MapAppOption> availableApps = [];

      if (hasAppleMaps) {
        availableApps.add(MapAppOption(
          name: 'خرائط آبل (Apple Maps)',
          description: 'التطبيق الرسمي المدمج من آبل',
          icon: Icons.explore_rounded,
          iconColor: Colors.blue.shade600,
          url: Uri.parse('http://maps.apple.com/?daddr=$latitude,$longitude&dirflg=d'),
        ));
      }

      if (hasGoogleMaps) {
        availableApps.add(MapAppOption(
          name: 'خرائط جوجل (Google Maps)',
          description: 'الملاحة الدقيقة مع حالة المرور المباشرة',
          icon: Icons.map_rounded,
          iconColor: Colors.green.shade600,
          url: Uri.parse('comgooglemaps://?daddr=$latitude,$longitude&directionsmode=driving'),
        ));
      }

      if (hasWaze) {
        availableApps.add(MapAppOption(
          name: 'تطبيق وايز (Waze)',
          description: 'تنبيهات الطرق وحالة المرور والسرعة',
          icon: Icons.directions_car_rounded,
          iconColor: Colors.teal.shade600,
          url: Uri.parse('waze://?ll=$latitude,$longitude&navigate=yes'),
        ));
      }

      if (availableApps.isEmpty) {
        // Fallback to web maps
        final Uri fallbackUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude');
        await _launch(fallbackUrl);
      } else if (availableApps.length == 1) {
        // Only one is available, launch it directly
        await _launch(availableApps.first.url);
      } else {
        // Show selection sheet
        if (context.mounted) {
          await _showMapSelectionSheet(context, availableApps);
        }
      }
    } else {
      // Android / Generic
      final bool hasWaze = await canLaunchUrl(Uri.parse('waze://'));
      final List<MapAppOption> availableApps = [];

      availableApps.add(MapAppOption(
        name: 'خرائط جوجل (Google Maps)',
        description: 'خرائط جوجل الرسمية للملاحة',
        icon: Icons.map_rounded,
        iconColor: Colors.green.shade600,
        url: Uri.parse('google.navigation:q=$latitude,$longitude'),
      ));

      if (hasWaze) {
        availableApps.add(MapAppOption(
          name: 'تطبيق وايز (Waze)',
          description: 'تنبيهات الطرق وحالة المرور والسرعة',
          icon: Icons.directions_car_rounded,
          iconColor: Colors.teal.shade600,
          url: Uri.parse('waze://?ll=$latitude,$longitude&navigate=yes'),
        ));
      }

      if (availableApps.length == 1) {
        // Just launch Google Maps directly
        await _launch(availableApps.first.url);
      } else {
        if (context.mounted) {
          await _showMapSelectionSheet(context, availableApps);
        }
      }
    }
  }

  static Future<void> _launch(Uri url) async {
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[ExternalNavigationService] Error launching map URL: $e');
    }
  }

  static Future<void> _showMapSelectionSheet(BuildContext context, List<MapAppOption> apps) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'اختر تطبيق الخرائط للملاحة',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ...apps.map((app) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _launch(app.url);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: app.iconColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(app.icon, color: app.iconColor, size: 22),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    app.name,
                                    style: GoogleFonts.cairo(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    app.description,
                                    style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MapAppOption {
  final String name;
  final String description;
  final IconData icon;
  final Color iconColor;
  final Uri url;

  MapAppOption({
    required this.name,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.url,
  });
}

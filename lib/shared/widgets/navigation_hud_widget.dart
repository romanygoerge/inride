import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/controllers/navigation_controller.dart';
import '../../core/services/trip_navigation_manager.dart';
import '../../core/DI/injection_container.dart' show sl;
import '../../core/utils/map_coordinates_helper.dart';
import 'package:latlong2/latlong.dart' show LatLng;

/// Professional navigation HUD overlay widget displayed during active navigation.
/// Mirrors the experience of Uber/inDrive with large maneuver arrows,
/// clear Arabic instructions, and real-time trip metrics.
class NavigationHudWidget extends StatelessWidget {
  const NavigationHudWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final navCtrl = sl<NavigationController>();
    final navManager = sl<TripNavigationManager>();

    if (!navManager.isNavigating || navCtrl.activeRoute == null) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status bar for special states (rerouting, GPS lost, offline)
        _buildStatusBar(navCtrl),

        // Main maneuver instruction card
        _buildManeuverCard(navCtrl),

        const SizedBox(height: 6),

        // Info strip: street name, ETA, distance
        _buildInfoStrip(navCtrl),
      ],
    );
  }

  /// Top status bar for error/rerouting states (yellow, red, or gray)
  Widget _buildStatusBar(NavigationController navCtrl) {
    if (navCtrl.status == NavigationStatus.active || navCtrl.status == NavigationStatus.idle) {
      return const SizedBox.shrink();
    }

    Color bgColor;
    IconData icon;
    String text;

    switch (navCtrl.status) {
      case NavigationStatus.rerouting:
        bgColor = AppColors.warning;
        icon = Icons.refresh;
        text = 'جاري إعادة حساب المسار...';
        break;
      case NavigationStatus.gpsLost:
        bgColor = AppColors.error;
        icon = Icons.gps_off;
        text = 'تم فقدان إشارة GPS';
        break;
      case NavigationStatus.offline:
        bgColor = const Color(0xFF78909C);
        icon = Icons.cloud_off;
        text = navCtrl.errorMessage.isNotEmpty ? navCtrl.errorMessage : 'لا يوجد اتصال بالإنترنت';
        break;
      case NavigationStatus.error:
        bgColor = AppColors.error;
        icon = Icons.error_outline;
        text = navCtrl.errorMessage.isNotEmpty ? navCtrl.errorMessage : 'حدث خطأ';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          navCtrl.status == NavigationStatus.rerouting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Main large maneuver instruction card (gradient blue background)
  Widget _buildManeuverCard(NavigationController navCtrl) {
    final hasStatusBar = navCtrl.status != NavigationStatus.active && navCtrl.status != NavigationStatus.idle;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: hasStatusBar
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        child: Row(
          children: [
            // Large maneuver icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(40, 40),
                  painter: ManeuverIconPainter(
                    type: navCtrl.maneuverType,
                    modifier: navCtrl.maneuverModifier,
                    exitNumber: navCtrl.exitNumber,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Instructions text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Distance to next maneuver
                  Text(
                    'بعد ${navCtrl.formattedDistanceToTurn}',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Main instruction
                  Text(
                    _getShortInstruction(navCtrl),
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Next street name (if available)
                  if (navCtrl.nextStreetName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'نحو: ${navCtrl.nextStreetName}',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Control buttons column
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mute/Unmute button
                _buildControlButton(
                  icon: navCtrl.isVoiceMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  onTap: () => navCtrl.toggleVoiceMute(),
                ),
                const SizedBox(height: 6),
                // Recenter button (only if auto-follow is off)
                if (!navCtrl.isAutoFollow)
                  _buildControlButton(
                    icon: Icons.gps_fixed_rounded,
                    onTap: () {
                      final deviceLoc = MapCoordinatesHelper.deviceLocation;
                      final snapped = navCtrl.snappedLocation ??
                          (deviceLoc != null
                              ? LatLng(deviceLoc.latitude, deviceLoc.longitude)
                              : const LatLng(30.0130, 31.2080));
                      sl<TripNavigationManager>().cameraController?.recenter(snapped, 0.0);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Small pill button for HUD controls
  Widget _buildControlButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 20),
      ),
    );
  }

  /// Info strip showing current street, ETA, remaining distance
  Widget _buildInfoStrip(NavigationController navCtrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Current street name
          Expanded(
            flex: 3,
            child: Row(
              children: [
                const Icon(Icons.map_rounded, color: AppColors.mediumBlue, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    navCtrl.currentStreetName.isNotEmpty
                        ? navCtrl.currentStreetName
                        : 'طريق غير مسمى',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Vertical divider
          Container(
            height: 24,
            width: 1,
            color: AppColors.border,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),

          // ETA
          _buildInfoItem(
            icon: Icons.access_time_rounded,
            value: navCtrl.formattedETA,
            color: AppColors.mediumBlue,
          ),

          Container(
            height: 24,
            width: 1,
            color: AppColors.border,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),

          // Remaining distance
          _buildInfoItem(
            icon: Icons.straighten_rounded,
            value: navCtrl.formattedRemainingDistance,
            color: AppColors.darkBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({required IconData icon, required String value, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Returns a concise direction-only instruction for the HUD (without distance prefix).
  String _getShortInstruction(NavigationController navCtrl) {
    final type = navCtrl.maneuverType;
    final modifier = navCtrl.maneuverModifier;

    switch (type) {
      case 'depart':
        return 'ابدأ التحرك';
      case 'arrive':
        if (modifier == 'left') return 'وجهتك على اليسار';
        if (modifier == 'right') return 'وجهتك على اليمين';
        return 'وصلت إلى وجهتك';
      case 'turn':
        return _getShortDirection(modifier);
      case 'new name':
      case 'continue':
        return 'استمر للأمام';
      case 'roundabout':
      case 'rotary':
        final exit = navCtrl.exitNumber;
        if (exit != null) {
          return 'ادخل الدوار - المخرج ${_translateExitNumber(exit)}';
        }
        return 'ادخل الدوار';
      case 'merge':
        return 'اندمج في الطريق';
      case 'fork':
        return _getShortDirection(modifier);
      case 'end of road':
        return _getShortDirection(modifier);
      default:
        return _getShortDirection(modifier);
    }
  }

  String _getShortDirection(String modifier) {
    switch (modifier) {
      case 'left': return 'انعطف يساراً';
      case 'right': return 'انعطف يميناً';
      case 'slight left': return 'انحرف قليلاً لليسار';
      case 'slight right': return 'انحرف قليلاً لليمين';
      case 'sharp left': return 'انعطف بحدة لليسار';
      case 'sharp right': return 'انعطف بحدة لليمين';
      case 'uturn': return 'قم بالدوران';
      case 'straight': return 'استمر مباشرة';
      default: return 'استمر للأمام';
    }
  }

  String _translateExitNumber(int n) {
    switch (n) {
      case 1: return 'الأول';
      case 2: return 'الثاني';
      case 3: return 'الثالث';
      case 4: return 'الرابع';
      case 5: return 'الخامس';
      default: return 'رقم $n';
    }
  }
}


// ─────────────────────────────────────────────────────────────────────
// Custom Painter: Professional navigation maneuver icons
// ─────────────────────────────────────────────────────────────────────

class ManeuverIconPainter extends CustomPainter {
  final String type;
  final String modifier;
  final int? exitNumber;

  ManeuverIconPainter({
    required this.type,
    required this.modifier,
    this.exitNumber,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;

    switch (type) {
      case 'depart':
        _drawDepartIcon(canvas, size, paint, fillPaint, cx, cy);
        break;
      case 'arrive':
        _drawArriveIcon(canvas, size, paint, fillPaint, cx, cy);
        break;
      case 'roundabout':
      case 'rotary':
        _drawRoundaboutIcon(canvas, size, paint, fillPaint, cx, cy);
        break;
      default:
        _drawDirectionArrow(canvas, size, paint, fillPaint, cx, cy);
        break;
    }
  }

  void _drawDepartIcon(Canvas canvas, Size size, Paint paint, Paint fillPaint, double cx, double cy) {
    // Circle with dot (starting point)
    canvas.drawCircle(Offset(cx, cy), size.width * 0.3, paint);
    canvas.drawCircle(Offset(cx, cy), size.width * 0.1, fillPaint);
  }

  void _drawArriveIcon(Canvas canvas, Size size, Paint paint, Paint fillPaint, double cx, double cy) {
    // Flag icon
    final flagPole = Path()
      ..moveTo(cx - size.width * 0.15, cy + size.height * 0.35)
      ..lineTo(cx - size.width * 0.15, cy - size.height * 0.35);
    canvas.drawPath(flagPole, paint);

    // Flag body
    final flag = Path()
      ..moveTo(cx - size.width * 0.15, cy - size.height * 0.35)
      ..lineTo(cx + size.width * 0.25, cy - size.height * 0.2)
      ..lineTo(cx - size.width * 0.15, cy - size.height * 0.05)
      ..close();
    canvas.drawPath(flag, fillPaint);

    // Base
    canvas.drawCircle(Offset(cx - size.width * 0.15, cy + size.height * 0.35), 3, fillPaint);
  }

  void _drawRoundaboutIcon(Canvas canvas, Size size, Paint paint, Paint fillPaint, double cx, double cy) {
    // Draw circle for roundabout
    final radius = size.width * 0.22;
    canvas.drawCircle(Offset(cx, cy - size.height * 0.05), radius, paint);

    // Draw entry arrow from bottom
    final entryPath = Path()
      ..moveTo(cx, cy + size.height * 0.4)
      ..lineTo(cx, cy + radius - size.height * 0.05);
    canvas.drawPath(entryPath, paint);

    // Draw exit number if available
    if (exitNumber != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$exitNumber',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(cx - textPainter.width / 2, cy - size.height * 0.05 - textPainter.height / 2),
      );
    }

    // Draw circular arrow indicator on top of the circle
    final arrowTip = Offset(cx + radius * 0.7, cy - size.height * 0.05 - radius * 0.7);
    final arrowPath = Path()
      ..moveTo(arrowTip.dx - 4, arrowTip.dy - 5)
      ..lineTo(arrowTip.dx, arrowTip.dy)
      ..lineTo(arrowTip.dx + 5, arrowTip.dy - 4);
    canvas.drawPath(arrowPath, paint);
  }

  void _drawDirectionArrow(Canvas canvas, Size size, Paint paint, Paint fillPaint, double cx, double cy) {
    // Determine rotation angle based on modifier
    double angle = 0.0; // default: straight
    switch (modifier) {
      case 'left': angle = -math.pi / 2; break;
      case 'right': angle = math.pi / 2; break;
      case 'slight left': angle = -math.pi / 5; break;
      case 'slight right': angle = math.pi / 5; break;
      case 'sharp left': angle = -math.pi * 0.7; break;
      case 'sharp right': angle = math.pi * 0.7; break;
      case 'uturn': angle = math.pi; break;
      case 'straight': angle = 0.0; break;
      default: angle = 0.0; break;
    }

    canvas.save();
    canvas.translate(cx, cy);

    if (modifier == 'uturn') {
      // U-turn icon: curved arrow going down then back up
      _drawUturnArrow(canvas, size, paint, fillPaint);
    } else if (modifier == 'straight' || modifier.isEmpty) {
      // Straight arrow pointing up
      _drawStraightArrow(canvas, size, paint, fillPaint);
    } else {
      // Turn arrow: vertical stem + angled arrow
      _drawTurnArrow(canvas, size, paint, fillPaint, angle);
    }

    canvas.restore();
  }

  void _drawStraightArrow(Canvas canvas, Size size, Paint paint, Paint fillPaint) {
    final h = size.height;
    // Vertical line
    final stem = Path()
      ..moveTo(0, h * 0.35)
      ..lineTo(0, -h * 0.2);
    canvas.drawPath(stem, paint);

    // Arrow head
    final arrowHead = Path()
      ..moveTo(-h * 0.15, -h * 0.1)
      ..lineTo(0, -h * 0.35)
      ..lineTo(h * 0.15, -h * 0.1)
      ..close();
    canvas.drawPath(arrowHead, fillPaint);
  }

  void _drawTurnArrow(Canvas canvas, Size size, Paint paint, Paint fillPaint, double angle) {
    final h = size.height;
    final w = size.width;

    // Determine if turning left or right
    final isLeft = angle < 0;
    final absAngle = angle.abs();

    // Vertical stem from bottom
    final stemTop = -h * 0.05;
    final stem = Path()
      ..moveTo(0, h * 0.35)
      ..lineTo(0, stemTop);
    canvas.drawPath(stem, paint);

    // Curved turn section
    final turnLength = w * 0.25 + (absAngle / math.pi) * w * 0.1;
    final endX = isLeft ? -turnLength : turnLength;
    final endY = stemTop - h * 0.15;

    // Draw curved path for the turn
    final turnPath = Path()
      ..moveTo(0, stemTop)
      ..quadraticBezierTo(0, endY, endX, endY);
    canvas.drawPath(turnPath, paint);

    // Arrow head at the end of the turn
    final arrowSize = h * 0.12;
    canvas.save();
    canvas.translate(endX, endY);

    if (isLeft) {
      // Arrow pointing left
      final arrowHead = Path()
        ..moveTo(arrowSize * 0.5, -arrowSize)
        ..lineTo(-arrowSize * 0.5, 0)
        ..lineTo(arrowSize * 0.5, arrowSize)
        ..close();
      canvas.drawPath(arrowHead, fillPaint);
    } else {
      // Arrow pointing right
      final arrowHead = Path()
        ..moveTo(-arrowSize * 0.5, -arrowSize)
        ..lineTo(arrowSize * 0.5, 0)
        ..lineTo(-arrowSize * 0.5, arrowSize)
        ..close();
      canvas.drawPath(arrowHead, fillPaint);
    }
    canvas.restore();
  }

  void _drawUturnArrow(Canvas canvas, Size size, Paint paint, Paint fillPaint) {
    final h = size.height;
    final w = size.width;

    // Draw U shape: up, curve, down
    final path = Path()
      ..moveTo(w * 0.15, h * 0.35) // start bottom right
      ..lineTo(w * 0.15, -h * 0.15) // go up
      ..arcToPoint(
        Offset(-w * 0.15, -h * 0.15),
        radius: Radius.circular(w * 0.15),
        clockwise: true,
      )
      ..lineTo(-w * 0.15, h * 0.1); // go down
    canvas.drawPath(path, paint);

    // Arrow head at bottom left pointing down
    final arrowHead = Path()
      ..moveTo(-w * 0.15 - h * 0.1, h * 0.0)
      ..lineTo(-w * 0.15, h * 0.2)
      ..lineTo(-w * 0.15 + h * 0.1, h * 0.0)
      ..close();
    canvas.drawPath(arrowHead, fillPaint);
  }

  @override
  bool shouldRepaint(covariant ManeuverIconPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.modifier != modifier || oldDelegate.exitNumber != exitNumber;
  }
}

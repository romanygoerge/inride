import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

/// Professional push notification banner that mimics native OS notification style.
/// Shows as an overlay from the top with swipe-to-dismiss, type-based icons,
/// and a polished glassmorphism design.
class InAppNotificationWidget extends StatefulWidget {
  final String title;
  final String body;
  final String type;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const InAppNotificationWidget({
    super.key,
    required this.title,
    required this.body,
    this.type = 'info',
    required this.onTap,
    required this.onClose,
  });

  /// Show the notification banner as an overlay
  static void show(
    BuildContext context, {
    required String title,
    required String body,
    String type = 'info',
    required VoidCallback onTap,
  }) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return InAppNotificationWidget(
          title: title,
          body: body,
          type: type,
          onTap: () {
            if (overlayEntry.mounted) {
              overlayEntry.remove();
            }
            onTap();
          },
          onClose: () {
            if (overlayEntry.mounted) {
              overlayEntry.remove();
            }
          },
        );
      },
    );

    overlayState.insert(overlayEntry);
  }

  @override
  State<InAppNotificationWidget> createState() => _InAppNotificationWidgetState();
}

class _InAppNotificationWidgetState extends State<InAppNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _dismissed = false;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _controller.forward();

    // Haptic feedback on appear
    HapticFeedback.lightImpact();

    // Auto dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_dismissed) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    if (_dismissed) return;
    _dismissed = true;
    if (mounted) {
      await _controller.reverse();
    }
    widget.onClose();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Get icon and color based on notification type
  _NotificationStyle _getStyle() {
    final t = widget.type.trim().toLowerCase();

    // Trip / ride related
    if (t.contains('trip') || t.contains('ride') || t.contains('delivery') || t.contains('arrived')) {
      return _NotificationStyle(
        icon: Icons.directions_car_rounded,
        color: const Color(0xFF1E88E5),
        gradient: const [Color(0xFF1976D2), Color(0xFF42A5F5)],
      );
    }

    // Offer / bidding related
    if (t.contains('offer') || t.contains('bid') || t.contains('counter')) {
      return _NotificationStyle(
        icon: Icons.local_offer_rounded,
        color: const Color(0xFF7C4DFF),
        gradient: const [Color(0xFF651FFF), Color(0xFFB388FF)],
      );
    }

    // Chat / message related
    if (t.contains('message') || t.contains('chat')) {
      return _NotificationStyle(
        icon: Icons.chat_bubble_rounded,
        color: const Color(0xFF00BFA5),
        gradient: const [Color(0xFF00897B), Color(0xFF4DB6AC)],
      );
    }

    // Wallet / payment related
    if (t.contains('wallet') || t.contains('charge') || t.contains('payment') ||
        t.contains('payout') || t.contains('deposit')) {
      return _NotificationStyle(
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFFFF6D00),
        gradient: const [Color(0xFFE65100), Color(0xFFFFAB40)],
      );
    }

    // Support related
    if (t.contains('support')) {
      return _NotificationStyle(
        icon: Icons.headset_mic_rounded,
        color: const Color(0xFF43A047),
        gradient: const [Color(0xFF2E7D32), Color(0xFF66BB6A)],
      );
    }

    // Admin / general
    return _NotificationStyle(
      icon: Icons.notifications_rounded,
      color: AppColors.mediumBlue,
      gradient: const [Color(0xFF1565C0), Color(0xFF42A5F5)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = _getStyle();
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              setState(() {
                _dragOffset += details.delta.dy;
                if (_dragOffset > 0) _dragOffset = 0; // Prevent dragging down
              });
            },
            onVerticalDragEnd: (details) {
              if (_dragOffset < -40) {
                _dismiss();
              } else {
                setState(() => _dragOffset = 0);
              }
            },
            onTap: () {
              HapticFeedback.selectionClick();
              _dismissed = true;
              widget.onTap();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              transform: Matrix4.translationValues(0, _dragOffset, 0),
              child: Material(
                color: Colors.transparent,
                elevation: 0,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: style.color.withValues(alpha: 0.15),
                        blurRadius: 24,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Gradient accent strip at top
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: style.gradient,
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // App header row (like native notification)
                            Row(
                              children: [
                                // App icon
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: AppColors.blueGradient,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'iR',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'inRide',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textLight,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '•',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.textLight.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'الآن',
                                  style: GoogleFonts.cairo(
                                    fontSize: 10,
                                    color: AppColors.textLight,
                                  ),
                                ),
                                const Spacer(),
                                // Close button
                                GestureDetector(
                                  onTap: _dismiss,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 12,
                                      color: AppColors.textLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Main content row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Type icon with gradient background
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        style.color.withValues(alpha: 0.15),
                                        style.color.withValues(alpha: 0.05),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      style.icon,
                                      color: style.color,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Text content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.title,
                                        style: GoogleFonts.cairo(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                          color: AppColors.textPrimary,
                                          height: 1.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        widget.body,
                                        style: GoogleFonts.cairo(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          height: 1.3,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Bottom swipe hint
                      Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationStyle {
  final IconData icon;
  final Color color;
  final List<Color> gradient;

  _NotificationStyle({
    required this.icon,
    required this.color,
    required this.gradient,
  });
}

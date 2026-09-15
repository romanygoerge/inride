import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/state/global_state.dart';
import '../../core/localization/locale_controller.dart';

/// A semi-transparent animated banner shown at the top of the active ride
/// screen when the device is offline. It does NOT block interaction – the
/// user can still see the ride UI underneath and tap on controls.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = LocaleController.instance.isArabic;
    final isReconnecting = GlobalState.instance.isReconnecting;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) => Opacity(
        opacity: _pulseAnimation.value,
        child: child,
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          bottom: 10,
          left: 16,
          right: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isReconnecting
                ? [Colors.orange.shade700, Colors.orange.shade600]
                : [Colors.red.shade700, Colors.red.shade600],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (isReconnecting)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isReconnecting
                        ? (isArabic ? 'جاري إعادة الاتصال...' : 'Reconnecting...')
                        : (isArabic ? 'لا يوجد اتصال بالإنترنت' : 'No internet connection'),
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    isReconnecting
                        ? (isArabic
                            ? 'سيتم استعادة البيانات تلقائياً'
                            : 'Data will be restored automatically')
                        : (isArabic
                            ? 'الرحلة مستمرة - سيتم مزامنة البيانات عند العودة'
                            : 'Trip continues – data syncs when back online'),
                    style: GoogleFonts.cairo(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

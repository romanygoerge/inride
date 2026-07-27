import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class InAppNotificationWidget extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const InAppNotificationWidget({
    super.key,
    required this.title,
    required this.body,
    required this.onTap,
    required this.onClose,
  });

  static void show(
    BuildContext context, {
    required String title,
    required String body,
    required VoidCallback onTap,
  }) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return InAppNotificationWidget(
          title: title,
          body: body,
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

class _InAppNotificationWidgetState extends State<InAppNotificationWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();

    // Auto dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
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

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              _dismissed = true;
              widget.onTap();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Row(
                children: [
                  // Message icon bubble
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.mediumBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      color: AppColors.mediumBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  
                  // Text Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.body,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // Close Icon Button
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: AppColors.textLight),
                    onPressed: _dismiss,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

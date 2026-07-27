import 'package:flutter/material.dart';

class ScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDownTo;
  final Duration duration;

  const ScaleButton({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDownTo = 0.95,
    this.duration = const Duration(milliseconds: 120),
  });

  @override
  State<ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<ScaleButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;

    return GestureDetector(
      onTapDown: (_) {
        if (mounted) {
          setState(() {
            _scale = widget.scaleDownTo;
          });
        }
      },
      onTapUp: (_) {
        if (mounted) {
          setState(() {
            _scale = 1.0;
          });
        }
      },
      onTapCancel: () {
        if (mounted) {
          setState(() {
            _scale = 1.0;
          });
        }
      },
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

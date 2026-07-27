import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool isTransparent;
  final bool isCircle;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  const AppLogo({
    super.key,
    this.size = 100,
    this.isTransparent = false,
    this.isCircle = false,
    this.color,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final double borderRadius = size * 0.24;
    
    final Widget logoImage = Image.asset(
      'assets/images/logo.png',
      fit: BoxFit.contain,
      color: color,
    );

    if (isTransparent) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: logoImage),
      );
    }

    return Container(
      width: size,
      height: size,
      padding: padding ?? EdgeInsets.all(size * 0.16),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: size * 0.12,
            offset: Offset(0, size * 0.04),
          ),
        ],
      ),
      child: Center(
        child: logoImage,
      ),
    );
  }
}


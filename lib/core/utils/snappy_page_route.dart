import 'package:flutter/material.dart';

class SnappyPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SnappyPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 240),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation.drive(
                CurveTween(curve: Curves.easeOutCubic),
              ),
              child: SlideTransition(
                position: animation.drive(
                  Tween<Offset>(
                    begin: const Offset(0.06, 0.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutCubic)),
                ),
                child: child,
              ),
            );
          },
        );
}

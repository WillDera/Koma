import 'package:flutter/material.dart';

import '../theme/tokens/app_motion.dart';

/// AnymeX-inspired horizontal slide with parallax on the outgoing page.
/// Curves/durations follow [AppMotion] (MIT-adapted from anymex page_transition).
class SmoothSlideTransition extends PageTransitionsBuilder {
  const SmoothSlideTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: AppMotion.decelerate,
      reverseCurve: AppMotion.accelerate,
    );

    final curvedSecondary = CurvedAnimation(
      parent: secondaryAnimation,
      curve: AppMotion.standard,
      reverseCurve: AppMotion.accelerate,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(curvedAnimation),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.3, 0.0),
        ).animate(curvedSecondary),
        child: child,
      ),
    );
  }
}

/// Scale + fade entrance with a gentle shrink/fade on the page beneath.
class ScaleFadeTransition extends PageTransitionsBuilder {
  const ScaleFadeTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const curve = AppMotion.decelerate;

    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: curve),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: curve),
        ),
        child: FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.8).animate(
            CurvedAnimation(parent: secondaryAnimation, curve: curve),
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.05).animate(
              CurvedAnimation(parent: secondaryAnimation, curve: curve),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Convenience builder for imperative [PageRouteBuilder] pushes (settings, etc.).
Widget scaleFadePageTransition({
  required Animation<double> animation,
  required Widget child,
}) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: AppMotion.decelerate,
    reverseCurve: AppMotion.accelerate,
  );
  return FadeTransition(
    opacity: curved,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
      child: child,
    ),
  );
}

/// Horizontal slide for You / Settings destinations and imperative pushes.
///
/// Enters from the right; outgoing page shifts slightly left (parallax).
Widget smoothSlidePageTransition({
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required Widget child,
}) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: AppMotion.decelerate,
    reverseCurve: AppMotion.accelerate,
  );
  final secondary = CurvedAnimation(
    parent: secondaryAnimation,
    curve: AppMotion.standard,
    reverseCurve: AppMotion.accelerate,
  );
  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(curved),
    child: SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.3, 0.0),
      ).animate(secondary),
      child: child,
    ),
  );
}

/// Scale-fade [PageRouteBuilder] for imperative pushes (migrate, settings, etc.).
Route<T> scaleFadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: AppMotion.page,
    reverseTransitionDuration: AppMotion.base,
    pageBuilder: (_, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        scaleFadePageTransition(animation: animation, child: child),
  );
}

/// Fast horizontal slide [PageRouteBuilder] (You hub, snippets, etc.).
Route<T> smoothSlideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: AppMotion.base,
    reverseTransitionDuration: AppMotion.fast,
    pageBuilder: (_, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        smoothSlidePageTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        ),
  );
}

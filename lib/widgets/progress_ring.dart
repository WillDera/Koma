import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';

/// A circular progress indicator (0..1) used on book covers and stats.
/// Uses the latest Material 3 circular indicator (theme `year2023: false`).
class ProgressRing extends StatelessWidget {
  final double progress; // 0..1
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final Widget? child;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 40,
    this.strokeWidth = 2.5,
    this.color,
    this.trackColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = color ?? c.accent;
    final bg = trackColor ?? c.border;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: AppMotion.slow,
        curve: AppMotion.standard,
        builder: (context, value, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: strokeWidth,
                  color: fg,
                  backgroundColor: bg,
                ),
              ),
              ?child,
            ],
          );
        },
      ),
    );
  }
}

/// A thin linear progress bar with rounded caps (Material 3 LinearProgressIndicator).
class ThinProgressBar extends StatelessWidget {
  final double progress;
  final double height;
  final Color? color;
  final Color? trackColor;

  const ThinProgressBar({
    super.key,
    required this.progress,
    this.height = 3,
    this.color,
    this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          minHeight: height,
          color: color ?? c.accent,
          backgroundColor: trackColor ?? c.border,
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/reader/text_progress_pill_prefs.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';

/// Thin edge progress pill for ebook / novel readers.
///
/// Tracks [progress] continuously (even while faded). Call [onUserActivity]
/// from scroll/page handlers so the pill fades in and auto-hides after 3s.
class ReadingProgressPillOverlay extends StatefulWidget {
  const ReadingProgressPillOverlay({
    super.key,
    required this.progress,
    required this.enabled,
    required this.placement,
    required this.activityTick,
  });

  /// 0 = start / first line in view; 1 = end / last line in view.
  final double progress;
  final bool enabled;
  final TextProgressPillPlacement placement;

  /// Bump this (e.g. increment an int) whenever the user scrolls or turns a page.
  final int activityTick;

  @override
  State<ReadingProgressPillOverlay> createState() =>
      _ReadingProgressPillOverlayState();
}

class _ReadingProgressPillOverlayState
    extends State<ReadingProgressPillOverlay> {
  static const _hideAfter = Duration(seconds: 3);
  static const _fadeDuration = AppMotion.base;

  bool _visible = false;
  Timer? _hideTimer;

  @override
  void didUpdateWidget(covariant ReadingProgressPillOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _hideTimer?.cancel();
      if (_visible) setState(() => _visible = false);
      return;
    }
    final justEnabled = !oldWidget.enabled && widget.enabled;
    final placementChanged = oldWidget.placement != widget.placement;
    final activity = widget.activityTick != oldWidget.activityTick;
    // Pulse on scroll/page activity, and when the user turns the pill on or
    // changes placement (settings feedback — otherwise opacity stays 0).
    if (justEnabled || placementChanged || activity) {
      _pulseVisible();
    }
  }

  void _pulseVisible() {
    _hideTimer?.cancel();
    if (!_visible) {
      setState(() => _visible = true);
    }
    _hideTimer = Timer(_hideAfter, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    final c = context.colors;
    final padding = MediaQuery.paddingOf(context);
    final progress = widget.progress.clamp(0.0, 1.0);
    const thickness = 5.0;
    const length = 80.0;
    const edgeInset = 10.0;

    late final Alignment alignment;
    late final EdgeInsets margin;
    late final Size size;
    late final Axis axis;

    switch (widget.placement) {
      case TextProgressPillPlacement.left:
        alignment = Alignment.centerLeft;
        margin = EdgeInsets.only(left: math.max(padding.left, edgeInset));
        size = const Size(thickness, length);
        axis = Axis.vertical;
      case TextProgressPillPlacement.right:
        alignment = Alignment.centerRight;
        margin = EdgeInsets.only(right: math.max(padding.right, edgeInset));
        size = const Size(thickness, length);
        axis = Axis.vertical;
      case TextProgressPillPlacement.bottom:
        alignment = Alignment.bottomCenter;
        margin = EdgeInsets.only(
          bottom: math.max(padding.bottom, edgeInset) + 4,
        );
        size = const Size(length, thickness);
        axis = Axis.horizontal;
    }

    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: margin,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: _fadeDuration,
            curve: Curves.easeOutCubic,
            child: _ProgressPillPaint(
              progress: progress,
              axis: axis,
              size: size,
              fill: c.accent,
              track: c.accent.withValues(alpha: 0.28),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressPillPaint extends StatelessWidget {
  const _ProgressPillPaint({
    required this.progress,
    required this.axis,
    required this.size,
    required this.fill,
    required this.track,
  });

  final double progress;
  final Axis axis;
  final Size size;
  final Color fill;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: progress, end: progress),
        duration: Duration.zero,
        builder: (context, _, _) {
          return CustomPaint(
            painter: _PillPainter(
              progress: progress,
              axis: axis,
              fill: fill,
              track: track,
            ),
          );
        },
      ),
    );
  }
}

class _PillPainter extends CustomPainter {
  _PillPainter({
    required this.progress,
    required this.axis,
    required this.fill,
    required this.track,
  });

  final double progress;
  final Axis axis;
  final Color fill;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(math.min(size.width, size.height));
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, radius);
    canvas.drawRRect(rrect, Paint()..color = track);

    if (progress <= 0) return;

    late final Rect fillRect;
    if (axis == Axis.horizontal) {
      // Left → right
      fillRect = Rect.fromLTWH(0, 0, size.width * progress, size.height);
    } else {
      // Bottom → top
      final h = size.height * progress;
      fillRect = Rect.fromLTWH(0, size.height - h, size.width, h);
    }
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(fillRect, Paint()..color = fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PillPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.fill != fill ||
        oldDelegate.track != track ||
        oldDelegate.axis != axis;
  }
}

/// Scroll progress 0–1 from [ScrollMetrics]. Empty when at start; full at end.
double readingProgressFromScroll(ScrollMetrics metrics) {
  final max = metrics.maxScrollExtent;
  if (max <= 0) return 1.0;
  return (metrics.pixels / max).clamp(0.0, 1.0);
}

/// Page progress 0–1. [pageIndex] is 0-based; [pageCount] must be > 0.
double readingProgressFromPage(int pageIndex, int pageCount) {
  if (pageCount <= 1) return 1.0;
  return (pageIndex / (pageCount - 1)).clamp(0.0, 1.0);
}

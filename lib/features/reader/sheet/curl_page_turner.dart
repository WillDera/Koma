import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../theme/tokens/app_motion.dart';

/// Single-page curl — one full-screen sheet that peels to the next/previous.
///
/// Unlike an open-book spread widget (spine down the middle), this follows
/// the finger in both directions and never draws a binding bar over the text.
class CurlPageTurner extends StatefulWidget {
  const CurlPageTurner({
    super.key,
    required this.pageCount,
    required this.pageIndex,
    required this.pageSize,
    required this.pageBuilder,
    required this.captureKey,
    required this.sheetColor,
    this.onPageChanged,
    this.onChapterEdge,
  });

  final int pageCount;
  final int pageIndex;
  final Size pageSize;
  final Widget Function(BuildContext context, int pageIndex) pageBuilder;
  final Object captureKey;
  final Color sheetColor;
  final ValueChanged<int>? onPageChanged;

  /// Fired when a committed swipe would leave the chapter.
  final void Function({required bool forward})? onChapterEdge;

  @override
  State<CurlPageTurner> createState() => _CurlPageTurnerState();
}

class _CurlPageTurnerState extends State<CurlPageTurner>
    with SingleTickerProviderStateMixin {
  static const _slop = 18.0;
  static const _commit = 0.28;
  static const _fling = 700.0;

  late int _index;
  double _t = 0;
  int _dir = 0; // 1 = forward (RTL), -1 = backward (LTR)
  Offset? _down;
  Duration? _downAt;
  bool _dragging = false;
  int _settleGen = 0;
  late final AnimationController _settle;
  Animation<double>? _settleAnim;

  @override
  void initState() {
    super.initState();
    _index = widget.pageIndex.clamp(0, math.max(0, widget.pageCount - 1));
    _settle = AnimationController(vsync: this, duration: AppMotion.pageTurn)
      ..addListener(_onSettleTick);
  }

  @override
  void didUpdateWidget(covariant CurlPageTurner old) {
    super.didUpdateWidget(old);
    if (old.captureKey != widget.captureKey) {
      _index = widget.pageIndex.clamp(0, math.max(0, widget.pageCount - 1));
      _t = 0;
      _dir = 0;
      _settle.stop();
    } else if (widget.pageIndex != _index) {
      _index = widget.pageIndex.clamp(0, math.max(0, widget.pageCount - 1));
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _onSettleTick() {
    final anim = _settleAnim;
    if (anim == null || !mounted) return;
    setState(() => _t = anim.value);
  }

  void _pointerDown(PointerDownEvent e) {
    _settleGen++;
    if (_settle.isAnimating) _settle.stop();
    _down = e.localPosition;
    _downAt = e.timeStamp;
    _dragging = false;
  }

  void _pointerMove(PointerMoveEvent e) {
    final start = _down;
    if (start == null) return;
    final dx = e.localPosition.dx - start.dx;
    final dy = e.localPosition.dy - start.dy;
    if (!_dragging) {
      if (dx.abs() < _slop || dx.abs() < dy.abs()) return;
      _dragging = true;
      _dir = dx < 0 ? 1 : -1;
    }
    final w = widget.pageSize.width.clamp(1.0, 8000.0);
    final raw = _dir > 0 ? -dx / w : dx / w;
    setState(() => _t = raw.clamp(0.0, 1.0));
  }

  void _pointerUp(PointerUpEvent e) {
    final start = _down;
    final startedAt = _downAt;
    _down = null;
    _downAt = null;
    if (!_dragging || _dir == 0 || start == null || startedAt == null) {
      _dragging = false;
      return;
    }
    _dragging = false;
    final dx = e.localPosition.dx - start.dx;
    final dtMs = math.max(1, (e.timeStamp - startedAt).inMilliseconds);
    final vx = dx / dtMs * 1000;
    final fling = _dir > 0 ? -vx : vx;
    final commit = _t >= _commit || fling > _fling;
    unawaited(_animateTo(commit ? 1 : 0, commit: commit));
  }

  void _pointerCancel(PointerCancelEvent e) {
    _down = null;
    _downAt = null;
    if (!_dragging) return;
    _dragging = false;
    unawaited(_animateTo(0, commit: false));
  }

  Future<void> _animateTo(double target, {required bool commit}) async {
    final gen = ++_settleGen;
    final tween = Tween<double>(begin: _t, end: target);
    _settleAnim = tween.animate(
      CurvedAnimation(parent: _settle, curve: AppMotion.decelerate),
    );
    try {
      await _settle.forward(from: 0);
    } catch (_) {
      return;
    }
    if (!mounted || gen != _settleGen) return;
    if (commit && target >= 1) {
      _commitTurn();
    } else {
      setState(() {
        _t = 0;
        _dir = 0;
      });
    }
  }

  void _commitTurn() {
    final forward = _dir > 0;
    final atEnd = forward && _index >= widget.pageCount - 1;
    final atStart = !forward && _index <= 0;
    if (atEnd || atStart) {
      setState(() {
        _t = 0;
        _dir = 0;
      });
      widget.onChapterEdge?.call(forward: forward);
      return;
    }
    final next = forward ? _index + 1 : _index - 1;
    setState(() {
      _index = next;
      _t = 0;
      _dir = 0;
    });
    widget.onPageChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.pageSize;
    final underIndex = _dir > 0
        ? _index + 1
        : _dir < 0
        ? _index - 1
        : _index;
    final turning = _t > 0.002 && _dir != 0;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _pointerDown,
      onPointerMove: _pointerMove,
      onPointerUp: _pointerUp,
      onPointerCancel: _pointerCancel,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: widget.sheetColor),
            if (turning &&
                underIndex >= 0 &&
                underIndex < widget.pageCount)
              widget.pageBuilder(context, underIndex)
            else if (turning)
              ColoredBox(color: widget.sheetColor),
            if (!turning)
              widget.pageBuilder(context, _index)
            else
              ClipPath(
                clipper: _CurlClipper(t: _t, forward: _dir > 0),
                child: widget.pageBuilder(context, _index),
              ),
            if (turning)
              IgnorePointer(
                child: CustomPaint(
                  painter: _CurlShadePainter(
                    t: _t,
                    forward: _dir > 0,
                    paper: widget.sheetColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Curved leading edge of the peeling sheet (not a hard vertical bar).
class _CurlClipper extends CustomClipper<Path> {
  _CurlClipper({required this.t, required this.forward});

  final double t;
  final bool forward;

  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final edge = forward ? w * (1 - t) : w * t;
    final bulge = (12.0 + t * 28.0).clamp(8.0, 40.0);

    if (forward) {
      path
        ..moveTo(0, 0)
        ..lineTo(math.max(0, edge - bulge * 0.15), 0)
        ..cubicTo(
          edge + bulge * 0.35,
          h * 0.22,
          edge + bulge * 0.35,
          h * 0.78,
          math.max(0, edge - bulge * 0.15),
          h,
        )
        ..lineTo(0, h)
        ..close();
    } else {
      path
        ..moveTo(w, 0)
        ..lineTo(math.min(w, edge + bulge * 0.15), 0)
        ..cubicTo(
          edge - bulge * 0.35,
          h * 0.22,
          edge - bulge * 0.35,
          h * 0.78,
          math.min(w, edge + bulge * 0.15),
          h,
        )
        ..lineTo(w, h)
        ..close();
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _CurlClipper old) =>
      old.t != t || old.forward != forward;
}

/// Soft fold + drop shadow. No spine, no opaque black bar.
class _CurlShadePainter extends CustomPainter {
  _CurlShadePainter({
    required this.t,
    required this.forward,
    required this.paper,
  });

  final double t;
  final bool forward;
  final Color paper;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final edge = forward ? w * (1 - t) : w * t;
    final bulge = (12.0 + t * 28.0).clamp(8.0, 40.0);
    final foldW = 18.0 + t * 22.0;
    final ink = paper.computeLuminance() < 0.45;

    final shadow = Paint()
      ..shader = ui.Gradient.linear(
        Offset(edge, 0),
        Offset(forward ? edge + foldW * 1.8 : edge - foldW * 1.8, 0),
        [
          (ink ? Colors.black : const Color(0xFF3A342C)).withValues(
            alpha: 0.10 + t * 0.16,
          ),
          Colors.transparent,
        ],
      );

    final shadowRect = forward
        ? Rect.fromLTWH(edge, 0, foldW * 1.8, h)
        : Rect.fromLTWH(edge - foldW * 1.8, 0, foldW * 1.8, h);
    canvas.drawRect(shadowRect, shadow);

    final foldPath = Path();
    if (forward) {
      foldPath
        ..moveTo(edge - bulge * 0.1, 0)
        ..cubicTo(
          edge + bulge * 0.4,
          h * 0.22,
          edge + bulge * 0.4,
          h * 0.78,
          edge - bulge * 0.1,
          h,
        )
        ..lineTo(edge + foldW * 0.55, h)
        ..cubicTo(
          edge + foldW * 0.15 + bulge * 0.2,
          h * 0.78,
          edge + foldW * 0.15 + bulge * 0.2,
          h * 0.22,
          edge + foldW * 0.55,
          0,
        )
        ..close();
    } else {
      foldPath
        ..moveTo(edge + bulge * 0.1, 0)
        ..cubicTo(
          edge - bulge * 0.4,
          h * 0.22,
          edge - bulge * 0.4,
          h * 0.78,
          edge + bulge * 0.1,
          h,
        )
        ..lineTo(edge - foldW * 0.55, h)
        ..cubicTo(
          edge - foldW * 0.15 - bulge * 0.2,
          h * 0.78,
          edge - foldW * 0.15 - bulge * 0.2,
          h * 0.22,
          edge - foldW * 0.55,
          0,
        )
        ..close();
    }

    final underside = Color.lerp(
      paper,
      ink ? Colors.white : const Color(0xFF2A2620),
      ink ? 0.08 : 0.10,
    )!;
    canvas.drawPath(
      foldPath,
      Paint()
        ..color = underside
        ..style = PaintingStyle.fill,
    );

    final gloss = Paint()
      ..shader = ui.Gradient.linear(
        Offset(edge, 0),
        Offset(forward ? edge + foldW * 0.5 : edge - foldW * 0.5, 0),
        [
          Colors.white.withValues(alpha: ink ? 0.10 : 0.28),
          Colors.transparent,
        ],
      );
    canvas.drawPath(foldPath, gloss);

    final rim = Paint()
      ..color = (ink ? Colors.white : Colors.black).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(foldPath, rim);
  }

  @override
  bool shouldRepaint(covariant _CurlShadePainter old) =>
      old.t != t || old.forward != forward || old.paper != paper;
}

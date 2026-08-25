import 'package:flutter/material.dart';

import '../../../theme/tokens/app_motion.dart';

enum SheetTurnDirection { none, forward, back }

/// Stack of two opaque sheets. The incoming page never fades or scales.
///
/// Forward (swipe left): current sheet slides off to the left; next is already
/// underneath and stays put.
/// Back (swipe right): previous sheet slides in from the left over the current
/// sheet, which stays put.
class SheetSwitcher extends StatefulWidget {
  const SheetSwitcher({
    super.key,
    required this.index,
    required this.child,
    required this.sheetColor,
    this.direction = SheetTurnDirection.none,
    this.duration = AppMotion.pageTurn,
    this.curve = AppMotion.standard,
    this.disableAnimations = false,
  });

  /// Identity of [child]. A change with [direction] other than [none] animates.
  final int index;
  final Widget child;
  final Color sheetColor;
  final SheetTurnDirection direction;
  final Duration duration;
  final Curve curve;
  final bool disableAnimations;

  @override
  State<SheetSwitcher> createState() => _SheetSwitcherState();
}

class _SheetSwitcherState extends State<SheetSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  Widget? _outgoing;
  SheetTurnDirection _playing = SheetTurnDirection.none;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _outgoing = null;
          _playing = SheetTurnDirection.none;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant SheetSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _ctrl.duration = widget.duration;
    }
    if (oldWidget.index == widget.index) return;
    if (widget.disableAnimations ||
        widget.direction == SheetTurnDirection.none) {
      _outgoing = null;
      _playing = SheetTurnDirection.none;
      _ctrl.value = 1;
      return;
    }
    _outgoing = oldWidget.child;
    _playing = widget.direction;
    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _sheet(Widget child) {
    return ColoredBox(
      color: widget.sheetColor,
      child: SizedBox.expand(child: child),
    );
  }

  Widget _moving(Widget child, {required bool fromLeft}) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = widget.curve.transform(_ctrl.value);
        final w = MediaQuery.sizeOf(context).width;
        final dx = fromLeft ? -w * (1 - t) : -w * t;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x29000000),
                    blurRadius: 16,
                    offset: Offset(fromLeft ? -6 : 6, 0),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _sheet(widget.child);
    final outgoing = _outgoing;
    if (outgoing == null || _playing == SheetTurnDirection.none) {
      return current;
    }
    final oldSheet = _sheet(outgoing);
    if (_playing == SheetTurnDirection.forward) {
      return ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            current,
            _moving(oldSheet, fromLeft: false),
          ],
        ),
      );
    }
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          oldSheet,
          _moving(current, fromLeft: true),
        ],
      ),
    );
  }
}

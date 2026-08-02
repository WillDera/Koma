import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A shimmer-style placeholder box. Use for skeletons while content loads.
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const Skeleton({super.key, this.width, this.height = 16, this.borderRadius});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = widget.borderRadius ?? BorderRadius.circular(10);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        // Constrain the body first with a SizedBox so the layout has a
        // definite size, then layer the gradient on top. We deliberately
        // avoid Container(decoration: BoxDecoration(borderRadius: ...))
        // because that path layers a ClipRRect that can receive
        // unbounded vertical constraints from its parent and fail to
        // lay out.
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment(-1 + _ctrl.value * 2, 0),
                end: Alignment(1 + _ctrl.value * 2, 0),
                colors: [c.surfaceMuted, c.surface, c.surfaceMuted],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        );
      },
    );
  }
}

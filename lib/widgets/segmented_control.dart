import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';
import '../theme/tokens/app_spacing.dart';

/// iOS-style segmented control. T is a stable identifier for each segment
/// (e.g. an enum).
///
/// The widget sizes to its content when placed in an unbounded parent
/// (e.g. inside a Row). When the parent supplies bounded width (e.g. when
/// placed in a Column), the segments expand to fill it.
class SegmentedControl<T extends Object> extends StatelessWidget {
  final Map<T, String> segments;
  final T? value;
  final ValueChanged<T> onChanged;
  final double height;
  final EdgeInsets padding;
  final double minWidth;

  const SegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.height = 38,
    this.padding = const EdgeInsets.all(3),
    this.minWidth = 100,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final segmentStyle = (Theme.of(context).textTheme.labelMedium ??
            const TextStyle())
        .copyWith(fontSize: 13, letterSpacing: 0.1);
    final entries = segments.entries.toList();
    final selectedIndex = value == null
        ? -1
        : entries.indexWhere((e) => e.key == value);

    // The outer wrapper is a ColoredBox + padding + height only. We do not
    // wrap in a Container(height: ...) because that creates a
    // ConstrainedBox with loose width constraints, which fails to lay out
    // when the parent is unbounded (e.g. inside a Row).
    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        // If the parent gave us a finite width, divide it among segments.
        // Otherwise, fall back to a per-segment min width so the inner
        // Row can still lay out.
        final hasBoundedWidth = constraints.hasBoundedWidth;
        final perSeg = hasBoundedWidth
            ? ((constraints.maxWidth - padding.horizontal) / entries.length)
                  .clamp(0.0, double.infinity)
            : (minWidth / entries.length).clamp(40.0, 200.0);
        final totalWidth = hasBoundedWidth
            ? constraints.maxWidth
            : perSeg * entries.length + padding.horizontal;
        return SizedBox(
          width: totalWidth,
          height: height,
          child: Padding(
            padding: padding,
            child: Stack(
              children: [
                if (selectedIndex >= 0)
                  AnimatedPositioned(
                    duration: AppMotion.base,
                    curve: AppMotion.standard,
                    left: perSeg * selectedIndex,
                    top: 0,
                    width: perSeg,
                    height: height - padding.vertical,
                    child: AnimatedContainer(
                      duration: AppMotion.base,
                      curve: AppMotion.standard,
                      decoration: BoxDecoration(
                        color: c.accent,
                        // Figma active segment: rounded-lg (8).
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                Row(
                  children: List.generate(entries.length, (i) {
                    final entry = entries[i];
                    final isSelected = i == selectedIndex;
                    return SizedBox(
                      width: perSeg,
                      height: height - padding.vertical,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(entry.key),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: AppMotion.base,
                            style: segmentStyle.copyWith(
                              color: isSelected ? c.onAccent : c.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            child: Text(entry.value),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Outer chrome (background + radius) as a DecoratedBox rather than
    // a Container(height: ...), so it does not impose width constraints.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: AppSpacing.brMd,
      ),
      child: content,
    );
  }
}

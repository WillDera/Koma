import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_colors.dart';
import '../theme/tokens/app_motion.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';

class HighlightColorPicker extends StatelessWidget {
  final List<String> colors;
  final String selected;
  final ValueChanged<String> onChanged;

  const HighlightColorPicker({
    super.key,
    required this.colors,
    required this.selected,
    required this.onChanged,
  });

  static const List<String> palette = ['yellow', 'blue', 'pink', 'green'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isSepia = c.bg == AppColors.sepiaBg;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: c.textPrimary.withValues(alpha: 0.92),
        borderRadius: AppSpacing.brPill,
        boxShadow: AppSpacing.shadow2(isDark: c.bg.computeLuminance() < 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: colors.map((key) {
          final isSelected = selected == key;
          final color = AppColors.highlight(
            key,
            Brightness.light,
            isSepia: isSepia,
          );
          return AnimatedPress(
            onTap: () => onChanged(key),
            scaleDown: 0.85,
            child: AnimatedContainer(
              duration: AppMotion.base,
              curve: AppMotion.standard,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? c.bg
                      : Colors.white.withValues(alpha: 0.3),
                  width: isSelected ? 2.5 : 1.5,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 16, color: c.textPrimary)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens/app_colors.dart';
import '../theme/tokens/app_motion.dart';
import '../theme/tokens/glass_blur.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';
import 'highlight_color_picker.dart';

/// The custom text selection toolbar for the reader. Indigo floating
/// pill with colour swatches (Highlight), Snippet, Copy, Share, and
/// Remove when the selection already covers a mark.
class ReaderSelectionToolbar extends StatelessWidget {
  final String selectedColor;
  final ValueChanged<String> onHighlight;
  final VoidCallback? onRemove;
  final VoidCallback onNote;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  const ReaderSelectionToolbar({
    super.key,
    required this.selectedColor,
    required this.onHighlight,
    this.onRemove,
    required this.onNote,
    required this.onCopy,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isSepia = c.bg == AppColors.sepiaBg;
    final brightness = Theme.of(context).brightness;
    return Center(
      child: GlassBlur.layer(
        borderRadius: AppSpacing.brPill,
        child: AnimatedContainer(
          duration: AppMotion.base,
          curve: AppMotion.standard,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: c.textPrimary.withValues(alpha: 0.92),
            borderRadius: AppSpacing.brPill,
            boxShadow: AppSpacing.shadow3(
              isDark: c.bg.computeLuminance() < 0.5,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final key in HighlightColorPicker.palette)
                  _ColorSwatch(
                    colorKey: key,
                    color: AppColors.highlight(
                      key,
                      brightness,
                      isSepia: isSepia,
                    ),
                    selected: selectedColor == key,
                    onTap: () => onHighlight(key),
                  ),
                if (onRemove != null) ...[
                  _Divider(),
                  _ToolAction(
                    icon: Icons.format_color_reset,
                    label: 'Remove',
                    onTap: onRemove!,
                  ),
                ],
                _Divider(),
                _ToolAction(
                  icon: Icons.edit_note,
                  label: 'Snippet',
                  onTap: onNote,
                ),
                _Divider(),
                _ToolAction(icon: Icons.copy, label: 'Copy', onTap: onCopy),
                _Divider(),
                _ToolAction(
                  icon: Icons.ios_share,
                  label: 'Share',
                  onTap: onShare,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.colorKey,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String colorKey;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Highlight $colorKey',
      selected: selected,
      child: AnimatedPress(
        onTap: onTap,
        scaleDown: 0.85,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: AppMotion.base,
            curve: AppMotion.standard,
            width: selected ? 26 : 22,
            height: selected ? 26 : 22,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? c.bg : Colors.white.withValues(alpha: 0.35),
                width: selected ? 2.5 : 1.5,
              ),
            ),
            child: selected
                ? Icon(Icons.check, size: 14, color: c.textPrimary)
                : null,
          ),
        ),
      ),
    );
  }
}

class _ToolAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ToolAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: onTap,
      scaleDown: 0.92,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c.bg, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: c.bg,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.5,
      height: 18,
      color: context.colors.bg.withValues(alpha: 0.2),
    );
  }
}

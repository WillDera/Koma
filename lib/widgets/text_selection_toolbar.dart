import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';

/// The custom text selection toolbar for the reader. Indigo floating
/// pill with action chips (Highlight, Note, Copy, Share).
class ReaderSelectionToolbar extends StatelessWidget {
  final String selectedText;
  final String defaultHighlightColor;
  final ValueChanged<String> onHighlight;
  final VoidCallback onNote;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final Offset position;

  const ReaderSelectionToolbar({
    super.key,
    required this.selectedText,
    required this.defaultHighlightColor,
    required this.onHighlight,
    required this.onNote,
    required this.onCopy,
    required this.onShare,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Positioned(
      left: 16,
      right: 16,
      bottom: 120,
      child: Center(
        child: ClipRRect(
          borderRadius: AppSpacing.brPill,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ToolAction(
                    icon: Icons.format_color_fill,
                    label: 'Mark',
                    onTap: () => onHighlight(defaultHighlightColor),
                  ),
                  _Divider(),
                  _ToolAction(
                    icon: Icons.edit_note,
                    label: 'Snippet',
                    onTap: onNote,
                  ),
                  _Divider(),
                  _ToolAction(
                    icon: Icons.copy,
                    label: 'Copy',
                    onTap: onCopy,
                  ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

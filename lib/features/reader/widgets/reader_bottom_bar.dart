import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/animated_press.dart';

/// Kenji-style manga bottom chrome: pill page scrubber + circular controls.
class ReaderBottomBar extends StatelessWidget {
  final ValueListenable<int> pageListenable;
  final int totalPages;
  final bool showNavigator;
  final void Function(int) onPageChanged;
  final VoidCallback onSettings;
  final VoidCallback? onCropToggle;
  final VoidCallback? onPreviousChapter;
  final VoidCallback? onNextChapter;
  final bool isVisible;

  const ReaderBottomBar({
    super.key,
    required this.pageListenable,
    required this.totalPages,
    required this.showNavigator,
    required this.onPageChanged,
    required this.onSettings,
    this.onCropToggle,
    this.onPreviousChapter,
    this.onNextChapter,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      bottom: isVisible ? 0 : -220,
      left: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 8,
          bottom: MediaQuery.of(context).padding.bottom + 10,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showNavigator)
              ValueListenableBuilder<int>(
                valueListenable: pageListenable,
                builder: (_, page, _) {
                  return Row(
                    children: [
                      _CircleBtn(
                        icon: Icons.chevron_left,
                        enabled: page > 0,
                        onTap: () => onPageChanged(page - 1),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              if (onPreviousChapter != null)
                                _MiniIcon(
                                  icon: Icons.skip_previous_rounded,
                                  onTap: onPreviousChapter!,
                                ),
                              SizedBox(
                                width: 36,
                                child: Text(
                                  '${page + 1}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: c.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 7,
                                    ),
                                    overlayShape:
                                        const RoundSliderOverlayShape(
                                      overlayRadius: 14,
                                    ),
                                    activeTrackColor: c.accent,
                                    inactiveTrackColor: c.border,
                                    thumbColor: c.textPrimary,
                                    overlayColor: c.accent.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                  child: Slider(
                                    value: page.toDouble(),
                                    min: 0,
                                    max: max(0, (totalPages - 1).toDouble()),
                                    divisions: totalPages > 1
                                        ? totalPages - 1
                                        : null,
                                    onChanged: (v) =>
                                        onPageChanged(v.round()),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 36,
                                child: Text(
                                  '$totalPages',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: c.textTertiary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (onNextChapter != null)
                                _MiniIcon(
                                  icon: Icons.skip_next_rounded,
                                  onTap: onNextChapter!,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CircleBtn(
                        icon: Icons.chevron_right,
                        enabled: page < totalPages - 1,
                        onTap: () => onPageChanged(page + 1),
                        filled: true,
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FloatAction(
                  icon: Icons.crop_outlined,
                  tooltip: 'Crop borders',
                  onPressed: onCropToggle ?? onSettings,
                ),
                const SizedBox(width: 16),
                _FloatAction(
                  icon: Icons.settings_rounded,
                  tooltip: 'Settings',
                  onPressed: onSettings,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool filled;

  const _CircleBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = filled && enabled ? c.accent : const Color(0xFF1A1A1A);
    final fg = filled && enabled
        ? c.onAccent
        : (enabled ? c.textPrimary : c.textTertiary.withValues(alpha: 0.4));
    return AnimatedPress(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: fg, size: 26),
      ),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MiniIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: context.colors.textSecondary, size: 20),
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}

class _FloatAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _FloatAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: const Color(0xFF1A1A1A),
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: c.textSecondary, size: 22),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}

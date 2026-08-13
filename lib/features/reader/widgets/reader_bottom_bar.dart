import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Reader bottom bar with page navigation + specialized quick actions.
///
/// Layout:
/// - Page slider in a rounded pill container with prev/next buttons
/// - Chapter skip buttons (skip_previous / skip_next)
/// - Quick actions row: reading mode, crop borders, settings
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
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      bottom: isVisible ? 0 : -200,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            top: 8,
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Page slider in a rounded pill ──
              if (showNavigator)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: ValueListenableBuilder<int>(
                      valueListenable: pageListenable,
                      builder: (_, page, _) => Row(
                        children: [
                          // Prev page arrow
                          _PageButton(
                            icon: Icons.chevron_left,
                            enabled: page > 0,
                            onTap: () => onPageChanged(page - 1),
                          ),
                          // Prev chapter
                          if (onPreviousChapter != null)
                            _PageButton(
                              icon: Icons.skip_previous_rounded,
                              enabled: true,
                              onTap: onPreviousChapter!,
                            ),
                          // Page label
                          SizedBox(
                            width: 44,
                            child: Center(
                              child: Text(
                                '${page + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          // Slider
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 12,
                                ),
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: Colors.white,
                                overlayColor: Colors.white12,
                                valueIndicatorColor: Colors.white,
                                valueIndicatorTextStyle: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                ),
                              ),
                              child: Slider(
                                value: page.toDouble(),
                                min: 0,
                                max: max(0, (totalPages - 1).toDouble()),
                                divisions: totalPages > 1
                                    ? totalPages - 1
                                    : null,
                                onChanged: (v) => onPageChanged(v.round()),
                              ),
                            ),
                          ),
                          // Total pages label
                          SizedBox(
                            width: 44,
                            child: Center(
                              child: Text(
                                '$totalPages',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          // Next chapter
                          if (onNextChapter != null)
                            _PageButton(
                              icon: Icons.skip_next_rounded,
                              enabled: true,
                              onTap: onNextChapter!,
                            ),
                          // Next page arrow
                          _PageButton(
                            icon: Icons.chevron_right,
                            enabled: page < totalPages - 1,
                            onTap: () => onPageChanged(page + 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 6),

              // ── Quick action buttons ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ActionButton(
                      icon: Icons.crop_outlined,
                      tooltip: 'Crop borders',
                      onPressed: onCropToggle ?? onSettings,
                    ),
                    _ActionButton(
                      icon: Icons.settings_rounded,
                      tooltip: 'Settings',
                      onPressed: onSettings,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PageButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        icon,
        color: enabled ? Colors.white70 : Colors.white24,
        size: 22,
      ),
      onPressed: enabled ? onTap : null,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.white70, size: 22),
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }
}

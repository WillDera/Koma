import 'package:flutter/material.dart';

import '../core/models/chapter.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_spacing.dart';
import '../theme/tokens/app_type.dart';

/// Cinematic chapter navigation overlay with a slider.
///
/// Shows a slide-up panel with a large chapter scrubber, current chapter
/// title, and prev/next buttons. Designed for the Aethelgard neo-noir
/// aesthetic (glassmorphism surface, accent tint, rounded pill slider).
class ChapterNavOverlay extends StatefulWidget {
  final List<Chapter> chapters;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const ChapterNavOverlay({
    super.key,
    required this.chapters,
    required this.currentIndex,
    required this.onSelect,
    required this.onPrevious,
    required this.onNext,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Chapter> chapters,
    required int currentIndex,
    required ValueChanged<int> onSelect,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => ChapterNavOverlay(
        chapters: chapters,
        currentIndex: currentIndex,
        onSelect: onSelect,
        onPrevious: onPrevious,
        onNext: onNext,
      ),
    );
  }

  @override
  State<ChapterNavOverlay> createState() => _ChapterNavOverlayState();
}

class _ChapterNavOverlayState extends State<ChapterNavOverlay> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.currentIndex.clamp(0, widget.chapters.length - 1);
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.chapters.length || index == _index) {
      return;
    }
    setState(() => _index = index);
    widget.onSelect(index);
  }

  void _previous() {
    if (_index <= 0) return;
    setState(() => _index -= 1);
    widget.onPrevious();
  }

  void _next() {
    if (_index >= widget.chapters.length - 1) return;
    setState(() => _index += 1);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ch = widget.chapters[_index];
    final last = widget.chapters.length - 1;
    final progress = last > 0 ? _index / last : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.of(context).padding.bottom + AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: AppSpacing.brXxl,
        boxShadow: AppSpacing.shadow4(isDark: c.bg.computeLuminance() < 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: c.borderStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Chapter title + meta
          Text(
            'Chapter ${_index + 1} of ${widget.chapters.length}',
            style: AppType.labelCaps(fontSize: 12, color: c.textTertiary),
          ),
          const SizedBox(height: 6),
          Text(
            ch.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              height: 26 / 20,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Slider
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              borderRadius: AppSpacing.brPill,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.skip_previous_rounded,
                    color: _index > 0 ? c.textSecondary : c.textTertiary,
                  ),
                  onPressed: _index > 0 ? _previous : null,
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 14,
                        elevation: 6,
                        pressedElevation: 10,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 24,
                      ),
                      activeTrackColor: c.accent,
                      inactiveTrackColor: c.borderStrong,
                      thumbColor: c.accent,
                      overlayColor: c.accent.withValues(alpha: 0.18),
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      min: 0.0,
                      max: 1.0,
                      divisions: last > 0 ? last : null,
                      onChanged: last > 0
                          ? (v) => _goTo((v * last).round())
                          : null,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.skip_next_rounded,
                    color: _index < last ? c.textSecondary : c.textTertiary,
                  ),
                  onPressed: _index < last ? _next : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';

/// A gentle 7-day reading streak heatmap card. Used on Library home.
/// No gamification, no flames, no aggressive "🔥" — just a calm row of
/// 7 dots whose intensity reflects minutes read that day.
class ReadingStreakCard extends StatelessWidget {
  final List<int> minutesPerDay; // length 7, index 0 = oldest
  final int currentStreak;
  final VoidCallback? onTap;

  const ReadingStreakCard({
    super.key,
    required this.minutesPerDay,
    required this.currentStreak,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final maxMin = minutesPerDay
        .fold<int>(0, (a, b) => a > b ? a : b)
        .clamp(1, 10000);
    final labels = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return AnimatedPress(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: AppSpacing.brXl,
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentStreak == 0
                        ? 'Start a streak'
                        : '$currentStreak day${currentStreak == 1 ? '' : 's'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Your reading rhythm',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                children: List.generate(7, (i) {
                  final mins = minutesPerDay[i];
                  final intensity = maxMin == 0
                      ? 0.0
                      : (mins / maxMin).clamp(0.0, 1.0);
                  final color = Color.lerp(
                    c.surfaceMuted,
                    c.accent,
                    intensity,
                  )!;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: AppMotion.base,
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          labels[i],
                          style: TextStyle(
                            color: c.textTertiary,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

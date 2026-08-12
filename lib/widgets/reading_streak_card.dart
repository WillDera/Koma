import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';

/// A compact seven-day reading summary that opens the full activity calendar.
class ReadingStreakCard extends StatelessWidget {
  final List<int> minutesPerDay;
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
    final labels = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final weeklyMinutes = minutesPerDay.fold<int>(0, (sum, value) => sum + value);

    return AnimatedPress(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.fromLTRB(18, 17, 18, 15),
        decoration: BoxDecoration(
          color: c.surfaceMuted,
          borderRadius: AppSpacing.brXl,
          border: Border.all(color: c.border.withValues(alpha: 0.7), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.14),
                    borderRadius: AppSpacing.brMd,
                  ),
                  child: Icon(Icons.auto_stories_rounded, color: c.accent, size: 20),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentStreak == 0
                            ? 'Begin a reading trail'
                            : '$currentStreak-day reading trail',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$weeklyMinutes min across the last seven days',
                        style: TextStyle(color: c.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.calendar_month_rounded, color: c.textTertiary, size: 20),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: List.generate(7, (i) {
                final minutes = minutesPerDay[i];
                final (fill, text) = _miniColors(c, minutes);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == 6 ? 0 : 7),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: AppMotion.base,
                          height: 31,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(9)),
                          child: minutes >= 90
                              ? const Icon(Icons.local_fire_department_rounded, size: 17, color: Colors.white)
                              : Text(
                                  minutes == 0 ? '·' : '$minutes',
                                  style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                        ),
                        const SizedBox(height: 5),
                        Text(labels[i], style: TextStyle(color: c.textTertiary, fontSize: 10, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  (Color, Color) _miniColors(KomaColors c, int minutes) {
    if (minutes >= 90) return (const Color(0xFFC6381A), Colors.white);
    if (minutes >= 45) return (const Color(0xFFFF7138), Colors.white);
    if (minutes >= 20) return (const Color(0xFFFFB55E), const Color(0xFF542600));
    if (minutes >= 7) return (const Color(0xFFFFE1A8), const Color(0xFF6D4300));
    if (minutes > 0) return (c.accentMuted.withValues(alpha: 0.45), c.textSecondary);
    return (c.surface, c.textTertiary);
  }
}

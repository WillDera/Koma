import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Accent count pill for titles with unopened update chapters.
class NewChapterCountBadge extends StatelessWidget {
  const NewChapterCountBadge({
    super.key,
    required this.count,
    this.small = false,
  });

  final int count;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 5 : 7,
        vertical: small ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: c.accent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 0.8,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: c.onAccent,
          fontSize: small ? 9 : 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Accent "NEW" chip for chapter rows discovered by a library update.
class NewChapterTag extends StatelessWidget {
  const NewChapterTag({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.accent.withValues(alpha: 0.55)),
      ),
      child: Text(
        'NEW',
        style: TextStyle(
          color: c.accent,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Dimmed cover overlay while metadata (or similar) work is in progress.
class CoverWorkingOverlay extends StatelessWidget {
  const CoverWorkingOverlay({super.key, this.label = 'Fetching…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: c.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

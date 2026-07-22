import 'dart:io';
import 'package:flutter/material.dart';
import '../core/models/book.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';
import '../theme/tokens/app_spacing.dart';

enum BookCoverVariant { grid, list, hero, compact }

/// Single source of truth for book cover rendering.
///
/// Generates a warm gradient placeholder derived from the book title hash
/// when no cover image is available. The placeholder shows the first 1-2
/// letters of the title in a serif/display style.
class BookCover extends StatelessWidget {
  final Book book;
  final BookCoverVariant variant;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const BookCover({
    super.key,
    required this.book,
    this.variant = BookCoverVariant.grid,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = borderRadius ??
        switch (variant) {
          BookCoverVariant.grid => AppSpacing.brMd,
          BookCoverVariant.list => AppSpacing.brSm,
          BookCoverVariant.hero => AppSpacing.brLg,
          BookCoverVariant.compact => AppSpacing.brSm,
        };

    final hasCover =
        book.coverPath != null && book.coverPath!.isNotEmpty;
    final image = hasCover
        ? Image.file(
            File(book.coverPath!),
            fit: fit,
            errorBuilder: (_, _, _) => _placeholder(c),
          )
        : _placeholder(c);

    final child = ClipRRect(
      borderRadius: radius,
      child: image,
    );

    if (variant == BookCoverVariant.grid ||
        variant == BookCoverVariant.hero) {
      return AspectRatio(
        aspectRatio: 3 / 4,
        child: child,
      );
    }
    if (variant == BookCoverVariant.list) {
      return SizedBox(
        width: 44,
        height: 64,
        child: child,
      );
    }
    return SizedBox(
      width: 32,
      height: 44,
      child: child,
    );
  }

  Widget _placeholder(KomaColors c) {
    final gradient = _gradientFor(book.title, c);
    final monogram = _monogramFor(book.title);
    final sourceIcon = _sourceIcon(book.source);
    final showSubtitle = variant == BookCoverVariant.hero ||
        variant == BookCoverVariant.grid;

    return AnimatedContainer(
      duration: AppMotion.base,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: Stack(
        children: [
          // Subtle paper texture / noise hint (using a soft radial gradient)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.6, -0.8),
                  radius: 1.2,
                  colors: [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      sourceIcon,
                      size: 11,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                if (showSubtitle)
                  Text(
                    monogram,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: variant == BookCoverVariant.hero ? 64 : 26,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1,
                      height: 1,
                      fontFamily: 'serif',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _monogramFor(String title) {
    final cleaned = title.trim();
    if (cleaned.isEmpty) return '··';
    if (cleaned.length == 1) return cleaned.toUpperCase();
    // Take first 2 characters
    return cleaned.substring(0, 2).toUpperCase();
  }

  IconData _sourceIcon(String source) {
    switch (source) {
      case 'web':
        return Icons.language;
      case 'manual':
        return Icons.edit_note;
      default:
        return Icons.auto_stories;
    }
  }

  List<Color> _gradientFor(String title, KomaColors c) {
    // Hash the title to a stable pair of accent colors. Use the theme's
    // accent + accentMuted so the placeholder always feels on-brand.
    final hash = title.codeUnits.fold<int>(0, (acc, ch) => acc + ch);
    final palettes = <List<Color>>[
      [c.accent, c.accent.withValues(alpha: 0.7)],
      [
        c.accent.withValues(alpha: 0.85),
        c.accentMuted,
      ],
      [c.textPrimary, c.textSecondary],
      [c.accent, c.textPrimary],
      [c.textSecondary, c.accent],
    ];
    return palettes[hash % palettes.length];
  }
}

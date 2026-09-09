import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/manga.dart';
import '../core/models/reading_stat.dart';
import '../core/providers.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_colors.dart';
import '../theme/tokens/app_spacing.dart';
import 'reading_calendar_sheet.dart';
import 'reading_streak_card.dart';
import 'settings_section.dart';

/// Interactive reading stats (streak + library breakdown).
///
/// Used in You → Data and the long-press You nav popup.
class LibraryStatsPanel extends ConsumerStatefulWidget {
  const LibraryStatsPanel({
    super.key,
    this.embedded = false,
    this.onOpenCalendar,
  });

  /// When true, skips the outer [SettingsSection] chrome (popup already frames it).
  final bool embedded;

  final VoidCallback? onOpenCalendar;

  @override
  ConsumerState<LibraryStatsPanel> createState() => _LibraryStatsPanelState();
}

class _LibraryStatsPanelState extends ConsumerState<LibraryStatsPanel> {
  Map<String, int> _genres = {};
  Map<String, int> _formats = {};
  int _completed = 0;
  int _totalBooks = 0;
  int _totalManga = 0;
  int _chaptersRead = 0;
  int _mangaCompleted = 0;
  int _totalReadingMinutes = 0;
  int _monthReadingMinutes = 0;
  List<int> _minutesPerDay = List.filled(7, 0);
  int _streak = 0;
  bool _loading = true;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final repos = ref.read(repositoriesProvider);
    final statsSvc = ref.read(statsServiceProvider);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final results = await Future.wait([
      repos.books.getGenreCounts(),
      repos.books.getExtensionCounts(),
      repos.books.getCompletedBooksCount(),
      repos.books.getBooks(),
      repos.manga.getMangasInLibrary(),
      statsSvc.getWeeklyStreak(),
      statsSvc.getStats(DateTime(2000, 1, 1), now),
      statsSvc.getStats(monthStart, now),
    ]);
    if (!mounted) return;

    final mangas = results[4] as List<Manga>;
    final allStats = results[6] as List<ReadingStat>;
    final monthStats = results[7] as List<ReadingStat>;

    final mangaGenres = <String, int>{};
    var chaptersRead = 0;
    var mangaCompleted = 0;
    for (final manga in mangas) {
      for (final g in manga.genres) {
        final key = g.trim();
        if (key.isEmpty) continue;
        mangaGenres[key] = (mangaGenres[key] ?? 0) + 1;
      }
      if (manga.status == 2) mangaCompleted++;
      final chapters = await repos.manga.getMangaChapters(manga.id);
      chaptersRead += chapters.where((c) => c.isRead).length;
    }

    final bookGenres = Map<String, int>.from(results[0] as Map<String, int>);
    for (final e in mangaGenres.entries) {
      bookGenres[e.key] = (bookGenres[e.key] ?? 0) + e.value;
    }

    setState(() {
      _genres = bookGenres;
      _formats = results[1] as Map<String, int>;
      _completed = results[2] as int;
      _totalBooks = (results[3] as List).length;
      _totalManga = mangas.length;
      _chaptersRead = chaptersRead;
      _mangaCompleted = mangaCompleted;
      _totalReadingMinutes =
          allStats.fold<int>(0, (s, r) => s + r.readingTimeSeconds) ~/ 60;
      _monthReadingMinutes =
          monthStats.fold<int>(0, (s, r) => s + r.readingTimeSeconds) ~/ 60;
      final streak =
          results[5] as ({List<int> minutesPerDay, int currentStreak});
      _minutesPerDay = streak.minutesPerDay;
      _streak = streak.currentStreak;
      _loading = false;
    });
  }

  void _openCalendar() {
    final custom = widget.onOpenCalendar;
    if (custom != null) {
      custom();
      return;
    }
    showReadingCalendarSheet(context, ref.read(statsServiceProvider));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ReadingStreakCard(
          minutesPerDay: _minutesPerDay,
          currentStreak: _streak,
          onTap: _openCalendar,
        ),
        _StatsReadingTimeRow(
          totalMinutes: _totalReadingMinutes,
          monthMinutes: _monthReadingMinutes,
          chaptersRead: _chaptersRead,
        ),
        _StatsLibraryBreakdown(
          completed: _completed,
          totalBooks: _totalBooks,
          totalManga: _totalManga,
          mangaCompleted: _mangaCompleted,
          formats: _formats,
          genres: _genres,
        ),
      ],
    );

    if (widget.embedded) return body;

    return SettingsSection(
      title: 'Stats',
      headerColor: AppColors.figmaAmber,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [body],
    );
  }
}

class _StatsReadingTimeRow extends StatelessWidget {
  const _StatsReadingTimeRow({
    required this.totalMinutes,
    required this.monthMinutes,
    required this.chaptersRead,
  });

  final int totalMinutes;
  final int monthMinutes;
  final int chaptersRead;

  String _fmt(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: c.surfaceMuted,
          borderRadius: AppSpacing.brXl,
          border: Border.all(color: c.border.withValues(alpha: 0.7), width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: _StatsMetricTile(
                label: 'All time',
                value: _fmt(totalMinutes),
                icon: Icons.hourglass_bottom_rounded,
              ),
            ),
            _StatsMetricDivider(color: c.border),
            Expanded(
              child: _StatsMetricTile(
                label: 'This month',
                value: _fmt(monthMinutes),
                icon: Icons.calendar_today_outlined,
              ),
            ),
            _StatsMetricDivider(color: c.border),
            Expanded(
              child: _StatsMetricTile(
                label: 'Chapters',
                value: '$chaptersRead',
                icon: Icons.menu_book_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsLibraryBreakdown extends StatelessWidget {
  const _StatsLibraryBreakdown({
    required this.completed,
    required this.totalBooks,
    required this.totalManga,
    required this.mangaCompleted,
    required this.formats,
    required this.genres,
  });

  final int completed;
  final int totalBooks;
  final int totalManga;
  final int mangaCompleted;
  final Map<String, int> formats;
  final Map<String, int> genres;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                Expanded(
                  child: _StatsMetricTile(
                    label: 'Books done',
                    value: '$completed',
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ),
                _StatsMetricDivider(color: c.border),
                Expanded(
                  child: _StatsMetricTile(
                    label: 'Books',
                    value: '$totalBooks',
                    icon: Icons.menu_book_outlined,
                  ),
                ),
                if (totalManga > 0) ...[
                  _StatsMetricDivider(color: c.border),
                  Expanded(
                    child: _StatsMetricTile(
                      label: 'Manga',
                      value: '$totalManga',
                      icon: Icons.auto_stories_outlined,
                    ),
                  ),
                ],
              ],
            ),
            if (totalManga > 0) ...[
              const SizedBox(height: 14),
              Text(
                'Manga completed: $mangaCompleted of $totalManga',
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            _StatsBreakdownGroup(
              title: 'Formats',
              items: formats,
              emptyHint: 'Import books to see format breakdown',
            ),
            const SizedBox(height: 14),
            _StatsBreakdownGroup(
              title: 'Genres',
              items: genres,
              emptyHint: 'Add manga or enrich book metadata for genres',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsMetricTile extends StatelessWidget {
  const _StatsMetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Icon(icon, size: 17, color: c.accent.withValues(alpha: 0.85)),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: c.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _StatsMetricDivider extends StatelessWidget {
  const _StatsMetricDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.5,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: color.withValues(alpha: 0.7),
    );
  }
}

class _StatsBreakdownGroup extends StatelessWidget {
  const _StatsBreakdownGroup({
    required this.title,
    required this.items,
    required this.emptyHint,
  });

  final String title;
  final Map<String, int> items;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final labelStyle = TextStyle(
      color: c.textTertiary,
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.7,
    );

    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: labelStyle),
          const SizedBox(height: 6),
          Text(
            emptyHint,
            style: TextStyle(color: c.textSecondary, fontSize: 12),
          ),
        ],
      );
    }

    final sorted = items.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = sorted.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: labelStyle),
        const SizedBox(height: 8),
        ...sorted.take(8).map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    entry.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: entry.value / maxCount,
                      minHeight: 5,
                      backgroundColor: c.border.withValues(alpha: 0.55),
                      color: c.accent.withValues(alpha: 0.75),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  child: Text(
                    '${entry.value}',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

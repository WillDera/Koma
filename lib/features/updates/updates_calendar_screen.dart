import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/manga.dart';
import '../../core/providers.dart';
import '../../core/services/updates_calendar_service.dart';
import '../../core/utils/image_cache.dart';
import '../../core/utils/image_headers.dart';
import '../../router/router.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_transitions.dart';
import '../../widgets/screen_chrome.dart';

/// Month calendar of estimated next chapter releases (Mangayomi-style).
class UpdatesCalendarScreen extends ConsumerStatefulWidget {
  const UpdatesCalendarScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      scaleFadeRoute(const UpdatesCalendarScreen()),
    );
  }

  @override
  ConsumerState<UpdatesCalendarScreen> createState() =>
      _UpdatesCalendarScreenState();
}

class _UpdatesCalendarScreenState extends ConsumerState<UpdatesCalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;
  List<UpcomingRelease> _all = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final svc = UpdatesCalendarService(ref.read(repositoriesProvider));
    final items = await svc.loadUpcoming();
    if (!mounted) return;
    setState(() {
      _all = items;
      _loading = false;
      _selectedDay ??= DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
    });
  }

  Map<DateTime, List<UpcomingRelease>> get _byDay {
    final map = <DateTime, List<UpcomingRelease>>{};
    for (final e in _all) {
      map.putIfAbsent(e.expectedDate, () => []).add(e);
    }
    return map;
  }

  List<UpcomingRelease> get _selectedItems {
    final day = _selectedDay;
    if (day == null) return const [];
    return _byDay[DateTime(day.year, day.month, day.day)] ?? const [];
  }

  List<UpcomingRelease> get _monthItems {
    return _all
        .where(
          (e) =>
              e.expectedDate.year == _month.year &&
              e.expectedDate.month == _month.month,
        )
        .toList();
  }

  void _moveMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selectedDay = null;
    });
  }

  String _relative(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(day.year, day.month, day.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff > 1 && diff < 7) return 'In $diff days';
    if (diff < 0 && diff > -7) return '${-diff} days ago';
    return DateFormat.MMMd().format(day);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final events = {
      for (final e in _byDay.entries) e.key: e.value.length,
    };

    return ScreenBackdrop(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_rounded, color: c.textPrimary),
                  ),
                  Expanded(
                    child: Text(
                      'Release calendar',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'How estimates work',
                    onPressed: () => _showInfo(context),
                    icon: Icon(
                      Icons.help_outline_rounded,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => _moveMonth(-1),
                      icon: Icon(
                        Icons.chevron_left_rounded,
                        color: c.textPrimary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        DateFormat.yMMMM().format(_month),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _moveMonth(1),
                      icon: Icon(
                        Icons.chevron_right_rounded,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _WeekdayRow(color: c.textTertiary),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _MonthGrid(
                  month: _month,
                  events: events,
                  selectedDay: _selectedDay,
                  onDaySelected: (day) => setState(() => _selectedDay = day),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  _selectedDay == null
                      ? '${_monthItems.length} estimated this month'
                      : '${_relative(_selectedDay!)} · ${_selectedItems.length} title${_selectedItems.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: _selectedDay == null
                    ? _ReleaseList(
                        items: _monthItems,
                        emptyTitle: 'No estimates this month',
                        emptySubtitle:
                            'Need a few chapter dates to guess the next drop.',
                      )
                    : _ReleaseList(
                        items: _selectedItems,
                        emptyTitle: 'Nothing expected',
                        emptySubtitle: 'Pick another day with a mark.',
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showInfo(BuildContext context) {
    final c = context.colors;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(
          'Release estimates',
          style: TextStyle(color: c.textPrimary),
        ),
        content: Text(
          'Koma looks at recent chapter upload dates, takes the median gap, '
          'and projects the next release. It is a local guess — not a schedule '
          'from the source.',
          style: TextStyle(color: c.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Got it', style: TextStyle(color: c.accent)),
          ),
        ],
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: [
        for (final l in labels)
          Expanded(
            child: Text(
              l,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.events,
    required this.selectedDay,
    required this.onDaySelected,
  });

  final DateTime month;
  final Map<DateTime, int> events;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final firstWeekday = month.weekday - 1;
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    final cells = <Widget>[
      for (var i = 0; i < firstWeekday; i++) const SizedBox.shrink(),
      for (var day = 1; day <= lastDay; day++)
        Builder(
          builder: (context) {
            final date = DateTime(month.year, month.month, day);
            final count = events[date] ?? 0;
            final selected = selectedDay == date;
            final isToday = date == todayKey;
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onDaySelected(date),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: selected
                      ? c.accent.withValues(alpha: 0.22)
                      : count > 0
                      ? c.surfaceMuted
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? c.accent
                        : isToday
                        ? c.accent.withValues(alpha: 0.55)
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (count > 0)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: c.accent,
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(height: 6),
                  ],
                ),
              ),
            );
          },
        ),
    ];

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 0.95,
      children: cells,
    );
  }
}

class _ReleaseList extends ConsumerWidget {
  const _ReleaseList({
    required this.items,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  final List<UpcomingRelease> items;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    if (items.isEmpty) {
      return EmptyState(
        icon: AppIcons.calendar,
        emoji: '📅',
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = items[i];
        final m = item.manga;
        return Material(
          color: c.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.pushNamed(
              Routes.mangaDetail,
              extra: (
                sourceId: m.sourceId,
                url: m.url,
                title: m.name,
                manga: m,
                memo: m.memo,
              ) as MangaDetailArgs,
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 62,
                      child: _Cover(manga: m),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Usually every ${item.intervalDays} day'
                          '${item.intervalDays == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: c.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.textTertiary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Cover extends ConsumerWidget {
  const _Cover({required this.manga});

  final Manga manga;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final headers =
        ref.watch(sourceImageHeadersProvider(manga.sourceId)).value;
    final custom = manga.customCoverPath;
    if (custom != null && custom.isNotEmpty && File(custom).existsSync()) {
      return Image.file(File(custom), fit: BoxFit.cover);
    }
    final url = manga.imageUrl;
    if (url != null && url.isNotEmpty) {
      return Image(
        image: cachedCover(url, headers: headers),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => ColoredBox(color: c.iconWell),
      );
    }
    return ColoredBox(color: c.iconWell);
  }
}

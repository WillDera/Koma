import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/manga.dart';
import '../../core/providers.dart';
import '../../core/utils/image_cache.dart';
import '../../core/utils/image_headers.dart';
import '../../router/router.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_button_round.dart';
import '../../widgets/one_hand_spacer.dart';
import '../../widgets/screen_chrome.dart';
import 'updates_calendar_screen.dart';

/// Kenji-style “Your Updates” feed — unopened library chapters + refresh.
class UpdatesScreen extends ConsumerWidget {
  const UpdatesScreen({super.key});

  String _relativeDay(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(when.year, when.month, when.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return DateFormat.MMMd().format(when);
  }

  String _lastUpdatedLabel(DateTime? when) {
    if (when == null) return 'Never';
    return _relativeDay(when);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final library = ref.watch(libraryProvider);
    final update = ref.watch(libraryUpdateProvider);
    final mangasById = {for (final m in library.mangas) m.id: m};

    final entries = <({Manga manga, int count})>[];
    for (final e in library.newChapters.entries) {
      if (e.value <= 0) continue;
      final m = mangasById[e.key];
      if (m == null) continue;
      entries.add((manga: m, count: e.value));
    }
    entries.sort((a, b) => b.manga.updatedAt.compareTo(a.manga.updatedAt));

    final grouped = <String, List<({Manga manga, int count})>>{};
    for (final e in entries) {
      final label = _relativeDay(e.manga.updatedAt);
      grouped.putIfAbsent(label, () => []).add(e);
    }

    return ScreenBackdrop(
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: c.accent,
          backgroundColor: c.surface,
          onRefresh: () async {
            await ref
                .read(libraryUpdateProvider.notifier)
                .checkForNewChapters(applyRestrictions: false);
            await ref.read(libraryProvider.notifier).loadBooks();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: OneHandSpacer()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Your Updates',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButtonRound(
                        icon: Icons.calendar_month_outlined,
                        tooltip: 'Release calendar',
                        onPressed: () => UpdatesCalendarScreen.open(context),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: c.surfaceMuted,
                        borderRadius: BorderRadius.circular(64),
                        child: InkWell(
                          onTap: update.checking
                              ? null
                              : () => ref
                                    .read(libraryUpdateProvider.notifier)
                                    .checkForNewChapters(
                                      applyRestrictions: false,
                                    ),
                          borderRadius: BorderRadius.circular(64),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                if (update.checking)
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: c.textPrimary,
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.refresh_rounded,
                                    size: 22,
                                    color: c.textPrimary,
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  'Refresh',
                                  style: TextStyle(
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE6ED),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: c.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Last Updated: ${_lastUpdatedLabel(update.lastCheckedAt)}',
                            style: const TextStyle(
                              color: Color(0xFF19191C),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (entries.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: AppIcons.bell,
                    emoji: '🔔',
                    title: 'No new chapters',
                    subtitle:
                        'Pull to refresh or tap Refresh to check your library manga for updates.',
                  ),
                )
              else
                for (final section in grouped.entries) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                      child: Text(
                        section.key,
                        style: TextStyle(
                          color: c.textTertiary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final row = section.value[i];
                      return StaggeredFadeScale(
                        index: i,
                        child: _UpdateRow(
                          manga: row.manga,
                          newCount: row.count,
                        ),
                      );
                    }, childCount: section.value.length),
                  ),
                ],
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpdateRow extends ConsumerWidget {
  const _UpdateRow({
    required this.manga,
    required this.newCount,
  });

  final Manga manga;
  final int newCount;

  void _open(BuildContext context) {
    context.pushNamed(
      Routes.mangaDetail,
      extra: (
        sourceId: manga.sourceId,
        url: manga.url,
        title: manga.name,
        manga: manga,
        memo: manga.memo,
      ) as MangaDetailArgs,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final headers = ref.watch(sourceImageHeadersProvider(manga.sourceId)).value;
    final custom = manga.customCoverPath;
    return InkWell(
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 58,
                height: 72,
                child: custom != null &&
                        custom.isNotEmpty &&
                        File(custom).existsSync()
                    ? Image.file(File(custom), fit: BoxFit.cover)
                    : manga.imageUrl != null && manga.imageUrl!.isNotEmpty
                    ? Image(
                        image: cachedCover(manga.imageUrl!, headers: headers),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            ColoredBox(color: c.iconWell),
                      )
                    : ColoredBox(color: c.iconWell),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    manga.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 22 / 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    newCount == 1
                        ? '1 new chapter'
                        : '$newCount new chapters',
                    style: TextStyle(color: c.textTertiary, fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButtonRound(
              icon: Icons.download_outlined,
              size: 40,
              variant: IconButtonVariant.tonal,
              onPressed: () => _open(context),
            ),
          ],
        ),
      ),
    );
  }
}

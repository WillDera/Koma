import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../core/models/book.dart';
import '../../core/models/chapter.dart';
import '../../router/book_navigation.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../theme/tokens/app_type.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/screen_chrome.dart';
import 'book_detail_providers.dart';

class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final int bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(bookDetailStreamProvider(bookId));
    final chapters = ref.watch(bookChaptersStreamProvider(bookId));
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        title: const Text('Book details'),
      ),
      body: ScreenBackdrop(
        child: book.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _MessageState(
            icon: Icons.error_outline_rounded,
            title: 'Couldn’t load this book',
            message: '$error',
          ),
          data: (value) {
            if (value == null) {
              return const _MessageState(
                icon: Icons.menu_book_outlined,
                title: 'Book unavailable',
                message: 'This book is no longer in your library.',
              );
            }
            return chapters.when(
              loading: () => _DetailBody(
                book: value,
                chapters: const [],
                chaptersLoading: true,
              ),
              error: (error, _) => _DetailBody(
                book: value,
                chapters: const [],
                chapterError: '$error',
              ),
              data: (rows) => _DetailBody(book: value, chapters: rows),
            );
          },
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.book,
    required this.chapters,
    this.chaptersLoading = false,
    this.chapterError,
  });

  final Book book;
  final List<Chapter> chapters;
  final bool chaptersLoading;
  final String? chapterError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final theme = ref.watch(themeProvider);
    final chapterId = savedChapterId(chapters, book.currentChapterIndex);
    final progress = book.progress.clamp(0.0, 1.0);
    final currentPosition = chapters.isEmpty
        ? 'No saved chapter'
        : 'Chapter ${book.currentChapterIndex.clamp(0, chapters.length - 1) + 1} of ${chapters.length}';

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 132,
                      child: Hero(
                        tag: 'book-cover-${book.id}',
                        child: BookCover(
                          book: book,
                          variant: BookCoverVariant.hero,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: c.textPrimary,
                                  fontFamily: theme.useDeviceFont
                                      ? null
                                      : (theme.readingFontFamily ??
                                          AppType.readingFont),
                                  height: 1.15,
                                ),
                          ),
                          if (book.author?.trim().isNotEmpty == true) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              book.author!.trim(),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: c.textSecondary),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            currentPosition,
                            style: AppType.labelCaps(color: c.textTertiary),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: ThinProgressBar(
                                  progress: progress,
                                  height: 5,
                                  color: c.accent,
                                  trackColor: c.border,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                '${(progress * 100).round()}%',
                                style: AppType.mono(
                                  fontSize: 11,
                                  color: c.accent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                PremiumButton(
                  label: book.progress > 0 ? 'Continue reading' : 'Read',
                  leading: const Icon(Icons.menu_book_rounded),
                  size: PremiumButtonSize.lg,
                  expand: true,
                  onPressed: () => openBookReader(
                    context,
                    bookId: book.id,
                    chapterId: chapterId,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                _MetadataPanel(book: book),
                const SizedBox(height: AppSpacing.xxxl),
                Row(
                  children: [
                    Text(
                      'Chapters',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: c.textPrimary),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: c.surfaceMuted,
                        borderRadius: AppSpacing.brPill,
                      ),
                      child: Text(
                        '${chapters.length}',
                        style: AppType.mono(
                          fontSize: 11,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
        if (chaptersLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (chapterError != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text(
                'Chapter list unavailable: $chapterError',
                style: TextStyle(color: c.textSecondary),
              ),
            ),
          )
        else if (chapters.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Container(
                padding: AppSpacing.cardLg,
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: AppSpacing.brLg,
                  border: Border.all(color: c.border, width: 0.5),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.library_books_outlined,
                      color: c.textTertiary,
                      size: 28,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'No saved chapters',
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: c.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'You can still open the reader for this book.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            sliver: SliverList.builder(
              itemCount: chapters.length,
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ChapterRow(
                    chapter: chapter,
                    displayIndex: chapter.index >= 0
                        ? chapter.index + 1
                        : index + 1,
                    current:
                        index ==
                        book.currentChapterIndex.clamp(0, chapters.length - 1),
                    onTap: () => openBookReader(
                      context,
                      bookId: book.id,
                      chapterId: chapter.id,
                    ),
                  ),
                );
              },
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxxl)),
      ],
    );
  }
}

class _MetadataPanel extends StatelessWidget {
  const _MetadataPanel({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = <(IconData, String, String)>[
      if (book.genre.trim().isNotEmpty)
        (Icons.sell_outlined, 'Genre', book.genre.trim()),
      if (book.releaseDate != null)
        (
          Icons.calendar_today_outlined,
          'Released',
          DateFormat.yMMMd().format(book.releaseDate!),
        ),
      if (book.source.trim().isNotEmpty)
        (Icons.source_outlined, 'Source', _sourceLabel(book)),
      if (book.fileExtension.trim().isNotEmpty)
        (
          Icons.description_outlined,
          'Format',
          book.fileExtension.replaceFirst('.', '').toUpperCase(),
        ),
      if (book.filePath?.trim().isNotEmpty == true)
        (Icons.folder_outlined, 'File', p.basename(book.filePath!.trim())),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: AppSpacing.cardLg,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppSpacing.brLg,
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _MetadataRow(
              icon: rows[i].$1,
              label: rows[i].$2,
              value: rows[i].$3,
            ),
            if (i != rows.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Divider(height: 1, color: c.border),
              ),
          ],
        ],
      ),
    );
  }

  String _sourceLabel(Book book) {
    final url = book.sourceUrl?.trim();
    if (url != null && url.isNotEmpty) {
      final host = Uri.tryParse(url)?.host;
      if (host != null && host.isNotEmpty) return host;
    }
    return switch (book.source.toLowerCase()) {
      'web' => 'Web',
      'manual' => 'Note',
      'local' => 'Local file',
      _ => book.source,
    };
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: c.textTertiary),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: AppType.labelCaps(fontSize: 10, color: c.textTertiary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppType.mono(fontSize: 11, color: c.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.chapter,
    required this.displayIndex,
    required this.current,
    required this.onTap,
  });

  final Chapter chapter;
  final int displayIndex;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasPosition =
        (chapter.readingCharOffset ?? 0) > 0 || chapter.scrollPosition > 0;
    final status = [
      if (current) 'Current',
      if (chapter.readAt != null) 'Read',
      if (hasPosition && chapter.readAt == null) 'In progress',
      if ((chapter.readingCharOffset ?? 0) > 0)
        'Position ${chapter.readingCharOffset}',
      if (chapter.readingCharOffset == null && chapter.scrollPosition > 0)
        'Saved position',
    ].join(' · ');

    return Semantics(
      button: true,
      label: 'Open chapter $displayIndex, ${chapter.title}',
      child: AnimatedPress(
        onTap: onTap,
        scaleDown: 0.985,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: current ? c.accentMuted : c.surface,
            borderRadius: AppSpacing.brMd,
            border: Border.all(
              color: current ? c.accent.withValues(alpha: 0.5) : c.border,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: current ? c.accent : c.surfaceMuted,
                  borderRadius: AppSpacing.brSm,
                ),
                child: Text(
                  '$displayIndex',
                  style: AppType.mono(
                    fontSize: 11,
                    color: current ? c.onAccent : c.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.title.trim().isEmpty
                          ? 'Chapter $displayIndex'
                          : chapter.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: c.textPrimary),
                    ),
                    if (status.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        status,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: current ? c.accent : c.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                chapter.readAt != null
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                size: 20,
                color: chapter.readAt != null ? c.accent : c.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: AppSpacing.cardLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: c.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

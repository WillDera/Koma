import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/novel_html_content_service.dart';
import '../../core/services/security_prefs.dart';
import '../../core/services/trackers/track_chapter_use_case.dart';
import '../../core/services/trackers/track_sync_feedback.dart';
import '../../core/utils/text_extractor.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/toast.dart';
import '../../theme/app_icons.dart';

/// HTML novel chapter reader — reuses ebook text extraction, manga progress.
class NovelReaderScreen extends ConsumerStatefulWidget {
  final int? mangaId;
  final String sourceId;
  final String mangaUrl;
  final String mangaName;
  final String chapterUrl;
  final String chapterName;

  const NovelReaderScreen({
    super.key,
    this.mangaId,
    required this.sourceId,
    required this.mangaUrl,
    required this.mangaName,
    required this.chapterUrl,
    required this.chapterName,
  });

  @override
  ConsumerState<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends ConsumerState<NovelReaderScreen> {
  String? _html;
  String? _error;
  bool _loading = true;
  bool _chromeVisible = true;
  final _scroll = ScrollController();
  int? _chapterDbId;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceNetwork = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repos = ref.read(repositoriesProvider);
      final dispatch = ref.read(extensionServiceProvider);
      final mangaId = widget.mangaId ?? 0;
      if (widget.mangaId != null) {
        final existing = await repos.manga.getMangaChapterByUrl(
          widget.mangaId!,
          widget.chapterUrl,
        );
        _chapterDbId = existing?.id;
        if (existing != null) {
          await repos.manga.markMangaChapterOpened(existing.id);
        }
      }
      final html = await NovelHtmlContentService(
        repos: repos,
        dispatch: dispatch,
      ).load(
        sourceId: widget.sourceId,
        mangaId: mangaId,
        mangaName: widget.mangaName,
        chapterUrl: widget.chapterUrl,
        forceNetwork: forceNetwork,
      );
      if (!mounted) return;
      setState(() {
        _html = html;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _markReadAndSync() async {
    final mangaId = widget.mangaId;
    final chapterId = _chapterDbId;
    if (mangaId == null || chapterId == null) return;
    if (await SecurityPrefs.isIncognito()) return;
    final repos = ref.read(repositoriesProvider);
    await repos.manga.markMangaChapterRead(chapterId);
    final outcome = await TrackChapterUseCase(repos).invoke(
      mangaId: mangaId,
      chapterName: widget.chapterName,
    );
    if (!mounted) return;
    if (outcome != null && outcome.didAnything) {
      ref.read(latestTrackSyncProvider.notifier).setOutcome(outcome);
      final fail = outcome.failureToast;
      if (fail != null) {
        StashToast.show(context, message: fail, icon: Icons.error_outline);
      }
    }
  }

  void _onScrollEnd() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 120) {
      unawaited(_markReadAndSync());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = ref.watch(themeProvider);
    final fontSize = theme.fontSize.clamp(14.0, 28.0);

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (_error != null)
            Center(
              child: EmptyState(
                icon: AppIcons.cloudLoading,
                title: 'Couldn’t load chapter',
                subtitle: _error,
                primaryActionLabel: 'Retry',
                onPrimaryAction: () => _load(forceNetwork: true),
                pillPrimary: true,
              ),
            )
          else
            NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollEndNotification) _onScrollEnd();
                return false;
              },
              child: GestureDetector(
                onTap: () => setState(() => _chromeVisible = !_chromeVisible),
                child: CustomScrollView(
                  controller: _scroll,
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        MediaQuery.paddingOf(context).top + 72,
                        20,
                        MediaQuery.paddingOf(context).bottom + 48,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _NovelBody(
                          html: _html!,
                          chapterId: _chapterDbId ?? widget.chapterUrl.hashCode,
                          fontSize: fontSize,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          AnimatedOpacity(
            opacity: _chromeVisible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: IgnorePointer(
              ignoring: !_chromeVisible,
              child: SafeArea(
                child: Material(
                  color: c.bg.withValues(alpha: 0.92),
                  child: SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.chapterName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                widget.mangaName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Reload',
                          icon: const Icon(Icons.refresh),
                          onPressed: () => _load(forceNetwork: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NovelBody extends StatelessWidget {
  const _NovelBody({
    required this.html,
    required this.chapterId,
    required this.fontSize,
    required this.color,
  });

  final String html;
  final int chapterId;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = TextExtractor.extractCached(chapterId, html);
    final paragraphs = text
        .split(RegExp(r'\n+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (paragraphs.isEmpty) {
      return Text(
        'This chapter has no text.',
        style: TextStyle(color: color.withValues(alpha: 0.6)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in paragraphs) ...[
          Text(
            p,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              height: 1.55,
              letterSpacing: 0.1,
            ),
          ),
          SizedBox(height: fontSize * 0.85),
        ],
        const SizedBox(height: 48),
        Text(
          'End of chapter',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color.withValues(alpha: 0.45),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

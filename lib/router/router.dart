import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app.dart' show routeObserver;
import '../core/models/manga.dart';
import '../features/discover/discover_screen.dart';
import '../features/downloads/download_queue_screen.dart';
import '../features/extensions/extensions_screen.dart';
import '../features/extensions/manga_detail_screen.dart';
import '../features/extensions/sources_screen.dart';
import '../features/history/history_screen.dart';
import '../features/library/library_screen.dart';
import '../features/reader/manga_reader_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/snippets/snippets_screen.dart';
import 'shell.dart';

/// Route name constants — use these with `context.pushNamed` / `context.goNamed`
/// so call sites don't hardcode path strings.
abstract final class Routes {
  // Shell tabs
  static const library = 'library';
  static const history = 'history';
  static const snippets = 'snippets';
  static const discover = 'discover';
  static const search = 'search';
  static const settings = 'settings';

  // Detail (pushed above the shell)
  static const reader = 'reader';
  static const mangaReader = 'mangaReader';
  static const mangaDetail = 'mangaDetail';
  static const extensions = 'extensions';
  static const sources = 'sources';
  static const downloadQueue = 'downloadQueue';
}

// ── Typed argument records for detail routes ─────────────────────────
// go_router passes these via `state.extra`. We keep them as records so
// call sites stay type-checked at the push site.
//
// Note: ExtensionDetailScreen and SourceBrowseScreen are NOT registered
// here — they carry callbacks (onUninstall) and are only ever pushed
// from within other detail screens, so they stay on plain Navigator.push
// (already above the shell). Only tab-reachable / root-level destinations
// need go_router entries.

// Snippet jumps carry the stored character offsets, not a pixel scroll
// position: pixels are invalid the moment font size, width or reading mode
// changes, and mean nothing at all in paginated mode. snippetScrollOffset is
// kept as a last-resort fallback for older snippets saved before offsets were
// recorded.
typedef ReaderArgs = ({
  int bookId,
  int? snippetChapterId,
  double? snippetScrollOffset,
  int? snippetStartOffset,
  int? snippetEndOffset,
});

typedef MangaReaderArgs = ({
  int? mangaId,
  String sourceId,
  String mangaUrl,
  String chapterUrl,
  String chapterName,
  int? pageNumber,
});

typedef MangaDetailArgs = ({
  String sourceId,
  String url,
  String title,
  Manga? manga,
  String? memo,
});

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// The app's GoRouter. Bottom-nav tabs live in a
/// [StatefulShellRoute.indexedStack] so each tab keeps its own Navigator
/// and widget state across switches — the go_router equivalent of the
/// old custom Stack+IgnorePointer shell in app.dart, but with real
/// per-branch navigation history. Detail screens are top-level routes
/// pushed above the shell (covering the bottom nav).
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  observers: [routeObserver],
  initialLocation: '/library',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/library',
              name: Routes.library,
              builder: (context, state) => const LibraryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/history',
              name: Routes.history,
              builder: (context, state) => const HistoryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/snippets',
              name: Routes.snippets,
              builder: (context, state) => const SnippetsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/discover',
              name: Routes.discover,
              builder: (context, state) => const DiscoverScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              name: Routes.search,
              builder: (context, state) => const SearchScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              name: Routes.settings,
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),

    // ── Detail routes (above the shell) ──────────────────────────────
    GoRoute(
      path: '/reader',
      name: Routes.reader,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final a = state.extra as ReaderArgs;
        return ReaderScreen(
          bookId: a.bookId,
          snippetChapterId: a.snippetChapterId,
          snippetScrollOffset: a.snippetScrollOffset,
          snippetStartOffset: a.snippetStartOffset,
          snippetEndOffset: a.snippetEndOffset,
        );
      },
    ),
    GoRoute(
      path: '/manga-reader',
      name: Routes.mangaReader,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra;
        int? mangaId;
        String sourceId = '';
        String mangaUrl = '';
        String chapterUrl = '';
        String chapterName = '';
        int? pageNumber;

        if (extra is Map) {
          mangaId = extra['mangaId'] as int?;
          sourceId = extra['sourceId'] as String? ?? '';
          mangaUrl = extra['mangaUrl'] as String? ?? '';
          chapterUrl = extra['chapterUrl'] as String? ?? '';
          chapterName = extra['chapterName'] as String? ?? '';
          pageNumber = extra['pageNumber'] as int?;
        } else if (extra is MangaReaderArgs) {
          // Named record — the canonical form pushed by all reader entry
          // points (manga detail, snippets bookmarks, chapter navigation).
          // The previous positional-record `is` checks never matched a named
          // record, so every field fell through to its empty default and the
          // Dalvik server received sourceId='' → "Source not loaded: ".
          mangaId = extra.mangaId;
          sourceId = extra.sourceId;
          mangaUrl = extra.mangaUrl;
          chapterUrl = extra.chapterUrl;
          chapterName = extra.chapterName;
          pageNumber = extra.pageNumber;
        }

        return MangaReaderScreen(
          mangaId: mangaId,
          sourceId: sourceId,
          mangaUrl: mangaUrl,
          chapterUrl: chapterUrl,
          chapterName: chapterName,
          pageNumber: pageNumber,
        );
      },
    ),
    GoRoute(
      path: '/manga-detail',
      name: Routes.mangaDetail,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final a = state.extra as MangaDetailArgs;
        return MangaDetailScreen(
          sourceId: a.sourceId,
          url: a.url,
          title: a.title,
          manga: a.manga,
          memo: a.memo ?? a.manga?.memo,
        );
      },
    ),
    GoRoute(
      path: '/extensions',
      name: Routes.extensions,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const ExtensionsScreen(),
    ),
    GoRoute(
      path: '/sources',
      name: Routes.sources,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const SourcesScreen(),
    ),
    GoRoute(
      path: '/download-queue',
      name: Routes.downloadQueue,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const DownloadQueueScreen(),
    ),
  ],
);

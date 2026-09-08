import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app.dart' show routeObserver;
import '../core/models/manga.dart';
import '../features/discover/discover_screen.dart';
import '../features/downloads/download_queue_screen.dart';
import '../features/extensions/extensions_screen.dart';
import '../features/extensions/global_search_screen.dart';
import '../features/extensions/manga_detail_screen.dart';
import '../features/extensions/migrate_batch_screen.dart';
import '../features/extensions/sources_screen.dart';
import '../features/history/history_screen.dart';
import '../features/library/book_detail_screen.dart';
import '../features/library/collections_screen.dart';
import '../features/library/library_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/reader/manga_reader_screen.dart';
import '../features/reader/pdf_reader_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/snippets/snippets_screen.dart';
import '../features/updates/updates_screen.dart';
import '../core/services/user_profile.dart';
import 'shell.dart';

/// Route name constants — use these with `context.pushNamed` / `context.goNamed`
/// so call sites don't hardcode path strings.
abstract final class Routes {
  // Shell tabs (Kenji order: Library, Updates, History, Explore, You)
  static const library = 'library';
  static const updates = 'updates';
  static const history = 'history';
  static const discover = 'discover';
  static const settings = 'settings';
  static const onboarding = 'onboarding';

  // Detail (pushed above the shell)
  static const snippets = 'snippets';
  static const collections = 'collections';
  static const search = 'search';
  static const reader = 'reader';
  static const bookDetail = 'bookDetail';
  static const mangaReader = 'mangaReader';
  static const mangaDetail = 'mangaDetail';
  static const extensions = 'extensions';
  static const sources = 'sources';
  static const downloadQueue = 'downloadQueue';
  static const globalSearch = 'globalSearch';
  static const pdfReader = 'pdfReader';
  static const migrateBatch = 'migrateBatch';
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

typedef BookDetailArgs = ({int bookId});

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

typedef PdfReaderArgs = ({int bookId, int? initialPage});

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Sync gate for [appRouter] redirect — kept in sync by [UserProfileNotifier].
bool _onboardingGateCompleted() {
  // Prefer the live Riverpod state when available via listenable bumps;
  // SharedPreferences may not be re-read every redirect.
  return UserProfileNotifier.peekOnboardingCompleted;
}

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
  refreshListenable: userProfileListenable,
  redirect: (context, state) {
    final onOnboarding = state.matchedLocation == '/onboarding';
    final done = _onboardingGateCompleted();
    if (!done && !onOnboarding) return '/onboarding';
    if (done && onOnboarding) return '/library';
    return null;
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      name: Routes.onboarding,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const OnboardingScreen(),
    ),
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
              path: '/updates',
              name: Routes.updates,
              builder: (context, state) => const UpdatesScreen(),
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
              path: '/discover',
              name: Routes.discover,
              builder: (context, state) => const DiscoverScreen(),
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
      path: '/snippets',
      name: Routes.snippets,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const SnippetsScreen(),
    ),
    GoRoute(
      path: '/collections',
      name: Routes.collections,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const CollectionsScreen(),
    ),
    // Library-wide search is pushed from the Library header (not a tab).
    GoRoute(
      path: '/search',
      name: Routes.search,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const SearchScreen(),
    ),
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
      path: '/book-detail',
      name: Routes.bookDetail,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final a = state.extra as BookDetailArgs;
        return BookDetailScreen(bookId: a.bookId);
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
      builder: (context, state) {
        final extra = state.extra;
        var tab = 0;
        if (extra is int) {
          tab = extra;
        } else if (extra is Map && extra['tab'] is int) {
          tab = extra['tab'] as int;
        }
        return ExtensionsScreen(initialTabIndex: tab);
      },
    ),
    GoRoute(
      path: '/sources',
      name: Routes.sources,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const SourcesScreen(),
    ),
    GoRoute(
      path: '/global-search',
      name: Routes.globalSearch,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final fromExtra = state.extra is String ? state.extra as String : null;
        final fromQuery = state.uri.queryParameters['q'];
        return GlobalSearchScreen(initialQuery: fromExtra ?? fromQuery);
      },
    ),
    GoRoute(
      path: '/pdf-reader',
      name: Routes.pdfReader,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final args = state.extra as PdfReaderArgs?;
        final bookId = args?.bookId ?? 0;
        return PdfReaderScreen(
          bookId: bookId,
          initialPage: args?.initialPage,
        );
      },
    ),
    GoRoute(
      path: '/migrate-batch',
      name: Routes.migrateBatch,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const MigrateBatchScreen(),
    ),
    GoRoute(
      path: '/download-queue',
      name: Routes.downloadQueue,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const DownloadQueueScreen(),
    ),
  ],
);

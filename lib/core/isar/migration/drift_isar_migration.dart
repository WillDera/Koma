import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/database_service.dart';
import '../collections/book.dart' as i;
import '../collections/chapter.dart' as i;
import '../collections/extension_repo.dart' as i;
import '../collections/extension_source.dart' as i;
import '../collections/highlight.dart' as i;
import '../collections/manga.dart' as i;
import '../collections/manga_chapter.dart' as i;
import '../collections/reading_stat.dart' as i;
import '../collections/snippet.dart' as i;
import '../collections/snippet_collection.dart' as i;
import '../collections/source.dart' as i;
import '../collections/tag.dart' as i;
import '../collections/web_cache.dart' as i;
import '../isar.dart';
import 'migration_report.dart';

/// SharedPreferences key that gates the one-time Drift→Isar migration.
/// Once set to `true`, subsequent launches skip the migration entirely.
const kIsarMigratedFlag = 'isar_migrated_v1';

/// One-time migration of all data from the existing Drift SQLite DB to
/// the new Isar instance. Runs on first launch after the user upgrades
/// to a build that includes Isar. Idempotent (Isar `put` with an explicit
/// ID is an upsert). Gated by [kIsarMigratedFlag].
///
/// Tables are migrated in FK dependency order (parents before children)
/// so that child rows can reference parent IDs correctly. IDs from Drift
/// are preserved verbatim on Isar collections so all existing FK
/// references (bookId, mangaId, etc.) still resolve.
///
/// Usage (called from main.dart before runApp):
/// ```dart
/// final report = await migrateDriftToIsar(dbService);
/// if (report.error != null) { /* log */ }
/// ```
Future<MigrationReport> migrateDriftToIsar(
  DatabaseService dbService, {
  Isar? isar,
  SharedPreferences? prefs,
}) async {
  final start = DateTime.now();
  final sp = prefs ?? await SharedPreferences.getInstance();

  if (sp.getBool(kIsarMigratedFlag) == true) {
    return MigrationReport(
      skipped: true,
      elapsed: DateTime.now().difference(start),
    );
  }

  try {
    final db = dbService.db;
    final isarInstance = isar ?? await openIsar();

    final sourceCounts = <String, int>{};
    final targetCounts = <String, int>{};

    // ── Books ──────────────────────────────────────────────────────
    final bookRows = await db.customSelect('SELECT * FROM books').get();
    sourceCounts['books'] = bookRows.length;
    final books = bookRows.map((r) {
      final d = r.data;
      return i.Book(
        id: d['id'] as int,
        title: d['title'] as String,
        author: d['author'] as String?,
        coverPath: d['cover_path'] as String?,
        source: d['source'] as String? ?? 'local',
        sourceUrl: d['source_url'] as String?,
        filePath: d['file_path'] as String?,
        progress: (d['progress'] as num?)?.toDouble() ?? 0.0,
        currentChapterIndex: d['current_chapter_index'] as int? ?? 0,
        totalChapters: d['total_chapters'] as int? ?? 0,
        scrollPosition: (d['scroll_position'] as num?)?.toDouble() ?? 0.0,
        genre: d['genre'] as String? ?? '',
        fileExtension: d['file_extension'] as String? ?? '',
        createdAt: d['created_at'] != null
            ? DateTime.parse(d['created_at'] as String)
            : null,
        updatedAt: d['updated_at'] != null
            ? DateTime.parse(d['updated_at'] as String)
            : null,
      );
    }).toList();
    await isarInstance.writeTxn(() => isarInstance.books.putAll(books));
    targetCounts['books'] = books.length;

    // ── Chapters ───────────────────────────────────────────────────
    final chapterRows = await db.customSelect('SELECT * FROM chapters').get();
    sourceCounts['chapters'] = chapterRows.length;
    final chapters = chapterRows.map((r) {
      final d = r.data;
      return i.Chapter(
        id: d['id'] as int,
        bookId: d['book_id'] as int,
        title: d['title'] as String,
        content: d['content'] as String? ?? '',
        index: d['index'] as int,
        readAt: d['read_at'] != null
            ? DateTime.parse(d['read_at'] as String)
            : null,
        scrollPosition:
            (d['scroll_position'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
    await isarInstance.writeTxn(() => isarInstance.chapters.putAll(chapters));
    targetCounts['chapters'] = chapters.length;

    // ── SnippetCollections ─────────────────────────────────────────
    final collRows =
        await db.customSelect('SELECT * FROM snippet_collections').get();
    sourceCounts['snippet_collections'] = collRows.length;
    final colls = collRows.map((r) {
      final d = r.data;
      return i.SnippetCollection(
        id: d['id'] as int,
        name: d['name'] as String,
        color: d['color'] as String? ?? '#FFD700',
        createdAt: d['created_at'] != null
            ? DateTime.parse(d['created_at'] as String)
            : null,
        updatedAt: d['updated_at'] != null
            ? DateTime.parse(d['updated_at'] as String)
            : null,
      );
    }).toList();
    await isarInstance.writeTxn(
        () => isarInstance.snippetCollections.putAll(colls));
    targetCounts['snippet_collections'] = colls.length;

    // ── Tags + SnippetTags junction (denormalized into Snippet.tags) ──
    //
    // 1. Read all tags → Tag collection (preserve IDs).
    // 2. Read all snippet_tags junction rows → build snippetId→tagNames map.
    // 3. When migrating snippets, set .tags from this map.
    final tagRows = await db.customSelect('SELECT * FROM tags').get();
    sourceCounts['tags'] = tagRows.length;
    final tags = tagRows.map((r) {
      final d = r.data;
      return i.Tag(id: d['id'] as int, name: d['name'] as String);
    }).toList();
    await isarInstance.writeTxn(() => isarInstance.tags.putAll(tags));
    targetCounts['tags'] = tags.length;

    // Build the snippetId → tagNames lookup from the junction table.
    final junctionRows = await db
        .customSelect(
          'SELECT st.snippet_id, t.name FROM snippet_tags st '
          'INNER JOIN tags t ON st.tag_id = t.id',
        )
        .get();
    final snippetTags = <int, List<String>>{};
    for (final r in junctionRows) {
      final sid = r.data['snippet_id'] as int;
      final name = r.data['name'] as String;
      snippetTags.putIfAbsent(sid, () => []).add(name);
    }

    // ── Snippets ───────────────────────────────────────────────────
    final snippetRows = await db.customSelect('SELECT * FROM snippets').get();
    sourceCounts['snippets'] = snippetRows.length;
    final snippets = snippetRows.map((r) {
      final d = r.data;
      final sid = d['id'] as int;
      return i.Snippet(
        id: sid,
        text: d['content'] as String, // Drift column is `content`
        note: d['note'] as String?,
        sourceTitle: d['source_title'] as String?,
        sourceUrl: d['source_url'] as String?,
        color: d['color'] as String?,
        bookId: d['book_id'] as int?,
        chapterId: d['chapter_id'] as int?,
        collectionId: d['collection_id'] as int?,
        startOffset: d['start_offset'] as int?,
        endOffset: d['end_offset'] as int?,
        scrollPosition: (d['scroll_position'] as num?)?.toDouble(),
        tags: snippetTags[sid] ?? const [],
        createdAt: d['created_at'] != null
            ? DateTime.parse(d['created_at'] as String)
            : null,
        updatedAt: d['updated_at'] != null
            ? DateTime.parse(d['updated_at'] as String)
            : null,
      );
    }).toList();
    await isarInstance.writeTxn(
        () => isarInstance.snippets.putAll(snippets));
    targetCounts['snippets'] = snippets.length;

    // ── Highlights ──────────────────────────────────────────────────
    final hlRows = await db.customSelect('SELECT * FROM highlights').get();
    sourceCounts['highlights'] = hlRows.length;
    final hls = hlRows.map((r) {
      final d = r.data;
      return i.Highlight(
        id: d['id'] as int,
        snippetId: d['snippet_id'] as int?,
        bookId: d['book_id'] as int,
        chapterId: d['chapter_id'] as int,
        startOffset: d['start_offset'] as int,
        endOffset: d['end_offset'] as int,
        color: d['color'] as String? ?? 'yellow',
        text: d['text'] as String,
        createdAt: d['created_at'] != null
            ? DateTime.parse(d['created_at'] as String)
            : null,
        updatedAt: d['updated_at'] != null
            ? DateTime.parse(d['updated_at'] as String)
            : null,
      );
    }).toList();
    await isarInstance.writeTxn(() => isarInstance.highlights.putAll(hls));
    targetCounts['highlights'] = hls.length;

    // ── ReadingStats ────────────────────────────────────────────────
    final statRows = await db.customSelect('SELECT * FROM reading_stats').get();
    sourceCounts['reading_stats'] = statRows.length;
    final stats = statRows.map((r) {
      final d = r.data;
      return i.ReadingStat(
        id: d['id'] as int,
        date: DateTime.parse(d['date'] as String),
        readingTimeSeconds: d['reading_time_seconds'] as int? ?? 0,
        snippetsCreated: d['snippets_created'] as int? ?? 0,
        booksCompleted: d['books_completed'] as int? ?? 0,
      );
    }).toList();
    await isarInstance.writeTxn(
        () => isarInstance.readingStats.putAll(stats));
    targetCounts['reading_stats'] = stats.length;

    // ── WebCache ────────────────────────────────────────────────────
    final cacheRows = await db.customSelect('SELECT * FROM web_cache').get();
    sourceCounts['web_cache'] = cacheRows.length;
    final caches = cacheRows.map((r) {
      final d = r.data;
      return i.WebCache(
        id: d['id'] as int,
        urlHash: d['url_hash'] as String,
        url: d['url'] as String,
        title: d['title'] as String,
        content: d['content'] as String,
        cachedAt: d['cached_at'] != null
            ? DateTime.parse(d['cached_at'] as String)
            : null,
      );
    }).toList();
    await isarInstance.writeTxn(
        () => isarInstance.webCaches.putAll(caches));
    targetCounts['web_cache'] = caches.length;

    // ── Sources ─────────────────────────────────────────────────────
    final srcRows = await db.customSelect('SELECT * FROM sources').get();
    sourceCounts['sources'] = srcRows.length;
    final srcs = srcRows.map((r) {
      final d = r.data;
      return i.Source(
        id: d['id'] as int,
        name: d['name'] as String,
        tag: d['tag'] as String,
        baseUrl: d['base_url'] as String,
        enabled: (d['enabled'] as int? ?? 1) == 1,
        language: d['language'] as String?,
        createdAt: d['created_at'] != null
            ? DateTime.parse(d['created_at'] as String)
            : null,
      );
    }).toList();
    await isarInstance.writeTxn(() => isarInstance.sources.putAll(srcs));
    targetCounts['sources'] = srcs.length;

    // ── Manga ───────────────────────────────────────────────────────
    final mangaRows = await db.customSelect('SELECT * FROM manga').get();
    sourceCounts['manga'] = mangaRows.length;
    final mangas = mangaRows.map((r) {
      final d = r.data;
      return i.Manga(
        id: d['id'] as int,
        name: d['name'] as String,
        url: d['url'] as String,
        imageUrl: d['image_url'] as String?,
        author: d['author'] as String?,
        artist: d['artist'] as String?,
        description: d['description'] as String?,
        status: d['status'] as int? ?? 0,
        genres: _splitGenres(d['genre'] as String? ?? ''),
        sourceId: d['source_id'] as String? ?? '',
        inLibrary: (d['in_library'] as int? ?? 0) == 1,
        readingStatus: d['reading_status'] as int? ?? 0,
        createdAt: d['created_at'] != null
            ? DateTime.parse(d['created_at'] as String)
            : null,
        updatedAt: d['updated_at'] != null
            ? DateTime.parse(d['updated_at'] as String)
            : null,
      );
    }).toList();
    await isarInstance.writeTxn(() => isarInstance.mangas.putAll(mangas));
    targetCounts['manga'] = mangas.length;

    // ── MangaChapters ───────────────────────────────────────────────
    final mcRows =
        await db.customSelect('SELECT * FROM manga_chapters').get();
    sourceCounts['manga_chapters'] = mcRows.length;
    final mcs = mcRows.map((r) {
      final d = r.data;
      return i.MangaChapter(
        id: d['id'] as int,
        mangaId: d['manga_id'] as int,
        name: d['name'] as String,
        url: d['url'] as String,
        scanlator: d['scanlator'] as String?,
        dateUpload: d['date_upload'] as int? ?? 0,
        index: d['index'] as int,
        isRead: (d['is_read'] as int? ?? 0) == 1,
        lastPageRead: d['last_page_read'] as int? ?? 0,
        scrollPosition:
            (d['scroll_position'] as num?)?.toDouble() ?? 0.0,
        isDownloaded: (d['is_downloaded'] as int? ?? 0) == 1,
        isOpened: (d['is_opened'] as int? ?? 0) == 1,
        readAt: d['read_at'] != null
            ? DateTime.parse(d['read_at'] as String)
            : null,
      );
    }).toList();
    await isarInstance.writeTxn(
        () => isarInstance.mangaChapters.putAll(mcs));
    targetCounts['manga_chapters'] = mcs.length;

    // ── ExtensionSources ────────────────────────────────────────────
    //
    // Drift's `id` is TEXT (the native bridge's MD5). Isar's `id` is an
    // auto-increment int PK; `sourceId` is the unique logical ID. We let
    // Isar generate the PK and map Drift's `id` → `sourceId`. New field
    // `sourceCodeLanguage` defaults to 'mihon' for all existing rows.
    final esRows =
        await db.customSelect('SELECT * FROM extension_sources').get();
    sourceCounts['extension_sources'] = esRows.length;
    final extSrcs = esRows.map((r) {
      final d = r.data;
      return i.ExtensionSource(
        sourceId: d['id'] as String,
        name: d['name'] as String,
        version: d['version'] as String,
        versionLast: d['version_last'] as String?,
        lang: d['lang'] as String,
        apkPath: d['apk_path'] as String,
        className: d['class_name'] as String,
        iconUrl: d['icon_url'] as String?,
        baseUrl: d['base_url'] as String?,
        sourceCodeUrl: d['source_code_url'] as String?,
        repoUrl: d['repo_url'] as String?,
        isInstalled: (d['is_installed'] as int? ?? 1) == 1,
        isActive: (d['is_active'] as int? ?? 1) == 1,
        isNsfw: (d['is_nsfw'] as int? ?? 0) == 1,
        isPinned: (d['is_pinned'] as int? ?? 0) == 1,
        isObsolete: (d['is_obsolete'] as int? ?? 0) == 1,
        sourceCodeLanguage: 'mihon',
        createdAt: d['created_at'] != null
            ? DateTime.parse(d['created_at'] as String)
            : null,
        updatedAt: d['updated_at'] != null
            ? DateTime.parse(d['updated_at'] as String)
            : null,
      );
    }).toList();
    await isarInstance.writeTxn(
        () => isarInstance.extensionSources.putAll(extSrcs));
    targetCounts['extension_sources'] = extSrcs.length;

    // ── ExtensionRepos ──────────────────────────────────────────────
    final erRows =
        await db.customSelect('SELECT * FROM extension_repos').get();
    sourceCounts['extension_repos'] = erRows.length;
    final repos = erRows.map((r) {
      final d = r.data;
      return i.ExtensionRepo(
        id: d['id'] as int,
        name: d['name'] as String,
        url: d['url'] as String,
        enabled: (d['enabled'] as int? ?? 1) == 1,
        createdAt: d['created_at'] != null
            ? DateTime.parse(d['created_at'] as String)
            : null,
      );
    }).toList();
    await isarInstance.writeTxn(
        () => isarInstance.extensionRepos.putAll(repos));
    targetCounts['extension_repos'] = repos.length;

    // ── Done — flip the gate flag ──────────────────────────────────
    await sp.setBool(kIsarMigratedFlag, true);

    return MigrationReport(
      skipped: false,
      elapsed: DateTime.now().difference(start),
      sourceCounts: sourceCounts,
      targetCounts: targetCounts,
    );
  } catch (e, st) {
    return MigrationReport(
      skipped: false,
      elapsed: DateTime.now().difference(start),
      error: '$e\n$st',
    );
  }
}

/// Reset the migration flag (for testing or re-running after a failed
/// migration). Does NOT delete any data — the next call to
/// [migrateDriftToIsar] will upsert over existing Isar rows.
Future<void> resetMigrationFlag(SharedPreferences? prefs) async {
  final sp = prefs ?? await SharedPreferences.getInstance();
  await sp.remove(kIsarMigratedFlag);
}

List<String> _splitGenres(String raw) {
  if (raw.trim().isEmpty) return const [];
  return raw
      .split(',')
      .map((g) => g.trim())
      .where((g) => g.isNotEmpty)
      .toList(growable: false);
}

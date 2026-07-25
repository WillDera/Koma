import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/database/database.dart';
import 'package:koma/core/isar/collections/book.dart' as i;
import 'package:koma/core/isar/collections/chapter.dart' as i;
import 'package:koma/core/isar/collections/snippet.dart' as i;
import 'package:koma/core/isar/collections/snippet_collection.dart' as i;
import 'package:koma/core/isar/collections/tag.dart' as i;
import 'package:koma/core/isar/isar.dart';
import 'package:koma/core/isar/migration/drift_isar_migration.dart';
import 'package:koma/core/isar/migration/migration_report.dart';
import 'package:koma/core/services/database_service.dart';
import 'package:drift/native.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Initialize the Isar core binary for the host platform. In Flutter tests
/// on macOS, the native lib isn't auto-loaded — we point it at the dylib
/// shipped inside `isar_community_flutter_libs/macos/`.
Future<void> _initIsarCore() async {
  // Point Isar at the macOS dylib shipped inside isar_community_flutter_libs.
  // The production app gets this via the Flutter plugin system; for pure
  // Dart tests we resolve the path manually.
  final home = Platform.environment['HOME']!;
  final dylib = File('$home/.pub-cache/hosted/pub.dev/'
      'isar_community_flutter_libs-3.3.2/macos/libisar.dylib');
  if (!dylib.existsSync()) {
    throw StateError(
      'Isar macOS dylib not found at ${dylib.path}. '
      'Run flutter pub get first.',
    );
  }
  await Isar.initializeIsarCore(
    libraries: {Abi.current(): dylib.path},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService dbService;
  late AppDatabase db;
  late Isar isar;
  late SharedPreferences prefs;

  setUp(() async {
    await _initIsarCore();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    dbService = DatabaseService(db);
    await _createDriftTables(db);
    isar = await openIsarInMemory();
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    await db.close();
  });

  test('skips when flag is already set', () async {
    await prefs.setBool(kIsarMigratedFlag, true);
    final report = await migrateDriftToIsar(
      dbService,
      isar: isar,
      prefs: prefs,
    );
    expect(report.skipped, isTrue);
    // sourceCounts/targetCounts not populated when skipped.
    expect(report.sourceCounts, isEmpty);
  });

  test('migrates books with preserved IDs and all fields', () async {
    final now = DateTime.utc(2026, 7, 25, 12, 0, 0);
    await db.customStatement(
      "INSERT INTO books (id, title, author, source, progress, created_at, updated_at) "
      "VALUES (1, 'Test Book', 'Author', 'local', 0.5, '2026-07-25T12:00:00Z', '2026-07-25T12:00:00Z')",
    );

    final report = await migrateDriftToIsar(
      dbService,
      isar: isar,
      prefs: prefs,
    );

    expect(report.skipped, isFalse);
    expect(report.error, isNull);
    expect(report.sourceCounts['books'], 1);
    expect(report.targetCounts['books'], 1);
    expect(report.verified, isTrue);

    final books = await isar.books.where().findAll();
    expect(books.length, 1);
    expect(books.first.id, 1);
    expect(books.first.title, 'Test Book');
    expect(books.first.author, 'Author');
    expect(books.first.source, 'local');
    expect(books.first.progress, 0.5);
    // Isar returns DateTimes in local timezone; compare as instants.
    expect(books.first.createdAt?.toUtc(), now);
  });

  test('migrates chapters with bookId FK preserved', () async {
    await db.customStatement(
      "INSERT INTO books (id, title, source) VALUES (1, 'B', 'local')",
    );
    await db.customStatement(
      "INSERT INTO chapters (id, book_id, title, content, \"index\") "
      "VALUES (10, 1, 'Ch1', 'content', 0)",
    );

    final report = await migrateDriftToIsar(
      dbService,
      isar: isar,
      prefs: prefs,
    );

    expect(report.verified, isTrue);
    final chapters = await isar.chapters.where().findAll();
    expect(chapters.length, 1);
    expect(chapters.first.id, 10);
    expect(chapters.first.bookId, 1);
    expect(chapters.first.title, 'Ch1');
  });

  test('migrates snippets + tags junction into Snippet.tags', () async {
    await db.customStatement(
      "INSERT INTO snippets (id, content, source_title) VALUES (1, 'text', 'src')",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name) VALUES (1, 'tag-a'), (2, 'tag-b')",
    );
    await db.customStatement(
      "INSERT INTO snippet_tags (snippet_id, tag_id) VALUES (1, 1), (1, 2)",
    );

    final report = await migrateDriftToIsar(
      dbService,
      isar: isar,
      prefs: prefs,
    );

    expect(report.verified, isTrue);
    final snippets = await isar.snippets.where().findAll();
    expect(snippets.length, 1);
    expect(snippets.first.text, 'text');
    expect(snippets.first.tags, containsAll(['tag-a', 'tag-b']));

    final tags = await isar.tags.where().findAll();
    expect(tags.length, 2);
    expect(tags.map((t) => t.name).toList(), containsAll(['tag-a', 'tag-b']));
  });

  test('migrates snippet_collections', () async {
    await db.customStatement(
      "INSERT INTO snippet_collections (id, name, color) VALUES (1, 'Favs', '#FF0000')",
    );
    await migrateDriftToIsar(dbService, isar: isar, prefs: prefs);
    final colls = await isar.snippetCollections.where().findAll();
    expect(colls.length, 1);
    expect(colls.first.id, 1);
    expect(colls.first.name, 'Favs');
    expect(colls.first.color, '#FF0000');
  });

  test('flips gate flag on success', () async {
    await migrateDriftToIsar(dbService, isar: isar, prefs: prefs);
    expect(prefs.getBool(kIsarMigratedFlag), isTrue);
  });

  test('is idempotent — running twice is a no-op', () async {
    await db.customStatement(
      "INSERT INTO books (id, title, source) VALUES (1, 'B', 'local')",
    );
    await migrateDriftToIsar(dbService, isar: isar, prefs: prefs);
    final firstCount = await isar.books.count();
    // Second run should skip entirely (flag set).
    await migrateDriftToIsar(dbService, isar: isar, prefs: prefs);
    final secondCount = await isar.books.count();
    expect(secondCount, firstCount);
  });
}

/// Create all Drift tables in the in-memory DB so we can INSERT test data.
Future<void> _createDriftTables(AppDatabase db) async {
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS books (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      author TEXT,
      cover_path TEXT,
      source TEXT NOT NULL DEFAULT 'local',
      source_url TEXT,
      file_path TEXT,
      progress REAL NOT NULL DEFAULT 0.0,
      current_chapter_index INTEGER NOT NULL DEFAULT 0,
      total_chapters INTEGER NOT NULL DEFAULT 0,
      scroll_position REAL NOT NULL DEFAULT 0.0,
      genre TEXT NOT NULL DEFAULT '',
      file_extension TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS chapters (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      book_id INTEGER NOT NULL,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      "index" INTEGER NOT NULL,
      read_at TEXT,
      scroll_position REAL NOT NULL DEFAULT 0.0
    )
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS snippet_collections (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      color TEXT NOT NULL DEFAULT '#FFD700',
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS snippets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      content TEXT NOT NULL,
      note TEXT,
      source_title TEXT,
      source_url TEXT,
      color TEXT,
      book_id INTEGER,
      chapter_id INTEGER,
      collection_id INTEGER,
      start_offset INTEGER,
      end_offset INTEGER,
      scroll_position REAL,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS tags (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE
    )
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS snippet_tags (
      snippet_id INTEGER NOT NULL,
      tag_id INTEGER NOT NULL,
      PRIMARY KEY (snippet_id, tag_id)
    )
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS highlights (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      snippet_id INTEGER,
      book_id INTEGER NOT NULL,
      chapter_id INTEGER NOT NULL,
      start_offset INTEGER NOT NULL,
      end_offset INTEGER NOT NULL,
      color TEXT NOT NULL DEFAULT 'yellow',
      text TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS reading_stats (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL UNIQUE,
      reading_time_seconds INTEGER NOT NULL DEFAULT 0,
      snippets_created INTEGER NOT NULL DEFAULT 0,
      books_completed INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS web_cache (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      url_hash TEXT NOT NULL UNIQUE,
      url TEXT NOT NULL,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      cached_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS sources (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      tag TEXT NOT NULL,
      base_url TEXT NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 1,
      language TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS manga (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      url TEXT NOT NULL,
      image_url TEXT,
      author TEXT,
      artist TEXT,
      description TEXT,
      status INTEGER NOT NULL DEFAULT 0,
      genre TEXT NOT NULL DEFAULT '',
      source_id TEXT NOT NULL,
      in_library INTEGER NOT NULL DEFAULT 0,
      reading_status INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS manga_chapters (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      manga_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      url TEXT NOT NULL,
      scanlator TEXT,
      date_upload INTEGER NOT NULL DEFAULT 0,
      "index" INTEGER NOT NULL,
      is_read INTEGER NOT NULL DEFAULT 0,
      last_page_read INTEGER NOT NULL DEFAULT 0,
      scroll_position REAL NOT NULL DEFAULT 0.0,
      is_downloaded INTEGER NOT NULL DEFAULT 0,
      is_opened INTEGER NOT NULL DEFAULT 0,
      read_at TEXT
    )
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS extension_sources (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      version TEXT NOT NULL,
      version_last TEXT,
      lang TEXT NOT NULL,
      apk_path TEXT NOT NULL,
      class_name TEXT NOT NULL,
      icon_url TEXT,
      base_url TEXT,
      source_code_url TEXT,
      repo_url TEXT,
      is_installed INTEGER NOT NULL DEFAULT 1,
      is_active INTEGER NOT NULL DEFAULT 1,
      is_nsfw INTEGER NOT NULL DEFAULT 0,
      is_pinned INTEGER NOT NULL DEFAULT 0,
      is_obsolete INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS extension_repos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      url TEXT NOT NULL UNIQUE,
      enabled INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''');
}

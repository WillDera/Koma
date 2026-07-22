import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppDatabase extends GeneratedDatabase {
  AppDatabase(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 7;

  @override
  Iterable<TableInfo> get allTables => const [];

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {},
      onUpgrade: (Migrator m, int from, int to) async {},
      beforeOpen: (details) async {
        await _createTables();
        // v1 → v2 migrations (idempotent — each ALTER is wrapped in
        // try/catch so re-running on a newer schema is a no-op).
        try {
          await customStatement(
              'ALTER TABLE books ADD COLUMN scroll_position REAL NOT NULL DEFAULT 0.0');
        } catch (_) {}
        try {
          await customStatement(
              'ALTER TABLE chapters ADD COLUMN scroll_position REAL NOT NULL DEFAULT 0.0');
        } catch (_) {}
        // v2 → v3: genre + file_extension on books.
        try {
          await customStatement(
              'ALTER TABLE books ADD COLUMN genre TEXT NOT NULL DEFAULT \'\'');
        } catch (_) {}
        try {
          await customStatement(
              'ALTER TABLE books ADD COLUMN file_extension TEXT NOT NULL DEFAULT \'\'');
        } catch (_) {}
        // Backfill file_extension for existing books from file_path.
        try {
          await customStatement(
            "UPDATE books SET file_extension = '.epub' WHERE file_extension = '' AND file_path LIKE '%.epub'"
          );
        } catch (_) {}
        try {
          await customStatement(
            "UPDATE books SET file_extension = '.pdf' WHERE file_extension = '' AND file_path LIKE '%.pdf'"
          );
        } catch (_) {}
        try {
          await customStatement(
            "UPDATE books SET file_extension = '.html' WHERE file_extension = '' AND file_path LIKE '%.html'"
          );
        } catch (_) {}
        try {
          await customStatement(
            "UPDATE books SET file_extension = 'web' WHERE file_extension = '' AND source = 'web'"
          );
        } catch (_) {}
        try {
          await customStatement(
            "UPDATE books SET file_extension = 'note' WHERE file_extension = '' AND source = 'manual'"
          );
        } catch (_) {}
        // v3 → v4: downloaded flag on manga_chapters.
        try {
          await customStatement(
            'ALTER TABLE manga_chapters ADD COLUMN is_downloaded INTEGER NOT NULL DEFAULT 0'
          );
        } catch (_) {}
        // v4 → v5: opened flag on manga_chapters.
        try {
          await customStatement(
            'ALTER TABLE manga_chapters ADD COLUMN is_opened INTEGER NOT NULL DEFAULT 0'
          );
        } catch (_) {}
        // v5 → v6: read_at timestamp on manga_chapters.
        try {
          await customStatement(
            'ALTER TABLE manga_chapters ADD COLUMN read_at TEXT'
          );
        } catch (_) {}
        // v6 → v7: snippet collections.
        try {
          await customStatement(
            'ALTER TABLE snippets ADD COLUMN collection_id INTEGER REFERENCES snippet_collections(id) ON DELETE SET NULL'
          );
        } catch (_) {}
        try {
          await customStatement('''
            CREATE TABLE IF NOT EXISTS snippet_collections (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              color TEXT NOT NULL DEFAULT '#FFD700',
              created_at TEXT NOT NULL DEFAULT (datetime('now')),
              updated_at TEXT NOT NULL DEFAULT (datetime('now'))
            )
          ''');
        } catch (_) {}
      },
    );
  }

  Future<void> _createTables() async {
    await customStatement('PRAGMA journal_mode=WAL;');
    await customStatement('PRAGMA foreign_keys=ON;');
    await customStatement('''
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
    await customStatement('''
      CREATE TABLE IF NOT EXISTS chapters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        "index" INTEGER NOT NULL,
        read_at TEXT
      )
    ''');
    await customStatement('''
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
    await customStatement('''
      CREATE TABLE IF NOT EXISTS manga_chapters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        manga_id INTEGER NOT NULL REFERENCES manga(id) ON DELETE CASCADE,
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
    await customStatement('''
      CREATE TABLE IF NOT EXISTS snippets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        note TEXT,
        source_title TEXT,
        source_url TEXT,
        color TEXT,
        book_id INTEGER REFERENCES books(id) ON DELETE SET NULL,
        chapter_id INTEGER REFERENCES chapters(id) ON DELETE SET NULL,
        collection_id INTEGER REFERENCES snippet_collections(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS extension_sources (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        version TEXT NOT NULL,
        lang TEXT NOT NULL,
        apk_path TEXT NOT NULL,
        class_name TEXT NOT NULL,
        icon_url TEXT,
        is_installed INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS extension_repos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        url TEXT NOT NULL UNIQUE,
        enabled INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS snippet_tags (
        snippet_id INTEGER NOT NULL REFERENCES snippets(id) ON DELETE CASCADE,
        tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
        PRIMARY KEY (snippet_id, tag_id)
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS reading_stats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        reading_time_seconds INTEGER NOT NULL DEFAULT 0,
        snippets_created INTEGER NOT NULL DEFAULT 0,
        books_completed INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS web_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        url_hash TEXT NOT NULL UNIQUE,
        url TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        cached_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    // Drop old sources table schema; recreate with tag + base_url.
    try {
      await customStatement('DROP TABLE IF EXISTS sources');
    } catch (_) {}
    await customStatement('''
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
  }

  static Future<AppDatabase> create() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'koma.db'));
    final executor = NativeDatabase(file);
    return AppDatabase(executor);
  }
}

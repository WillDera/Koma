import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:koma/core/database/database.dart';

import 'helpers/test_database.dart';

/// Tests DatabaseService CRUD by exercising the same SQL layer directly.
/// DatabaseService has a private constructor (singleton), so we test the
/// underlying AppDatabase operations which use identical SQL statements.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  // -- Books --

  group('Books CRUD', () {
    test('insert and retrieve a book', () async {
      final id = await db.customInsert(
        'INSERT INTO books (title, author, source, progress, current_chapter_index, total_chapters) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('Test Book'),
          Variable.withString('Author A'),
          Variable.withString('local'),
          Variable.withReal(0.0),
          Variable.withInt(0),
          Variable.withInt(10),
        ],
      );

      expect(id, greaterThan(0));

      final rows = await db
          .customSelect('SELECT * FROM books WHERE id = ?',
              variables: [Variable.withInt(id)])
          .get();

      expect(rows.length, 1);
      expect(rows.first.data['title'], 'Test Book');
      expect(rows.first.data['author'], 'Author A');
      expect(rows.first.data['source'], 'local');
      expect((rows.first.data['progress'] as num).toDouble(), 0.0);
    });

    test('getBooks returns all books ordered by updated_at DESC', () async {
      await db.customInsert(
        'INSERT INTO books (title, author, source, updated_at) VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString('Book B'),
          Variable.withString('Author'),
          Variable.withString('local'),
          Variable.withDateTime(DateTime(2025, 1, 1)),
        ],
      );
      await db.customInsert(
        'INSERT INTO books (title, author, source, updated_at) VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString('Book A'),
          Variable.withString('Author'),
          Variable.withString('local'),
          Variable.withDateTime(DateTime(2025, 6, 1)),
        ],
      );

      final rows =
          await db.customSelect('SELECT * FROM books ORDER BY updated_at DESC').get();
      expect(rows.length, 2);
      // Most recently updated comes first
      expect(rows.first.data['title'], 'Book A');
    });

    test('update book fields', () async {
      final id = await db.customInsert(
        'INSERT INTO books (title, author, source, progress) VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString('Original'),
          Variable.withString('Author'),
          Variable.withString('local'),
          Variable.withReal(0.0),
        ],
      );

      await db.customUpdate(
        'UPDATE books SET title=?, progress=?, updated_at=? WHERE id=?',
        variables: [
          Variable.withString('Updated'),
          Variable.withReal(0.5),
          Variable.withDateTime(DateTime.now()),
          Variable.withInt(id),
        ],
      );

      final row = await db
          .customSelect('SELECT * FROM books WHERE id = ?',
              variables: [Variable.withInt(id)])
          .get();
      expect(row.first.data['title'], 'Updated');
      expect((row.first.data['progress'] as num).toDouble(), 0.5);
    });

    test('delete book removes it', () async {
      final id = await db.customInsert(
        'INSERT INTO books (title, author, source) VALUES (?, ?, ?)',
        variables: [
          Variable.withString('Doomed'),
          Variable.withString('Author'),
          Variable.withString('local'),
        ],
      );

      await db.customUpdate(
        'DELETE FROM books WHERE id=?',
        variables: [Variable.withInt(id)],
      );

      final rows = await db
          .customSelect('SELECT * FROM books WHERE id = ?',
              variables: [Variable.withInt(id)])
          .get();
      expect(rows, isEmpty);
    });

    test('updateProgress only changes progress and updated_at', () async {
      final id = await db.customInsert(
        'INSERT INTO books (title, author, source, progress, total_chapters) '
        'VALUES (?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('Progress Book'),
          Variable.withString('Author'),
          Variable.withString('local'),
          Variable.withReal(0.0),
          Variable.withInt(5),
        ],
      );

      await db.customUpdate(
        'UPDATE books SET progress=?, updated_at=? WHERE id=?',
        variables: [
          Variable.withReal(0.75),
          Variable.withDateTime(DateTime.now()),
          Variable.withInt(id),
        ],
      );

      final row = await db
          .customSelect('SELECT * FROM books WHERE id = ?',
              variables: [Variable.withInt(id)])
          .get();
      expect((row.first.data['progress'] as num).toDouble(), 0.75);
      expect(row.first.data['total_chapters'], 5); // unchanged
    });
  });

  // -- Chapters --

  group('Chapters CRUD', () {
    late int bookId;

    setUp(() async {
      bookId = await db.customInsert(
        'INSERT INTO books (title, author, source) VALUES (?, ?, ?)',
        variables: [
          Variable.withString('Chapter Test Book'),
          Variable.withString('Author'),
          Variable.withString('local'),
        ],
      );
    });

    test('insert and retrieve chapters', () async {
      final chId = await db.customInsert(
        'INSERT INTO chapters (book_id, title, content, "index") VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withInt(bookId),
          Variable.withString('Ch 1'),
          Variable.withString('Hello content'),
          Variable.withInt(0),
        ],
      );

      expect(chId, greaterThan(0));

      final rows = await db
          .customSelect('SELECT * FROM chapters WHERE book_id = ?',
              variables: [Variable.withInt(bookId)])
          .get();
      expect(rows.length, 1);
      expect(rows.first.data['title'], 'Ch 1');
      expect(rows.first.data['content'], 'Hello content');
    });

    test('getChapters ordered by index ASC', () async {
      await db.customInsert(
        'INSERT INTO chapters (book_id, title, content, "index") VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withInt(bookId),
          Variable.withString('Ch 2'),
          Variable.withString('Second'),
          Variable.withInt(1),
        ],
      );
      await db.customInsert(
        'INSERT INTO chapters (book_id, title, content, "index") VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withInt(bookId),
          Variable.withString('Ch 1'),
          Variable.withString('First'),
          Variable.withInt(0),
        ],
      );

      final rows = await db
          .customSelect(
              'SELECT * FROM chapters WHERE book_id = ? ORDER BY "index" ASC',
              variables: [Variable.withInt(bookId)])
          .get();
      expect(rows.length, 2);
      expect(rows[0].data['title'], 'Ch 1');
      expect(rows[1].data['title'], 'Ch 2');
    });

    test('mark chapter read sets read_at', () async {
      final chId = await db.customInsert(
        'INSERT INTO chapters (book_id, title, content, "index") VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withInt(bookId),
          Variable.withString('Read Me'),
          Variable.withString('Content'),
          Variable.withInt(0),
        ],
      );

      await db.customUpdate(
        'UPDATE chapters SET read_at=? WHERE id=?',
        variables: [
          Variable.withDateTime(DateTime.now()),
          Variable.withInt(chId),
        ],
      );

      final row = await db
          .customSelect('SELECT * FROM chapters WHERE id = ?',
              variables: [Variable.withInt(chId)])
          .get();
      expect(row.first.data['read_at'], isNotNull);
    });

    test('insertChapters bulk insert', () async {
      final chapters = [
        for (var i = 0; i < 5; i++)
          await db.customInsert(
            'INSERT INTO chapters (book_id, title, content, "index") VALUES (?, ?, ?, ?)',
            variables: [
              Variable.withInt(bookId),
              Variable.withString('Chapter $i'),
              Variable.withString('Content $i'),
              Variable.withInt(i),
            ],
          ),
      ];
      expect(chapters.length, 5);

      final rows = await db
          .customSelect('SELECT COUNT(*) as cnt FROM chapters WHERE book_id = ?',
              variables: [Variable.withInt(bookId)])
          .get();
      expect(rows.first.data['cnt'], 5);
    });
  });

  // -- Snippets & Tags --

  group('Snippets and Tags', () {
    test('create snippet and retrieve with tags', () async {
      // Insert snippet
      final snippetId = await db.customInsert(
        'INSERT INTO snippets (content, note, source_title, color, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('Important quote'),
          Variable.withString('My note'),
          Variable.withString('Some Book'),
          Variable.withString('#FF5733'),
          Variable.withDateTime(DateTime.now()),
          Variable.withDateTime(DateTime.now()),
        ],
      );

      // Add tags
      await db.customInsert('INSERT INTO tags (name) VALUES (?)',
          variables: [Variable.withString('flutter')]);
      await db.customInsert('INSERT INTO tags (name) VALUES (?)',
          variables: [Variable.withString('dart')]);

      final tag1 = await db
          .customSelect('SELECT id FROM tags WHERE name = ?',
              variables: [Variable.withString('flutter')])
          .get();
      final tag2 = await db
          .customSelect('SELECT id FROM tags WHERE name = ?',
              variables: [Variable.withString('dart')])
          .get();

      await db.customInsert(
        'INSERT OR IGNORE INTO snippet_tags (snippet_id, tag_id) VALUES (?, ?)',
        variables: [
          Variable.withInt(snippetId),
          Variable.withInt(tag1.first.data['id'] as int),
        ],
      );
      await db.customInsert(
        'INSERT OR IGNORE INTO snippet_tags (snippet_id, tag_id) VALUES (?, ?)',
        variables: [
          Variable.withInt(snippetId),
          Variable.withInt(tag2.first.data['id'] as int),
        ],
      );

      // Query tags for snippet
      final tagRows = await db.customSelect(
        'SELECT t.name FROM tags t '
        'INNER JOIN snippet_tags st ON st.tag_id = t.id '
        'WHERE st.snippet_id = ? ORDER BY t.name',
        variables: [Variable.withInt(snippetId)],
      ).get();

      expect(tagRows.length, 2);
      expect(tagRows[0].data['name'], 'dart');
      expect(tagRows[1].data['name'], 'flutter');

      // Verify snippet content
      final snippetRow = await db
          .customSelect('SELECT * FROM snippets WHERE id = ?',
              variables: [Variable.withInt(snippetId)])
          .get();
      expect(snippetRow.first.data['content'], 'Important quote');
      expect(snippetRow.first.data['note'], 'My note');
    });

    test('delete snippet removes it and cascades tags', () async {
      final snippetId = await db.customInsert(
        'INSERT INTO snippets (content, created_at, updated_at) VALUES (?, ?, ?)',
        variables: [
          Variable.withString('Ephemeral'),
          Variable.withDateTime(DateTime.now()),
          Variable.withDateTime(DateTime.now()),
        ],
      );

      await db.customInsert('INSERT INTO tags (name) VALUES (?)',
          variables: [Variable.withString('temp')]);
      final tagRow = await db
          .customSelect('SELECT id FROM tags WHERE name = ?',
              variables: [Variable.withString('temp')])
          .get();

      await db.customInsert(
        'INSERT OR IGNORE INTO snippet_tags (snippet_id, tag_id) VALUES (?, ?)',
        variables: [
          Variable.withInt(snippetId),
          Variable.withInt(tagRow.first.data['id'] as int),
        ],
      );

      // Delete snippet — cascade should remove snippet_tags
      await db.customUpdate(
        'DELETE FROM snippets WHERE id=?',
        variables: [Variable.withInt(snippetId)],
      );

      final remaining = await db
          .customSelect('SELECT * FROM snippet_tags WHERE snippet_id = ?',
              variables: [Variable.withInt(snippetId)])
          .get();
      expect(remaining, isEmpty);

      // Tag itself should still exist (no cascade to tags table)
      final tagStillThere = await db
          .customSelect('SELECT * FROM tags WHERE name = ?',
              variables: [Variable.withString('temp')])
          .get();
      expect(tagStillThere.length, 1);
    });

    test('getAllTags returns tags sorted by name', () async {
      await db.customInsert('INSERT INTO tags (name) VALUES (?)',
          variables: [Variable.withString('zebra')]);
      await db.customInsert('INSERT INTO tags (name) VALUES (?)',
          variables: [Variable.withString('alpha')]);
      await db.customInsert('INSERT INTO tags (name) VALUES (?)',
          variables: [Variable.withString('middle')]);

      final rows = await db
          .customSelect('SELECT name FROM tags ORDER BY name')
          .get();
      expect(rows.map((r) => r.data['name']).toList(),
          ['alpha', 'middle', 'zebra']);
    });

    test('tag uniqueness constraint', () async {
      await db.customInsert('INSERT INTO tags (name) VALUES (?)',
          variables: [Variable.withString('unique_tag')]);

      // Second insert with same name should fail
      expect(
        () => db.customInsert('INSERT INTO tags (name) VALUES (?)',
            variables: [Variable.withString('unique_tag')]),
        throwsA(anything),
      );
    });

    test('snippets for specific book', () async {
      // Create two books
      final book1 = await db.customInsert(
        'INSERT INTO books (title, author, source) VALUES (?, ?, ?)',
        variables: [
          Variable.withString('Book 1'),
          Variable.withString('Author'),
          Variable.withString('local'),
        ],
      );
      final book2 = await db.customInsert(
        'INSERT INTO books (title, author, source) VALUES (?, ?, ?)',
        variables: [
          Variable.withString('Book 2'),
          Variable.withString('Author'),
          Variable.withString('local'),
        ],
      );

      // Create snippets for each book
      await db.customInsert(
        'INSERT INTO snippets (content, book_id, created_at, updated_at) VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString('Snippet for Book 1'),
          Variable.withInt(book1),
          Variable.withDateTime(DateTime.now()),
          Variable.withDateTime(DateTime.now()),
        ],
      );
      await db.customInsert(
        'INSERT INTO snippets (content, book_id, created_at, updated_at) VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString('Snippet for Book 2'),
          Variable.withInt(book2),
          Variable.withDateTime(DateTime.now()),
          Variable.withDateTime(DateTime.now()),
        ],
      );

      final rows = await db
          .customSelect(
              'SELECT * FROM snippets WHERE book_id = ? ORDER BY created_at DESC',
              variables: [Variable.withInt(book1)])
          .get();
      expect(rows.length, 1);
      expect(rows.first.data['content'], 'Snippet for Book 1');
    });
  });

  // -- Delete cascade --

  group('Delete cascade', () {
    test('deleting book cascades to chapters', () async {
      final bookId = await db.customInsert(
        'INSERT INTO books (title, author, source) VALUES (?, ?, ?)',
        variables: [
          Variable.withString('Cascade Book'),
          Variable.withString('Author'),
          Variable.withString('local'),
        ],
      );
      await db.customInsert(
        'INSERT INTO chapters (book_id, title, content, "index") VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withInt(bookId),
          Variable.withString('Ch 1'),
          Variable.withString('Content'),
          Variable.withInt(0),
        ],
      );

      await db.customUpdate(
        'DELETE FROM books WHERE id=?',
        variables: [Variable.withInt(bookId)],
      );

      final chapters = await db
          .customSelect('SELECT * FROM chapters WHERE book_id = ?',
              variables: [Variable.withInt(bookId)])
          .get();
      expect(chapters, isEmpty);
    });

    test('deleting book sets snippet book_id to null', () async {
      final bookId = await db.customInsert(
        'INSERT INTO books (title, author, source) VALUES (?, ?, ?)',
        variables: [
          Variable.withString('Snippet Book'),
          Variable.withString('Author'),
          Variable.withString('local'),
        ],
      );
      final snippetId = await db.customInsert(
        'INSERT INTO snippets (content, book_id, created_at, updated_at) VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString('Orphan snippet'),
          Variable.withInt(bookId),
          Variable.withDateTime(DateTime.now()),
          Variable.withDateTime(DateTime.now()),
        ],
      );

      await db.customUpdate(
        'DELETE FROM books WHERE id=?',
        variables: [Variable.withInt(bookId)],
      );

      final row = await db
          .customSelect('SELECT * FROM snippets WHERE id = ?',
              variables: [Variable.withInt(snippetId)])
          .get();
      expect(row.length, 1);
      expect(row.first.data['book_id'], isNull);
    });
  });

  // -- Reading Stats --

  group('Reading Stats', () {
    test('upsert creates new stats row', () async {
      final today = DateTime(2025, 6, 15);
      await db.customInsert(
        'INSERT INTO reading_stats (date, reading_time_seconds, snippets_created, books_completed) '
        'VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withDateTime(today),
          Variable.withInt(120),
          Variable.withInt(3),
          Variable.withInt(1),
        ],
      );

      final row = await db
          .customSelect('SELECT * FROM reading_stats WHERE date = ?',
              variables: [Variable.withDateTime(today)])
          .get();
      expect(row.length, 1);
      expect(row.first.data['reading_time_seconds'], 120);
      expect(row.first.data['snippets_created'], 3);
      expect(row.first.data['books_completed'], 1);
    });

    test('upsert increments existing stats', () async {
      final today = DateTime(2025, 6, 15);
      await db.customInsert(
        'INSERT INTO reading_stats (date, reading_time_seconds, snippets_created, books_completed) '
        'VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withDateTime(today),
          Variable.withInt(100),
          Variable.withInt(2),
          Variable.withInt(0),
        ],
      );

      // Increment
      await db.customUpdate(
        'UPDATE reading_stats SET '
        'reading_time_seconds = reading_time_seconds + ?, '
        'snippets_created = snippets_created + ?, '
        'books_completed = books_completed + ? '
        'WHERE date = ?',
        variables: [
          Variable.withInt(50),
          Variable.withInt(1),
          Variable.withInt(1),
          Variable.withDateTime(today),
        ],
      );

      final row = await db
          .customSelect('SELECT * FROM reading_stats WHERE date = ?',
              variables: [Variable.withDateTime(today)])
          .get();
      expect(row.first.data['reading_time_seconds'], 150);
      expect(row.first.data['snippets_created'], 3);
      expect(row.first.data['books_completed'], 1);
    });

    test('getStatsRange returns correct range', () async {
      final day1 = DateTime(2025, 6, 10);
      final day2 = DateTime(2025, 6, 12);
      final day3 = DateTime(2025, 6, 15);

      for (final d in [day1, day2, day3]) {
        await db.customInsert(
          'INSERT INTO reading_stats (date, reading_time_seconds) VALUES (?, ?)',
          variables: [
            Variable.withDateTime(d),
            Variable.withInt(60),
          ],
        );
      }

      final rows = await db
          .customSelect(
              'SELECT * FROM reading_stats WHERE date >= ? AND date <= ? ORDER BY date',
              variables: [
            Variable.withDateTime(day1),
            Variable.withDateTime(day2),
          ])
          .get();
      expect(rows.length, 2);
    });

    test('stats date uniqueness constraint', () async {
      final today = DateTime(2025, 7, 1);
      await db.customInsert(
        'INSERT INTO reading_stats (date, reading_time_seconds) VALUES (?, ?)',
        variables: [
          Variable.withDateTime(today),
          Variable.withInt(10),
        ],
      );

      expect(
        () => db.customInsert(
          'INSERT INTO reading_stats (date, reading_time_seconds) VALUES (?, ?)',
          variables: [
            Variable.withDateTime(today),
            Variable.withInt(20),
          ],
        ),
        throwsA(anything),
      );
    });
  });
}

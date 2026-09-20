import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/models/snippet.dart';
import 'package:koma/core/services/snippet_export_service.dart';

void main() {
  const service = SnippetExportService();

  Snippet sn({
    required int id,
    required String text,
    String? note,
    String? sourceTitle,
    String? sourceUrl,
    List<String> tags = const [],
    DateTime? createdAt,
  }) {
    return Snippet(
      id: id,
      text: text,
      note: note,
      sourceTitle: sourceTitle,
      sourceUrl: sourceUrl,
      tags: tags,
      createdAt: createdAt ?? DateTime.utc(2025, 1, 15),
    );
  }

  group('exportMarkdown', () {
    test('groups by sourceTitle', () {
      final out = service.exportMarkdown([
        sn(id: 1, text: 'A', sourceTitle: 'Book B'),
        sn(id: 2, text: 'B', sourceTitle: 'Book A', note: 'thought'),
        sn(id: 3, text: 'C'),
      ]);
      expect(out, contains('# Book A'));
      expect(out, contains('# Book B'));
      expect(out, contains('# Ungrouped'));
      expect(out.indexOf('# Book A'), lessThan(out.indexOf('# Book B')));
      expect(out, contains('> B'));
      expect(out, contains('thought'));
    });

    test('empty list yields empty string', () {
      expect(service.exportMarkdown([]), '');
    });
  });

  group('exportCsv', () {
    test('writes header and rows with CSV escaping', () {
      final out = service.exportCsv([
        sn(
          id: 1,
          text: 'Hello, "world"',
          note: 'line\nbreak',
          sourceTitle: 'Title',
          sourceUrl: 'https://x.test',
          tags: ['a', 'b'],
        ),
      ]);
      expect(
        out,
        startsWith('text,note,source_title,source_url,tags,created_at\n'),
      );
      expect(out, contains('"Hello, ""world"""'));
      expect(out, contains('"line\nbreak"'));
      expect(out, contains('a;b'));
    });
  });

  group('exportAnkiTsv', () {
    test('front is text; back prefers note then sourceTitle', () {
      final withNote = service.exportAnkiTsv([
        sn(id: 1, text: 'Front', note: 'Back note', sourceTitle: 'Src'),
      ]);
      expect(withNote.trim(), 'Front\tBack note');

      final noNote = service.exportAnkiTsv([
        sn(id: 2, text: 'Q', sourceTitle: 'From book'),
      ]);
      expect(noNote.trim(), 'Q\tFrom book');
    });

    test('escapes tabs and newlines in fields', () {
      final out = service.exportAnkiTsv([
        sn(id: 1, text: 'a\tb\nc', note: 'x\ty'),
      ]);
      final line = out.trimRight();
      expect(line.contains('\t'), isTrue);
      expect(line.split('\t').length, 2);
      expect(line, isNot(contains('\n')));
      expect(line.startsWith('a b c\t'), isTrue);
    });
  });
}

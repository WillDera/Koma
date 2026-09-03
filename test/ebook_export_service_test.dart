import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/models/book.dart';
import 'package:koma/core/services/ebook_export_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('ebook_export_');
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('copies ebook files and skips missing paths', () async {
    final srcDir = Directory(p.join(tempRoot.path, 'src'))..createSync();
    final destDir = Directory(p.join(tempRoot.path, 'dest'))..createSync();
    final epub = File(p.join(srcDir.path, 'Novel.epub'))
      ..writeAsStringSync('epub-bytes');
    File(p.join(srcDir.path, 'Other.pdf')).writeAsStringSync('pdf-bytes');

    final result = await EbookExportService.exportToDirectory(
      books: [
        Book(
          id: 1,
          title: 'Novel',
          source: 'local',
          filePath: epub.path,
          fileExtension: 'epub',
        ),
        Book(
          id: 2,
          title: 'Missing',
          source: 'local',
          filePath: p.join(srcDir.path, 'gone.epub'),
          fileExtension: 'epub',
        ),
        Book(
          id: 3,
          title: 'No file',
          source: 'local',
          fileExtension: 'epub',
        ),
      ],
      destinationDir: destDir.path,
    );

    expect(result.exported, 1);
    expect(result.skipped, 2);
    expect(result.failed, 0);
    expect(File(p.join(destDir.path, 'Novel.epub')).existsSync(), isTrue);
    expect(
      File(p.join(destDir.path, 'Novel.epub')).readAsStringSync(),
      'epub-bytes',
    );
  });

  test('avoids overwriting by uniquifying names', () async {
    final srcDir = Directory(p.join(tempRoot.path, 'src'))..createSync();
    final destDir = Directory(p.join(tempRoot.path, 'dest'))..createSync();
    File(p.join(destDir.path, 'same.epub')).writeAsStringSync('existing');
    final a = File(p.join(srcDir.path, 'same.epub'))..writeAsStringSync('a');
    final b = File(p.join(srcDir.path, 'copy.epub'))..writeAsStringSync('b');

    final result = await EbookExportService.exportToDirectory(
      books: [
        Book(
          id: 1,
          title: 'A',
          source: 'local',
          filePath: a.path,
          fileExtension: 'epub',
        ),
        Book(
          id: 2,
          title: 'B',
          source: 'local',
          filePath: b.path,
          fileExtension: 'epub',
        ),
      ],
      destinationDir: destDir.path,
    );

    // Second book prefers basename "copy.epub"; first collides with existing.
    expect(result.exported, 2);
    expect(File(p.join(destDir.path, 'same.epub')).readAsStringSync(), 'existing');
    expect(
      File(p.join(destDir.path, 'same (1).epub')).readAsStringSync(),
      'a',
    );
    expect(File(p.join(destDir.path, 'copy.epub')).readAsStringSync(), 'b');
  });
}

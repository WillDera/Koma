import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/models/library_category.dart';
import 'package:koma/core/models/manga.dart';
import 'package:koma/core/models/manga_chapter.dart';
import 'package:koma/core/services/backup/backup_format.dart';
import 'package:koma/core/services/backup/backup_importer.dart';
import 'package:koma/core/services/backup/backup_status_map.dart';
import 'package:koma/core/services/backup/foreign_backup.dart';
import 'package:koma/core/services/backup/mangayomi_backup_decoder.dart';
import 'package:koma/core/services/backup/mihon_backup_decoder.dart';
import 'package:koma/core/services/export_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sniffBackup', () {
    test('detects gzip as mihon', () {
      expect(sniffBackup([0x1f, 0x8b, 0x08]).kind, BackupKind.mihon);
    });

    test('detects zip as mangayomi', () {
      expect(sniffBackup([0x50, 0x4b, 0x03, 0x04]).kind, BackupKind.mangayomi);
    });

    test('detects koma json', () {
      final bytes = utf8.encode('{"version":4,"books":[]}');
      expect(sniffBackup(bytes).kind, BackupKind.komaJson);
    });
  });

  group('status map', () {
    test('maps mangayomi Status.index to SManga', () {
      expect(mangayomiStatusToSManga(0), SMangaStatus.ongoing);
      expect(mangayomiStatusToSManga(1), SMangaStatus.completed);
      expect(mangayomiStatusToSManga(2), SMangaStatus.cancelled);
      expect(mangayomiStatusToSManga(4), SMangaStatus.onHiatus);
      expect(mangayomiStatusToSManga(5), SMangaStatus.publishingFinished);
    });
  });

  group('Mihon protobuf', () {
    test('omitted favorite means in-library', () {
      final encoded = encodeMihonBackup(
        ForeignLibraryBackup(
          manga: [
            ForeignManga(
              backupSourceId: '2499283573021220255',
              sourceName: 'MangaDex',
              manga: Manga(
                id: 0,
                name: 'One Piece',
                url: '/title/op',
                sourceId: '2499283573021220255',
                inLibrary: true,
                createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              ),
              chapters: [
                MangaChapter(
                  id: 0,
                  mangaId: 0,
                  name: 'Chapter 1',
                  url: '/ch/1',
                  index: 0,
                  isRead: true,
                  lastPageRead: 7,
                  dateUpload: 1700000000000,
                ),
              ],
            ),
          ],
        ),
        gzip: true,
      );
      expect(encoded[0], 0x1f);
      final decoded = decodeMihonBackup(encoded);
      expect(decoded.manga, hasLength(1));
      expect(decoded.manga.first.manga.inLibrary, isTrue);
      expect(decoded.manga.first.manga.name, 'One Piece');
      expect(
        decoded.manga.first.manga.createdAt.millisecondsSinceEpoch,
        1700000000000,
      );
      expect(decoded.manga.first.chapters.first.isRead, isTrue);
      expect(decoded.manga.first.chapters.first.lastPageRead, 7);
      expect(decoded.manga.first.chapters.first.dateUpload, 1700000000000);
    });

    test('explicit favorite false stays out of library', () {
      final encoded = encodeMihonBackup(
        ForeignLibraryBackup(
          manga: [
            ForeignManga(
              backupSourceId: '1',
              manga: Manga(
                id: 0,
                name: 'Read later',
                url: '/x',
                sourceId: '1',
                inLibrary: false,
              ),
              chapters: const [],
            ),
          ],
        ),
        gzip: false,
      );
      final decoded = decodeMihonBackup(encoded);
      expect(decoded.manga.first.manga.inLibrary, isFalse);
    });
  });

  group('Mangayomi JSON', () {
    test('maps link, status, skips anime', () {
      final json = {
        'version': '2',
        'manga': [
          {
            'id': 1,
            'name': 'Title',
            'link': '/manga/1',
            'favorite': true,
            'sourceId': 99,
            'source': 'Foo',
            'itemType': 0,
            'status': 1,
            'genre': ['a'],
            'dateAdded': 1700000000000,
          },
          {
            'id': 2,
            'name': 'Show',
            'link': '/anime/1',
            'favorite': true,
            'sourceId': 1,
            'itemType': 1,
            'status': 0,
          },
        ],
        'chapters': [
          {
            'id': 10,
            'mangaId': 1,
            'name': 'Ch 1',
            'url': '/c/1',
            'isRead': true,
            'lastPageRead': '3',
            'dateUpload': '1700000000000',
            'isBookmarked': false,
          },
        ],
        'history': [
          {'chapterId': 10, 'date': '1700001111000', 'mangaId': 1, 'itemType': 0},
        ],
      };
      final decoded = decodeMangayomiBackup(utf8.encode(jsonEncode(json)));
      expect(decoded.skippedAnime, 1);
      expect(decoded.manga, hasLength(1));
      expect(decoded.manga.first.manga.url, '/manga/1');
      expect(decoded.manga.first.manga.status, SMangaStatus.completed);
      expect(decoded.manga.first.chapters.first.lastPageRead, 3);
      expect(decoded.manga.first.chapters.first.readAt, isNotNull);
    });
  });

  group('BackupImporter', () {
    test('merges mihon library into empty db', () async {
      SharedPreferences.setMockInitialValues({});
      final repos = await createTestRepositories();
      addTearDown(() => repos.isar.close());

      final encoded = encodeMihonBackup(
        ForeignLibraryBackup(
          categories: [LibraryCategory(id: 1, name: 'Shonen', order: 2)],
          manga: [
            ForeignManga(
              backupSourceId: '9',
              sourceName: 'Missing Source',
              manga: Manga(
                id: 0,
                name: 'Naruto',
                url: '/n',
                sourceId: '9',
                inLibrary: true,
                categoryIds: const [2],
              ),
              chapters: [
                MangaChapter(
                  id: 0,
                  mangaId: 0,
                  name: 'Ch 1',
                  url: '/n/1',
                  index: 0,
                  isRead: true,
                ),
              ],
            ),
          ],
        ),
      );

      final result = await ExportService(repos).importBytes(
        encoded,
        filename: 'app.mihon_2026-01-01.tachibk',
      );
      expect(result.mangaImported, 1);
      expect(result.mangaChaptersImported, 1);
      expect(result.missingSources, contains('Missing Source'));

      final mangas = await repos.manga.getMangasInLibrary();
      expect(mangas.single.name, 'Naruto');
      expect(mangas.single.categoryIds, isNotEmpty);
    });

    test('mangayomi zip import skips anime', () async {
      SharedPreferences.setMockInitialValues({});
      final repos = await createTestRepositories();
      addTearDown(() => repos.isar.close());

      final json = jsonEncode({
        'version': '2',
        'manga': [
          {
            'id': 1,
            'name': 'Manga',
            'link': '/m',
            'favorite': true,
            'sourceId': 5,
            'itemType': 0,
            'status': 0,
          },
        ],
        'chapters': <Map<String, dynamic>>[],
      });
      final archive = Archive()
        ..addFile(
          ArchiveFile(
            'mangayomi_test.backup.db',
            json.length,
            utf8.encode(json),
          ),
        );
      final zip = ZipEncoder().encode(archive);

      final result = await BackupImporter(repos).importForeign(
        decodeMangayomiBackup(Uint8List.fromList(zip)),
      );
      expect(result.mangaImported, 1);
      final mangas = await repos.manga.getMangasInLibrary();
      expect(mangas.single.url, '/m');
      expect(mangas.single.status, SMangaStatus.ongoing);
    });
  });
}

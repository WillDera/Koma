import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/models/manga_chapter.dart';
import 'package:koma/core/utils/chapter_language.dart';

void main() {
  MangaChapter ch(String name, {String url = '', String? scanlator}) =>
      MangaChapter(
        id: 0,
        mangaId: 1,
        name: name,
        url: url.isEmpty ? '/$name' : url,
        index: 0,
        scanlator: scanlator,
      );

  group('detectInText', () {
    test('full language names', () {
      expect(ChapterLanguage.detectInText('Chapter 1 - English'), 'en');
      expect(ChapterLanguage.detectInText('Capítulo 1 Español'), 'es');
      expect(ChapterLanguage.detectInText('Chapitre 1 Français'), 'fr');
    });

    test('bracket and separator codes', () {
      expect(ChapterLanguage.detectInText('Chapter 1 [EN]'), 'en');
      expect(ChapterLanguage.detectInText('Chapter 1 (ES)'), 'es');
      expect(ChapterLanguage.detectInText('Chapter 1-fr'), 'fr');
      expect(ChapterLanguage.detectInText('Ch. 2 / pt-br'), 'pt');
    });

    test('no false positive on ordinary titles', () {
      expect(ChapterLanguage.detectInText('Chapter 10'), isNull);
      expect(ChapterLanguage.detectInText('The End'), isNull);
    });
  });

  group('next / previous', () {
    late List<MangaChapter> order;

    setUp(() {
      // Reading order: oldest → newest (as manga reader sorts).
      order = [
        ch('Chapter 1 - English', url: '/1-en'),
        ch('Chapter 1 - Spanish', url: '/1-es'),
        ch('Chapter 1 - French', url: '/1-fr'),
        ch('Chapter 2 - English', url: '/2-en'),
        ch('Chapter 2 - Spanish', url: '/2-es'),
        ch('Chapter 2 - French', url: '/2-fr'),
        ch('Chapter 3 - English', url: '/3-en'),
      ];
    });

    test('from English ch1 skips other languages to English ch2', () {
      final next = ChapterLanguage.next(order, order[0]);
      expect(next?.url, '/2-en');
    });

    test('from Spanish ch1 goes to Spanish ch2', () {
      final next = ChapterLanguage.next(order, order[1]);
      expect(next?.url, '/2-es');
    });

    test('previous from English ch2 returns English ch1', () {
      final prev = ChapterLanguage.previous(order, order[3]);
      expect(prev?.url, '/1-en');
    });

    test('unlabeled chapters keep sequential navigation', () {
      final plain = [
        ch('Chapter 1', url: '/1'),
        ch('Chapter 2', url: '/2'),
        ch('Chapter 3', url: '/3'),
      ];
      expect(ChapterLanguage.next(plain, plain[0])?.url, '/2');
      expect(ChapterLanguage.previous(plain, plain[2])?.url, '/2');
    });

    test('scanlator language is used when name has none', () {
      final mixed = [
        ch('Chapter 1', url: '/1', scanlator: 'English'),
        ch('Chapter 1', url: '/1b', scanlator: 'Spanish'),
        ch('Chapter 2', url: '/2', scanlator: 'English'),
      ];
      expect(ChapterLanguage.next(mixed, mixed[0])?.url, '/2');
    });
  });
}

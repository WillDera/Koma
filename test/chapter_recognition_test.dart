import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/utils/chapter_recognition.dart';

void main() {
  test('trusts source chapter number when set', () {
    expect(
      ChapterRecognition.parseChapterNumber('Title', 'Ch. 1', 12.5),
      12.5,
    );
    expect(
      ChapterRecognition.parseChapterNumber('Title', 'whatever', -2),
      -2,
    );
  });

  test('parses Ch.xx from name', () {
    expect(
      ChapterRecognition.parseChapterNumber(
        'Mokushiroku Alice',
        'Mokushiroku Alice Vol.1 Ch. 4: Misrepresentation',
      ),
      4.0,
    );
  });

  test('parses lone number after stripping title', () {
    expect(
      ChapterRecognition.parseChapterNumber('Bleach', 'Bleach 567: Down With Snowwhite'),
      567.0,
    );
  });

  test('unknown returns -1', () {
    expect(
      ChapterRecognition.parseChapterNumber('X', 'Prologue'),
      -1.0,
    );
  });

  test('sub-chapters and language variants share a major number', () {
    expect(
      ChapterRecognition.majorFromName('Title', 'Chapter 1.1'),
      1,
    );
    expect(
      ChapterRecognition.majorFromName('Title', 'Chapter 1.2'),
      1,
    );
    expect(
      ChapterRecognition.majorFromName('Title', 'Chapter 1-english'),
      1,
    );
    expect(
      ChapterRecognition.majorFromName('Title', 'Chapter 1-spanish'),
      1,
    );
    expect(
      ChapterRecognition.majorFromName('Title', 'Ch. 12.5'),
      12,
    );
  });

  test('parseFromName ignores misleading source indexes', () {
    // Source may number language variants 1, 2, 3 — name still says ch.1.
    expect(
      ChapterRecognition.parseFromName('Title', 'Chapter 1 - English'),
      1.0,
    );
    expect(
      ChapterRecognition.majorChapterNumber(
        ChapterRecognition.parseChapterNumber('Title', 'Ch. 1.5', 99),
      ),
      99, // trusted source number when provided
    );
    expect(
      ChapterRecognition.majorFromName('Title', 'Ch. 1.5'),
      1,
    );
  });
}

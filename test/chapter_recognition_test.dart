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
}

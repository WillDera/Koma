import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/utils/chapter_recognition.dart';

void main() {
  test('sub-chapters and language variants collapse to one major', () {
    final names = [
      'Chapter 1',
      'Chapter 1.1',
      'Chapter 1.2',
      'Chapter 1-english',
      'Chapter 2',
      'Chapter 2.5',
    ];
    final majors = <int>{};
    for (final name in names) {
      final m = ChapterRecognition.majorFromName('Series', name);
      if (m != null) majors.add(m);
    }
    expect(majors, {1, 2});
  });

  test('name parse ignores misleading source-style indexes', () {
    final names = [
      'Ch. 1 - EN',
      'Ch. 1 - ES',
      'Ch. 1.5',
    ];
    final majors = <int>{};
    double? maxN;
    for (final name in names) {
      final n = ChapterRecognition.parseFromName('Book', name);
      if (!ChapterRecognition.isRecognized(n)) continue;
      majors.add(n.floor());
      if (maxN == null || n > maxN) maxN = n;
    }
    expect(majors.length, 1);
    expect(majors.single, 1);
    expect(maxN, 1.5);
  });
}

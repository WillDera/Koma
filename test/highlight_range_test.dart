import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/models/highlight.dart';
import 'package:koma/features/reader/pagination/highlight_range.dart';

void main() {
  Highlight hl(int start, int end) => Highlight(
    id: start,
    bookId: 1,
    chapterId: 1,
    startOffset: start,
    endOffset: end,
    text: '',
  );

  test('returns marks that overlap the selection', () {
    final marks = [hl(0, 10), hl(20, 30)];
    expect(
      highlightsOverlapping(marks, start: 8, end: 12).map((h) => h.id),
      [0],
    );
    expect(
      highlightsOverlapping(marks, start: 10, end: 20),
      isEmpty,
    );
    expect(
      highlightsOverlapping(marks, start: 5, end: 25).map((h) => h.id),
      [0, 20],
    );
  });

  test('empty or inverted ranges match nothing', () {
    expect(highlightsOverlapping([hl(0, 10)], start: 4, end: 4), isEmpty);
    expect(highlightsOverlapping([hl(0, 10)], start: 8, end: 2), isEmpty);
  });
}

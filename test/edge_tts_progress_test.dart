import 'package:flutter_test/flutter_test.dart';
import 'package:koma/features/reader/tts/tts_engine.dart';

// Mirror of EdgeTtsEngine._normalizeWord / resolve logic for unit coverage.
String _normalizeWord(String word) {
  return word
      .toLowerCase()
      .replaceAll(RegExp(r"[^\p{L}\p{N}']+", unicode: true), '');
}

void resolveCharOffsets(
  List<WordTimestamp> timestamps,
  String text,
  int baseOffset,
) {
  if (timestamps.isEmpty) return;
  final tokens = <({int start, String norm})>[];
  for (final m in RegExp(r'\S+').allMatches(text)) {
    final raw = m.group(0)!;
    final norm = _normalizeWord(raw);
    if (norm.isEmpty) continue;
    tokens.add((start: m.start, norm: norm));
  }
  if (tokens.isEmpty) return;
  var tokenIndex = 0;
  for (var wi = 0; wi < timestamps.length; wi++) {
    final want = _normalizeWord(timestamps[wi].word);
    var found = -1;
    if (want.isNotEmpty) {
      for (var j = tokenIndex; j < tokens.length; j++) {
        final have = tokens[j].norm;
        if (have == want || have.startsWith(want) || want.startsWith(have)) {
          found = j;
          break;
        }
      }
    }
    if (found < 0) {
      final approx = (wi * tokens.length / timestamps.length)
          .floor()
          .clamp(0, tokens.length - 1);
      found = approx < tokenIndex ? tokenIndex.clamp(0, tokens.length - 1) : approx;
    }
    timestamps[wi] = WordTimestamp(
      timestamps[wi].word,
      timestamps[wi].time,
      baseOffset + tokens[found].start,
    );
    tokenIndex = (found + 1).clamp(0, tokens.length);
  }
}

void main() {
  test('maps punctuated chapter words to Edge boundary words', () {
    const text = 'Hello, world! She said—yes.';
    final stamps = [
      WordTimestamp('Hello', const Duration(milliseconds: 0), 0),
      WordTimestamp('world', const Duration(milliseconds: 200), 0),
      WordTimestamp('She', const Duration(milliseconds: 400), 0),
      WordTimestamp('said', const Duration(milliseconds: 600), 0),
      WordTimestamp('yes', const Duration(milliseconds: 800), 0),
    ];
    resolveCharOffsets(stamps, text, 100);
    expect(stamps[0].charOffset, 100);
    expect(stamps[1].charOffset, greaterThan(stamps[0].charOffset));
    expect(stamps[2].charOffset, greaterThan(stamps[1].charOffset));
    expect(text.substring(stamps[0].charOffset - 100).startsWith('Hello'), isTrue);
  });
}

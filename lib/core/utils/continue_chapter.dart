import '../models/manga_chapter.dart';
import 'chapter_recognition.dart';

/// Resume the furthest chapter in the user's real reading run.
///
/// Progress is clustered by chapter number so a stray open of the latest
/// release cannot override having read through an earlier contiguous streak.
MangaChapter continueReadTargetChapter(
  List<MangaChapter> chapters, {
  String? mangaTitle,
}) {
  assert(chapters.isNotEmpty);
  final title = mangaTitle ?? '';

  double numberOf(MangaChapter ch) {
    if (ch.isRecognizedNumber && ch.chapterNumber >= 0) {
      return ch.chapterNumber;
    }
    return ChapterRecognition.parseFromName(title, ch.name);
  }

  final progressed = <MangaChapter>[
    for (final ch in chapters)
      if (ch.isRead ||
          ch.lastPageRead > 0 ||
          ch.scrollPosition > 0 ||
          ch.readAt != null)
        ch,
  ];

  if (progressed.isEmpty) {
    return _chapterOne(chapters, title);
  }

  final ranked = [...progressed]..sort((a, b) {
      final na = numberOf(a);
      final nb = numberOf(b);
      final aOk = ChapterRecognition.isRecognized(na);
      final bOk = ChapterRecognition.isRecognized(nb);
      if (aOk && bOk && na != nb) return na.compareTo(nb);
      if (aOk && !bOk) return -1;
      if (!aOk && bOk) return 1;
      return a.index.compareTo(b.index);
    });

  var bestStart = 0;
  var bestLen = 1;
  var runStart = 0;
  for (var i = 1; i < ranked.length; i++) {
    final prev = numberOf(ranked[i - 1]);
    final cur = numberOf(ranked[i]);
    final contiguous = ChapterRecognition.isRecognized(prev) &&
        ChapterRecognition.isRecognized(cur) &&
        (cur - prev) <= 1.5 &&
        (cur - prev) >= -0.01;
    final indexContiguous = !ChapterRecognition.isRecognized(prev) &&
        !ChapterRecognition.isRecognized(cur) &&
        (ranked[i].index - ranked[i - 1].index).abs() <= 1;
    if (contiguous || indexContiguous) {
      final len = i - runStart + 1;
      if (len > bestLen) {
        bestLen = len;
        bestStart = runStart;
      }
    } else {
      runStart = i;
      if (1 > bestLen) {
        bestLen = 1;
        bestStart = i;
      }
    }
  }
  final runEnd = bestStart + bestLen - 1;
  final run = ranked.sublist(bestStart, runEnd + 1);

  MangaChapter frontier = run.first;
  var frontierNum = numberOf(frontier);
  var anyNumbered = ChapterRecognition.isRecognized(frontierNum);
  for (final ch in run.skip(1)) {
    final n = numberOf(ch);
    if (ChapterRecognition.isRecognized(n)) {
      if (!anyNumbered || n >= frontierNum) {
        frontier = ch;
        frontierNum = n;
        anyNumbered = true;
      }
    }
  }
  if (!anyNumbered) {
    final sample = [
      for (final ch in chapters)
        if (ChapterRecognition.isRecognized(numberOf(ch))) ch,
    ]..sort((a, b) => a.index.compareTo(b.index));
    final newestFirst = sample.length >= 2 &&
        numberOf(sample.first) > numberOf(sample.last);
    frontier = newestFirst
        ? run.reduce((a, b) => a.index <= b.index ? a : b)
        : run.reduce((a, b) => a.index >= b.index ? a : b);
  }

  if (frontier.isRead) {
    final frontierN = numberOf(frontier);
    MangaChapter? next;
    for (final ch in chapters) {
      if (ch.isRead) continue;
      if (ch.lastPageRead <= 0 && ch.scrollPosition <= 0) continue;
      final n = numberOf(ch);
      if (!ChapterRecognition.isRecognized(frontierN) ||
          !ChapterRecognition.isRecognized(n)) {
        continue;
      }
      final gap = n - frontierN;
      if (gap >= -0.01 && gap <= 1.01) {
        if (next == null || n >= numberOf(next)) next = ch;
      }
    }
    if (next != null) return next;
  }
  return frontier;
}

MangaChapter _chapterOne(List<MangaChapter> chapters, String mangaTitle) {
  MangaChapter? best;
  var bestNum = double.infinity;
  for (final ch in chapters) {
    var n = ch.isRecognizedNumber && ch.chapterNumber >= 0
        ? ch.chapterNumber
        : ChapterRecognition.parseFromName(mangaTitle, ch.name);
    if (!ChapterRecognition.isRecognized(n) || n <= 0) continue;
    if (n < bestNum) {
      bestNum = n;
      best = ch;
    }
  }
  if (best != null) return best;

  final numbered = [
    for (final ch in chapters)
      if (ch.isRecognizedNumber && ch.chapterNumber >= 0) ch,
  ]..sort((a, b) => a.index.compareTo(b.index));
  final indexFollowsNumber = numbered.length < 2 ||
      numbered.first.chapterNumber <= numbered.last.chapterNumber;
  if (indexFollowsNumber) {
    return chapters.reduce((a, b) => a.index <= b.index ? a : b);
  }
  return chapters.reduce((a, b) => a.index >= b.index ? a : b);
}

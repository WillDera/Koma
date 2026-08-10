import '../core/models/chapter.dart';

int? savedChapterId(List<Chapter> chapters, int currentChapterIndex) {
  if (chapters.isEmpty) return null;
  final position = currentChapterIndex.clamp(0, chapters.length - 1);
  return chapters[position].id;
}

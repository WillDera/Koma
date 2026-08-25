/// Mihon SManga status ints used by Koma's manga-detail labels.
class SMangaStatus {
  static const unknown = 0;
  static const ongoing = 1;
  static const completed = 2;
  static const licensed = 3;
  static const publishingFinished = 4;
  static const cancelled = 5;
  static const onHiatus = 6;
}

/// Mangayomi `Status.index` → Mihon [SMangaStatus].
int mangayomiStatusToSManga(int index) {
  return switch (index) {
    0 => SMangaStatus.ongoing,
    1 => SMangaStatus.completed,
    2 => SMangaStatus.cancelled,
    3 => SMangaStatus.unknown,
    4 => SMangaStatus.onHiatus,
    5 => SMangaStatus.publishingFinished,
    _ => SMangaStatus.unknown,
  };
}

int readingStatusFromChapters({
  required int readCount,
  required int total,
}) {
  if (total <= 0 || readCount <= 0) return 0;
  if (readCount >= total) return 2;
  return 1;
}

/// Publication status used by Dart extension bridges (`MStatus` enum).
///
/// Mirrored from mangayomi `models/manga.dart` Status — kept as a lean eval
/// model so bridges don't depend on Isar manga collections.
enum Status {
  ongoing,
  completed,
  canceled,
  unknown,
  onHiatus,
  publishingFinished,
}

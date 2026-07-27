import '../reader_settings_sheet.dart';
import '../../../core/models/manga_chapter.dart';

/// Mixin that provides per-chapter reader setting overrides. Each chapter
/// can remember its own crop-borders, rotation, zoom-crop, double-page,
/// and reading-direction overrides, falling back to global settings.
///
/// Mirrors mangayomi's per-chapter setting persistence pattern.
mixin class ChapterReaderSettingsMixin {
  final Map<int, ReaderSettings> _chapterOverrides = {};

  ReaderSettings settingsForChapter(
    MangaChapter? chapter,
    ReaderSettings globalSettings,
  ) {
    if (chapter == null) return globalSettings;
    return _chapterOverrides[chapter.id] ?? globalSettings;
  }

  void applyChapterSetting(MangaChapter chapter, ReaderSettings overrides) {
    final existing = _chapterOverrides[chapter.id] ?? ReaderSettings();
    _chapterOverrides[chapter.id] = ReaderSettings(
      readingMode: overrides.readingMode,
      rotationMode: overrides.rotationMode != RotationMode.free
          ? overrides.rotationMode
          : existing.rotationMode,
      tapZones: overrides.tapZones != TapZoneMode.leftRight
          ? overrides.tapZones
          : existing.tapZones,
      sidePadding: overrides.sidePadding,
      cropBorders: overrides.cropBorders,
      bookMode: overrides.bookMode,
      disableDoubleTap: overrides.disableDoubleTap,
      disableZoomOut: overrides.disableZoomOut,
      showPageNumber: overrides.showPageNumber,
      showPageNavigator: overrides.showPageNavigator,
      fullscreen: overrides.fullscreen,
      keepScreenOn: overrides.keepScreenOn,
      showActionsOnLongTap: overrides.showActionsOnLongTap,
      animatePageTransition: overrides.animatePageTransition,
      progressBarPlacement: overrides.progressBarPlacement,
      brightness: overrides.brightness,
      contrast: overrides.contrast,
      saturation: overrides.saturation,
      tintColor: overrides.tintColor,
      tintOpacity: overrides.tintOpacity,
    );
  }

  void clearChapterSetting(MangaChapter chapter) {
    _chapterOverrides.remove(chapter.id);
  }

  void clearAllChapterSettings() {
    _chapterOverrides.clear();
  }

  bool hasChapterOverride(MangaChapter chapter) {
    return _chapterOverrides.containsKey(chapter.id);
  }

  void dispose() {
    _chapterOverrides.clear();
  }
}

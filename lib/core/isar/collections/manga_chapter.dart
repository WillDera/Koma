import 'package:isar_community/isar.dart';

part 'manga_chapter.g.dart';

@collection
@Name('MangaChapter')
class MangaChapter {
  Id? id;

  @Index() // hot lookup: chapters of a manga (by mangaId)
  int mangaId;

  String name;

  @Index() // hot lookup: getPageList by chapterUrl
  String url;

  String? scanlator;

  /// Epoch millis — mirrors existing `date_upload INTEGER NOT NULL DEFAULT 0`.
  int dateUpload;

  /// 0-based position within the parent manga.
  int index;

  bool isRead;
  int lastPageRead;
  double scrollPosition;

  /// Mihon `chapterNumber` — recognized reading order key for migrate / sort.
  /// `-1` means unrecognized (see [ChapterRecognition]).
  double chapterNumber;

  /// Mihon chapter bookmark (not ebook page bookmarks).
  bool isBookmarked;

  /// Set by the native downloader / future JS downloader. Phase 7 replaced
  /// the `getDownloadedChapterKeys()` MethodChannel round-trip with a direct
  /// Isar query; this flag is now the canonical source of truth.
  bool isDownloaded;

  /// First-open marker (mangayomi parity — drives the "new" badge).
  bool isOpened;

  DateTime? readAt;

  /// Raw JSON of the source-side `SChapter.memo` (e.g. allanime
  /// `{"mangaId":..., "mangaSlug":...}`). Opaque to the UI — round-tripped
  /// back to the Dalvik server so `getPageList` can resolve image URLs for
  /// sources that derive them from memo.
  String? memo;

  MangaChapter({
    this.id = Isar.autoIncrement,
    required this.mangaId,
    required this.name,
    required this.url,
    this.scanlator,
    this.dateUpload = 0,
    required this.index,
    this.isRead = false,
    this.lastPageRead = 0,
    this.scrollPosition = 0.0,
    this.chapterNumber = -1,
    this.isBookmarked = false,
    this.isDownloaded = false,
    this.isOpened = false,
    this.readAt,
    this.memo,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'manga_id': mangaId,
    'name': name,
    'url': url,
    'scanlator': scanlator,
    'date_upload': dateUpload,
    'index': index,
    'is_read': isRead ? 1 : 0,
    'last_page_read': lastPageRead,
    'scroll_position': scrollPosition,
    'chapter_number': chapterNumber,
    'is_bookmarked': isBookmarked ? 1 : 0,
    'is_downloaded': isDownloaded ? 1 : 0,
    'is_opened': isOpened ? 1 : 0,
    'read_at': readAt?.toIso8601String(),
    'memo': memo,
  };

  factory MangaChapter.fromJson(Map<String, dynamic> json) => MangaChapter(
    id: json['id'] as int?,
    mangaId: json['manga_id'] as int? ?? 0,
    name: json['name'] as String? ?? '',
    url: json['url'] as String? ?? '',
    scanlator: json['scanlator'] as String?,
    dateUpload: json['date_upload'] as int? ?? 0,
    index: json['index'] as int? ?? 0,
    isRead: (json['is_read'] as int? ?? 0) == 1,
    lastPageRead: json['last_page_read'] as int? ?? 0,
    scrollPosition: (json['scroll_position'] as num?)?.toDouble() ?? 0.0,
    chapterNumber: (json['chapter_number'] as num?)?.toDouble() ?? -1,
    isBookmarked: (json['is_bookmarked'] as int? ?? 0) == 1,
    isDownloaded: (json['is_downloaded'] as int? ?? 0) == 1,
    isOpened: (json['is_opened'] as int? ?? 0) == 1,
    readAt: json['read_at'] != null
        ? DateTime.parse(json['read_at'] as String)
        : null,
    memo: json['memo'] as String?,
  );
}

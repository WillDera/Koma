import '../utils/chapter_recognition.dart';

class MangaChapter {
  final int id;
  final int mangaId;
  final String name;
  final String url;
  final String? scanlator;
  final int dateUpload;
  final int index;
  final bool isRead;
  final int lastPageRead;
  final double scrollPosition;
  final double chapterNumber;
  final bool isBookmarked;
  final bool isDownloaded;
  final bool isOpened;
  final DateTime? readAt;

  /// Raw JSON of the source-side `SChapter.memo` — round-tripped back to the
  /// Dalvik server so `getPageList` can resolve image URLs for sources that
  /// derive them from memo (e.g. allanime).
  final String? memo;

  bool get isRecognizedNumber =>
      ChapterRecognition.isRecognized(chapterNumber);

  MangaChapter({
    required this.id,
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

  /// Build a chapter with [chapterNumber] resolved via [ChapterRecognition].
  factory MangaChapter.withRecognition({
    required int id,
    required int mangaId,
    required String mangaTitle,
    required String name,
    required String url,
    String? scanlator,
    int dateUpload = 0,
    required int index,
    bool isRead = false,
    int lastPageRead = 0,
    double scrollPosition = 0.0,
    num? sourceChapterNumber,
    bool isBookmarked = false,
    bool isDownloaded = false,
    bool isOpened = false,
    DateTime? readAt,
    String? memo,
  }) {
    return MangaChapter(
      id: id,
      mangaId: mangaId,
      name: name,
      url: url,
      scanlator: scanlator,
      dateUpload: dateUpload,
      index: index,
      isRead: isRead,
      lastPageRead: lastPageRead,
      scrollPosition: scrollPosition,
      chapterNumber: ChapterRecognition.parseChapterNumber(
        mangaTitle,
        name,
        sourceChapterNumber?.toDouble(),
      ),
      isBookmarked: isBookmarked,
      isDownloaded: isDownloaded,
      isOpened: isOpened,
      readAt: readAt,
      memo: memo,
    );
  }

  MangaChapter copyWith({
    int? id,
    int? mangaId,
    String? name,
    String? url,
    String? scanlator,
    int? dateUpload,
    int? index,
    bool? isRead,
    int? lastPageRead,
    double? scrollPosition,
    double? chapterNumber,
    bool? isBookmarked,
    bool? isDownloaded,
    bool? isOpened,
    DateTime? readAt,
    String? memo,
  }) {
    return MangaChapter(
      id: id ?? this.id,
      mangaId: mangaId ?? this.mangaId,
      name: name ?? this.name,
      url: url ?? this.url,
      scanlator: scanlator ?? this.scanlator,
      dateUpload: dateUpload ?? this.dateUpload,
      index: index ?? this.index,
      isRead: isRead ?? this.isRead,
      lastPageRead: lastPageRead ?? this.lastPageRead,
      scrollPosition: scrollPosition ?? this.scrollPosition,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isOpened: isOpened ?? this.isOpened,
      readAt: readAt ?? this.readAt,
      memo: memo ?? this.memo,
    );
  }

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
    id: json['id'] as int? ?? 0,
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

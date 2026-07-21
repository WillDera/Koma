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
  final bool isDownloaded;
  final bool isOpened;

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
    this.isDownloaded = false,
    this.isOpened = false,
  });

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
    bool? isDownloaded,
    bool? isOpened,
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
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isOpened: isOpened ?? this.isOpened,
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
        'is_downloaded': isDownloaded ? 1 : 0,
        'is_opened': isOpened ? 1 : 0,
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
        isDownloaded: (json['is_downloaded'] as int? ?? 0) == 1,
        isOpened: (json['is_opened'] as int? ?? 0) == 1,
      );
}

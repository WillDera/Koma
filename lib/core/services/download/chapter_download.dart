/// Mihon-faithful download job model for the chapter download queue.
///
/// Persistence key is [chapterKey] (`sourceId|chapterUrl`). Runtime status and
/// page progress are held in memory and mirrored to SharedPreferences via
/// [DownloadStore].

enum DownloadState {
  notDownloaded(0),
  queue(1),
  downloading(2),
  downloaded(3),
  error(4);

  const DownloadState(this.value);
  final int value;

  static DownloadState fromValue(int v) {
    return DownloadState.values.firstWhere(
      (e) => e.value == v,
      orElse: () => DownloadState.notDownloaded,
    );
  }
}

class ChapterDownload {
  ChapterDownload({
    required this.sourceId,
    required this.mangaUrl,
    required this.mangaTitle,
    required this.chapterUrl,
    required this.chapterName,
    this.chapterMemo = '',
    this.mangaMemo = '',
    this.mangaId,
    this.chapterId,
    this.chapterNumber,
    this.order = 0,
    this.status = DownloadState.queue,
    this.pagesDone = 0,
    this.pagesTotal = 0,
  });

  final String sourceId;
  final String mangaUrl;
  final String mangaTitle;
  final String chapterUrl;
  final String chapterName;
  /// Chapter-level source memo (e.g. AllAnime `{"mangaId":…}`). Mutable so
  /// we can hydrate after a chapter-list refresh.
  String chapterMemo;
  /// Manga-level memo (e.g. AllAnime slug) needed to refresh chapter lists.
  final String mangaMemo;
  final int? mangaId;
  final int? chapterId;
  final num? chapterNumber;
  int order;

  DownloadState status;
  int pagesDone;
  int pagesTotal;

  /// Stable prefs / dedupe key — equivalent to Mihon store key by chapter id,
  /// using URL when Isar ids are unavailable (browse-only titles).
  String get chapterKey => '$sourceId|$chapterUrl';

  double get progressFraction {
    if (pagesTotal <= 0) return 0;
    return (pagesDone / pagesTotal).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'sourceId': sourceId,
        'mangaUrl': mangaUrl,
        'mangaTitle': mangaTitle,
        'chapterUrl': chapterUrl,
        'chapterName': chapterName,
        'chapterMemo': chapterMemo,
        'mangaMemo': mangaMemo,
        'mangaId': mangaId,
        'chapterId': chapterId,
        'chapterNumber': chapterNumber,
        'order': order,
        'status': status.value,
        'pagesDone': pagesDone,
        'pagesTotal': pagesTotal,
      };

  factory ChapterDownload.fromJson(Map<String, dynamic> json) {
    return ChapterDownload(
      sourceId: json['sourceId'] as String? ?? '',
      mangaUrl: json['mangaUrl'] as String? ?? '',
      mangaTitle: json['mangaTitle'] as String? ?? '',
      chapterUrl: json['chapterUrl'] as String? ?? '',
      chapterName: json['chapterName'] as String? ?? '',
      chapterMemo: json['chapterMemo'] as String? ?? '',
      mangaMemo: json['mangaMemo'] as String? ?? '',
      mangaId: (json['mangaId'] as num?)?.toInt(),
      chapterId: (json['chapterId'] as num?)?.toInt(),
      chapterNumber: json['chapterNumber'] as num?,
      order: (json['order'] as num?)?.toInt() ?? 0,
      status: DownloadState.fromValue((json['status'] as num?)?.toInt() ?? 1),
      pagesDone: (json['pagesDone'] as num?)?.toInt() ?? 0,
      pagesTotal: (json['pagesTotal'] as num?)?.toInt() ?? 0,
    );
  }

  ChapterDownload copy() => ChapterDownload.fromJson(toJson());
}

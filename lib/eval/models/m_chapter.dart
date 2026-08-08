import '../../core/services/keiyoushi_service.dart';

class MChapter {
  final String url;
  final String name;
  final String? scanlator;
  final int dateUpload;
  final int chapterNumber;

  /// Opaque source memo (e.g. AllAnime `mangaId`) — round-tripped to getPageList.
  final String? memo;

  const MChapter({
    required this.url,
    required this.name,
    this.scanlator,
    this.dateUpload = 0,
    this.chapterNumber = 0,
    this.memo,
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'name': name,
    'scanlator': scanlator,
    'date_upload': dateUpload,
    'chapter_number': chapterNumber,
    'memo': memo,
  };

  factory MChapter.fromJson(Map<String, dynamic> json) => MChapter(
    // Mangayomi uses `url`; some sources also emit `link`.
    url: json['url'] as String? ?? json['link'] as String? ?? '',
    name: json['name'] as String? ?? '',
    scanlator: json['scanlator'] as String?,
    dateUpload: _dateUploadFromJson(json),
    chapterNumber: json['chapter_number'] as int? ??
        (json['chapterNumber'] is num
            ? (json['chapterNumber'] as num).toInt()
            : 0),
    memo: coerceMemoJson(json['memo']),
  );

  static int _dateUploadFromJson(Map<String, dynamic> json) {
    final raw = json['date_upload'] ?? json['dateUpload'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  factory MChapter.fromMap(Map<String, dynamic> map) => MChapter.fromJson(map);

  factory MChapter.fromDynamic(dynamic d) {
    if (d is Map<String, dynamic>) return MChapter.fromJson(d);
    if (d is Map) {
      return MChapter.fromJson(Map<String, dynamic>.from(d));
    }
    throw ArgumentError('Expected Map, got ${d.runtimeType}');
  }
}

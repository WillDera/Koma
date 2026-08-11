import '../../core/services/keiyoushi_service.dart';
import '../../core/utils/json_coerce.dart';

class MChapter {
  final String url;
  final String name;
  final String? scanlator;
  final int dateUpload;
  /// Source chapter number. `-1` = unset (Mihon `SChapter` default) so
  /// [ChapterRecognition] can parse from the chapter name.
  final int chapterNumber;

  /// Opaque source memo (e.g. AllAnime `mangaId`) — round-tripped to getPageList.
  final String? memo;

  const MChapter({
    required this.url,
    required this.name,
    this.scanlator,
    this.dateUpload = 0,
    this.chapterNumber = -1,
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
    dateUpload: asIntOr(json['date_upload'] ?? json['dateUpload']),
    chapterNumber:
        asInt(json['chapter_number'] ?? json['chapterNumber']) ?? -1,
    memo: coerceMemoJson(json['memo']),
  );

  factory MChapter.fromMap(Map<String, dynamic> map) => MChapter.fromJson(map);

  factory MChapter.fromDynamic(dynamic d) {
    if (d is Map<String, dynamic>) return MChapter.fromJson(d);
    if (d is Map) {
      return MChapter.fromJson(Map<String, dynamic>.from(d));
    }
    throw ArgumentError('Expected Map, got ${d.runtimeType}');
  }
}

class MChapter {
  final String url;
  final String name;
  final String? scanlator;
  final int dateUpload;
  final int chapterNumber;

  const MChapter({
    required this.url,
    required this.name,
    this.scanlator,
    this.dateUpload = 0,
    this.chapterNumber = 0,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'name': name,
        'scanlator': scanlator,
        'date_upload': dateUpload,
        'chapter_number': chapterNumber,
      };

  factory MChapter.fromJson(Map<String, dynamic> json) => MChapter(
        url: json['url'] as String? ?? '',
        name: json['name'] as String? ?? '',
        scanlator: json['scanlator'] as String?,
        dateUpload: json['date_upload'] as int? ?? 0,
        chapterNumber: json['chapter_number'] as int? ?? 0,
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

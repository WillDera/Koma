class SourcePreference {
  final String key;
  final String type;
  final String? defaultValue;
  final String? title;
  final String? summary;
  final List<String>? entries;
  final List<String>? entryValues;

  const SourcePreference({
    required this.key,
    required this.type,
    this.defaultValue,
    this.title,
    this.summary,
    this.entries,
    this.entryValues,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'type': type,
        'defaultValue': defaultValue,
        'title': title,
        'summary': summary,
        if (entries != null) 'entries': entries,
        if (entryValues != null) 'entryValues': entryValues,
      };

  factory SourcePreference.fromJson(Map<String, dynamic> json) => SourcePreference(
        key: json['key'] as String? ?? '',
        type: json['type'] as String? ?? 'switch',
        defaultValue: json['defaultValue'] as String?,
        title: json['title'] as String?,
        summary: json['summary'] as String?,
        entries: json['entries'] != null ? List<String>.from(json['entries'] as List) : null,
        entryValues: json['entryValues'] != null ? List<String>.from(json['entryValues'] as List) : null,
      );

  factory SourcePreference.fromDynamic(dynamic d) {
    if (d is Map<String, dynamic>) return SourcePreference.fromJson(d);
    if (d is Map) {
      return SourcePreference.fromJson(Map<String, dynamic>.from(d));
    }
    throw ArgumentError('Expected Map, got ${d.runtimeType}');
  }
}

class Source {
  final int id;
  final String name;
  final String tag;
  final String baseUrl;
  final bool enabled;
  final String? language;

  const Source({
    this.id = 0,
    required this.name,
    required this.tag,
    required this.baseUrl,
    this.enabled = true,
    this.language,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tag': tag,
        'base_url': baseUrl,
        'enabled': enabled ? 1 : 0,
        if (language != null) 'language': language,
      };

  factory Source.fromJson(Map<String, dynamic> json) => Source(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String,
        tag: json['tag'] as String? ?? '',
        baseUrl: json['base_url'] as String? ?? json['search_url'] as String? ?? '',
        enabled: (json['enabled'] as int? ?? 1) == 1,
        language: json['language'] as String?,
      );

  Source copyWith({
    int? id,
    String? name,
    String? tag,
    String? baseUrl,
    bool? enabled,
    String? language,
  }) =>
      Source(
        id: id ?? this.id,
        name: name ?? this.name,
        tag: tag ?? this.tag,
        baseUrl: baseUrl ?? this.baseUrl,
        enabled: enabled ?? this.enabled,
        language: language ?? this.language,
      );

  String get label => '$name ($tag)';
}


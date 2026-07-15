class ExtensionRepo {
  final int id;
  final String name;
  final String url;
  final bool enabled;
  final DateTime createdAt;

  ExtensionRepo({
    int? id,
    required this.name,
    required this.url,
    this.enabled = true,
    DateTime? createdAt,
  })  : id = id ?? 0,
        createdAt = createdAt ?? DateTime.now();

  ExtensionRepo copyWith({
    int? id,
    String? name,
    String? url,
    bool? enabled,
    DateTime? createdAt,
  }) {
    return ExtensionRepo(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'enabled': enabled ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory ExtensionRepo.fromJson(Map<String, dynamic> json) => ExtensionRepo(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        url: json['url'] as String? ?? '',
        enabled: (json['enabled'] as int? ?? 0) == 1,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
      );
}

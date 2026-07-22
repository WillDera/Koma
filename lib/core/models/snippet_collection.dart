class SnippetCollection {
  final int id;
  final String name;
  final String color;
  final DateTime createdAt;
  final DateTime updatedAt;

  SnippetCollection({
    required this.id,
    required this.name,
    this.color = '#FFD700',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  SnippetCollection copyWith({
    int? id,
    String? name,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SnippetCollection(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory SnippetCollection.fromJson(Map<String, dynamic> json) => SnippetCollection(
        id: json['id'] as int,
        name: json['name'] as String,
        color: json['color'] as String? ?? '#FFD700',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : DateTime.now(),
      );
}

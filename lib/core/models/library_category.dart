class LibraryCategory {
  final int id;
  final String name;
  final int order;
  final int flags;

  LibraryCategory({
    required this.id,
    required this.name,
    this.order = 0,
    this.flags = 0,
  });

  LibraryCategory copyWith({
    int? id,
    String? name,
    int? order,
    int? flags,
  }) {
    return LibraryCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
      flags: flags ?? this.flags,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'order': order,
    'flags': flags,
  };

  factory LibraryCategory.fromJson(Map<String, dynamic> json) =>
      LibraryCategory(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        order: (json['order'] as num?)?.toInt() ?? 0,
        flags: (json['flags'] as num?)?.toInt() ?? 0,
      );
}

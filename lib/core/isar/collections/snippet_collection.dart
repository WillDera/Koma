import 'package:isar_community/isar.dart';

part 'snippet_collection.g.dart';

@collection
@Name('SnippetCollection')
class SnippetCollection {
  Id? id;

  String name;

  /// Hex color string for the collection accent (e.g. '#FFD700').
  String color;

  DateTime? createdAt;
  DateTime? updatedAt;

  SnippetCollection({
    this.id = Isar.autoIncrement,
    required this.name,
    this.color = '#FFD700',
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory SnippetCollection.fromJson(Map<String, dynamic> json) =>
      SnippetCollection(
        id: json['id'] as int?,
        name: json['name'] as String,
        color: json['color'] as String? ?? '#FFD700',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );
}

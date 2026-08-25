import 'package:isar_community/isar.dart';

part 'library_category.g.dart';

/// User library category (Mihon/Mangayomi import + Koma backup).
@collection
@Name('LibraryCategory')
class LibraryCategory {
  Id? id;

  @Index(unique: true, replace: true)
  String name;

  /// Display order. Mihon `BackupManga.categories` points at this value.
  int order;

  /// Mihon category flags (library sort bits). Opaque to Koma UI.
  int flags;

  LibraryCategory({
    this.id = Isar.autoIncrement,
    required this.name,
    this.order = 0,
    this.flags = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'order': order,
    'flags': flags,
  };

  factory LibraryCategory.fromJson(Map<String, dynamic> json) =>
      LibraryCategory(
        id: json['id'] as int?,
        name: json['name'] as String? ?? '',
        order: (json['order'] as num?)?.toInt() ?? 0,
        flags: (json['flags'] as num?)?.toInt() ?? 0,
      );
}

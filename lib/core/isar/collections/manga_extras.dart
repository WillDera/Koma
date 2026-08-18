import 'package:isar_community/isar.dart';

part 'manga_extras.g.dart';

/// Sidecar for [Manga] fields that must not shift Isar property ids
/// (`categoryIds`, `notes`). One row per manga.
@collection
@Name('MangaExtras')
class MangaExtras {
  Id? id;

  @Index(unique: true, replace: true)
  int mangaId;

  /// [LibraryCategory] ids this title belongs to.
  List<int>? categoryIds;

  /// Mihon user notes.
  String? notes;

  /// Local override cover file path (app support dir).
  String? customCoverPath;

  MangaExtras({
    this.id = Isar.autoIncrement,
    required this.mangaId,
    this.categoryIds,
    this.notes,
    this.customCoverPath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'manga_id': mangaId,
    'category_ids': categoryIds ?? const <int>[],
    'notes': notes,
    'custom_cover_path': customCoverPath,
  };

  factory MangaExtras.fromJson(Map<String, dynamic> json) => MangaExtras(
    id: json['id'] as int?,
    mangaId: (json['manga_id'] as num?)?.toInt() ?? 0,
    categoryIds: (json['category_ids'] as List<dynamic>?)
        ?.map((e) => (e as num).toInt())
        .toList(),
    notes: json['notes'] as String?,
    customCoverPath: json['custom_cover_path'] as String?,
  );
}

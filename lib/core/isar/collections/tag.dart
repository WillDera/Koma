import 'package:isar_community/isar.dart';

part 'tag.g.dart';

/// Catalog of all tags the user has ever used. Per-snippet tag lists are
/// stored denormalized on [Snippet.tags]; this collection exists for
/// autocomplete + the tag-filter chips on the Snippets screen.
@collection
@Name('Tag')
class Tag {
  Id? id;

  @Index(unique: true, replace: true)
  String name;

  Tag({this.id = Isar.autoIncrement, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory Tag.fromJson(Map<String, dynamic> json) =>
      Tag(id: json['id'] as int?, name: json['name'] as String);
}

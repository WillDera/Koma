import 'package:isar_community/isar.dart';

part 'library_group.g.dart';

/// Named reading group of library books and/or manga.
///
/// Membership lives in [LibraryGroupMember]. A group must keep ≥2 members
/// or it is dissolved by the repository.
@collection
@Name('LibraryGroup')
class LibraryGroup {
  Id? id;

  String name;

  DateTime createdAt;

  DateTime updatedAt;

  LibraryGroup({
    this.id = Isar.autoIncrement,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });
}

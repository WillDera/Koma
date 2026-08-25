import 'package:isar_community/isar.dart';

part 'library_group_member.g.dart';

/// One book or manga inside a [LibraryGroup].
///
/// [memberKey] is unique (`b:<id>` / `m:<id>`) so an item can belong to
/// only one group at a time.
@collection
@Name('LibraryGroupMember')
class LibraryGroupMember {
  Id? id;

  @Index()
  int groupId;

  /// `book` or `manga`.
  String kind;

  int itemId;

  /// Stable unique key: `b:12` or `m:34`.
  @Index(unique: true, replace: true)
  String memberKey;

  /// Optional reading-order number within the group (unique when set).
  int? readingOrder;

  LibraryGroupMember({
    this.id = Isar.autoIncrement,
    required this.groupId,
    required this.kind,
    required this.itemId,
    required this.memberKey,
    this.readingOrder,
  });
}

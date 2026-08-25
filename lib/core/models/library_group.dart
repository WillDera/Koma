/// Domain view of a library reading group (not the Isar row).
class LibraryGroupInfo {
  const LibraryGroupInfo({
    required this.id,
    required this.name,
    required this.members,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final List<LibraryGroupMemberInfo> members;
  final DateTime updatedAt;

  bool get hasBooks => members.any((m) => m.isBook);
  bool get hasManga => members.any((m) => m.isManga);

  /// Members sorted by reading order (nulls last), then member key.
  List<LibraryGroupMemberInfo> get orderedMembers {
    final copy = List<LibraryGroupMemberInfo>.from(members);
    copy.sort((a, b) {
      final ao = a.readingOrder;
      final bo = b.readingOrder;
      if (ao != null && bo != null) return ao.compareTo(bo);
      if (ao != null) return -1;
      if (bo != null) return 1;
      return a.memberKey.compareTo(b.memberKey);
    });
    return copy;
  }
}

class LibraryGroupMemberInfo {
  const LibraryGroupMemberInfo({
    required this.id,
    required this.groupId,
    required this.kind,
    required this.itemId,
    required this.memberKey,
    this.readingOrder,
  });

  final int id;
  final int groupId;
  final String kind;
  final int itemId;
  final String memberKey;
  final int? readingOrder;

  bool get isBook => kind == 'book';
  bool get isManga => kind == 'manga';

  static String keyForBook(int id) => 'b:$id';
  static String keyForManga(int id) => 'm:$id';

  static (String kind, int itemId)? parseKey(String key) {
    if (key.startsWith('b:')) {
      final id = int.tryParse(key.substring(2));
      if (id == null) return null;
      return ('book', id);
    }
    if (key.startsWith('m:')) {
      final id = int.tryParse(key.substring(2));
      if (id == null) return null;
      return ('manga', id);
    }
    return null;
  }
}

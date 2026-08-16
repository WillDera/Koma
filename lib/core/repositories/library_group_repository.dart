import 'package:isar_community/isar.dart';

import '../isar/collections/library_group.dart' as i;
import '../isar/collections/library_group_member.dart' as i;
import '../models/library_group.dart';

class LibraryGroupRepository {
  LibraryGroupRepository(this._isar);

  final Isar _isar;

  Future<List<LibraryGroupInfo>> getAllGroups() async {
    final groups = await _isar.libraryGroups.where().findAll();
    final members = await _isar.libraryGroupMembers.where().findAll();
    final byGroup = <int, List<i.LibraryGroupMember>>{};
    for (final m in members) {
      byGroup.putIfAbsent(m.groupId, () => []).add(m);
    }
    final out = <LibraryGroupInfo>[];
    for (final g in groups) {
      final id = g.id;
      if (id == null) continue;
      final ms = byGroup[id] ?? const [];
      if (ms.length < 2) continue;
      out.add(
        LibraryGroupInfo(
          id: id,
          name: g.name,
          updatedAt: g.updatedAt,
          members: ms.map(_toMember).toList(growable: false),
        ),
      );
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  /// Creates a group with [memberKeys] (`b:` / `m:`). Requires ≥2 keys.
  /// Moves members out of any existing group first.
  Future<int> createGroup({
    required String name,
    required List<String> memberKeys,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Group name cannot be empty');
    }
    final unique = memberKeys.toSet().toList();
    if (unique.length < 2) {
      throw ArgumentError('A group needs at least 2 items');
    }
    for (final key in unique) {
      if (LibraryGroupMemberInfo.parseKey(key) == null) {
        throw ArgumentError('Invalid member key: $key');
      }
    }

    return _isar.writeTxn(() async {
      await _detachKeys(unique);
      final now = DateTime.now();
      final groupId = await _isar.libraryGroups.put(
        i.LibraryGroup(name: trimmed, createdAt: now, updatedAt: now),
      );
      for (final key in unique) {
        final parsed = LibraryGroupMemberInfo.parseKey(key)!;
        await _isar.libraryGroupMembers.put(
          i.LibraryGroupMember(
            groupId: groupId,
            kind: parsed.$1,
            itemId: parsed.$2,
            memberKey: key,
            // Reading order is optional until the user sets it.
            readingOrder: null,
          ),
        );
      }
      return groupId;
    });
  }

  Future<void> renameGroup(int groupId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _isar.writeTxn(() async {
      final g = await _isar.libraryGroups.get(groupId);
      if (g == null) return;
      g.name = trimmed;
      g.updatedAt = DateTime.now();
      await _isar.libraryGroups.put(g);
    });
  }

  Future<void> dissolveGroup(int groupId) async {
    await _isar.writeTxn(() async {
      await _deleteGroupTxn(groupId);
    });
  }

  /// Removes one member. Dissolves the group if fewer than 2 remain.
  Future<void> removeMember(String memberKey) async {
    await _isar.writeTxn(() async {
      final row = await _isar.libraryGroupMembers
          .where()
          .memberKeyEqualTo(memberKey)
          .findFirst();
      if (row == null) return;
      final groupId = row.groupId;
      await _isar.libraryGroupMembers.delete(row.id ?? 0);
      final remaining = await _isar.libraryGroupMembers
          .filter()
          .groupIdEqualTo(groupId)
          .findAll();
      if (remaining.length < 2) {
        await _deleteGroupTxn(groupId);
      } else {
        await _touchGroup(groupId);
      }
    });
  }

  /// Drop an item from any group (e.g. when deleting a book/manga).
  Future<void> removeItemEverywhere({
    required String kind,
    required int itemId,
  }) async {
    final key = kind == 'book'
        ? LibraryGroupMemberInfo.keyForBook(itemId)
        : LibraryGroupMemberInfo.keyForManga(itemId);
    await removeMember(key);
  }

  /// Assign [order] to [memberKey], shifting others that collide upward.
  Future<void> setReadingOrder(String memberKey, int order) async {
    if (order < 1) {
      await clearReadingOrder(memberKey);
      return;
    }
    await _isar.writeTxn(() async {
      final row = await _isar.libraryGroupMembers
          .where()
          .memberKeyEqualTo(memberKey)
          .findFirst();
      if (row == null) return;
      final siblings = await _isar.libraryGroupMembers
          .filter()
          .groupIdEqualTo(row.groupId)
          .findAll();
      for (final s in siblings) {
        if (s.memberKey == memberKey) continue;
        final o = s.readingOrder;
        if (o != null && o >= order) {
          s.readingOrder = o + 1;
          await _isar.libraryGroupMembers.put(s);
        }
      }
      row.readingOrder = order;
      await _isar.libraryGroupMembers.put(row);
      await _touchGroup(row.groupId);
    });
  }

  Future<void> clearReadingOrder(String memberKey) async {
    await _isar.writeTxn(() async {
      final row = await _isar.libraryGroupMembers
          .where()
          .memberKeyEqualTo(memberKey)
          .findFirst();
      if (row == null) return;
      row.readingOrder = null;
      await _isar.libraryGroupMembers.put(row);
      await _touchGroup(row.groupId);
    });
  }

  /// Reassign orders 1..n from [orderedKeys] (must be all members of one group).
  Future<void> reorderMembers(int groupId, List<String> orderedKeys) async {
    await _isar.writeTxn(() async {
      final siblings = await _isar.libraryGroupMembers
          .filter()
          .groupIdEqualTo(groupId)
          .findAll();
      if (siblings.length != orderedKeys.length) {
        throw ArgumentError('Reorder list must include every member');
      }
      final byKey = {for (final s in siblings) s.memberKey: s};
      for (var i = 0; i < orderedKeys.length; i++) {
        final row = byKey[orderedKeys[i]];
        if (row == null) {
          throw ArgumentError('Unknown member ${orderedKeys[i]}');
        }
        row.readingOrder = i + 1;
        await _isar.libraryGroupMembers.put(row);
      }
      await _touchGroup(groupId);
    });
  }

  Future<void> _detachKeys(List<String> keys) async {
    final affectedGroups = <int>{};
    for (final key in keys) {
      final row = await _isar.libraryGroupMembers
          .where()
          .memberKeyEqualTo(key)
          .findFirst();
      if (row == null) continue;
      affectedGroups.add(row.groupId);
      await _isar.libraryGroupMembers.delete(row.id ?? 0);
    }
    for (final gid in affectedGroups) {
      final remaining = await _isar.libraryGroupMembers
          .filter()
          .groupIdEqualTo(gid)
          .findAll();
      if (remaining.length < 2) {
        await _deleteGroupTxn(gid);
      } else {
        await _touchGroup(gid);
      }
    }
  }

  Future<void> _deleteGroupTxn(int groupId) async {
    final members = await _isar.libraryGroupMembers
        .filter()
        .groupIdEqualTo(groupId)
        .findAll();
    for (final m in members) {
      await _isar.libraryGroupMembers.delete(m.id ?? 0);
    }
    await _isar.libraryGroups.delete(groupId);
  }

  Future<void> _touchGroup(int groupId) async {
    final g = await _isar.libraryGroups.get(groupId);
    if (g == null) return;
    g.updatedAt = DateTime.now();
    await _isar.libraryGroups.put(g);
  }

  LibraryGroupMemberInfo _toMember(i.LibraryGroupMember m) =>
      LibraryGroupMemberInfo(
        id: m.id ?? 0,
        groupId: m.groupId,
        kind: m.kind,
        itemId: m.itemId,
        memberKey: m.memberKey,
        readingOrder: m.readingOrder,
      );
}

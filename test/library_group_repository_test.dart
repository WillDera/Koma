import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/models/library_group.dart';

import 'helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('create group requires 2+ members and persists', () async {
    final repos = await createTestRepositories();
    addTearDown(() => repos.isar.close());

    expect(
      () => repos.groups.createGroup(name: 'Solo', memberKeys: ['b:1']),
      throwsA(isA<ArgumentError>()),
    );

    final id = await repos.groups.createGroup(
      name: 'Eisenhorn',
      memberKeys: ['b:1', 'b:2', 'm:3'],
    );
    final groups = await repos.groups.getAllGroups();
    expect(groups, hasLength(1));
    expect(groups.first.id, id);
    expect(groups.first.name, 'Eisenhorn');
    expect(groups.first.members, hasLength(3));
    expect(
      groups.first.members.every((m) => m.readingOrder == null),
      isTrue,
    );
  });

  test('item can only belong to one group', () async {
    final repos = await createTestRepositories();
    addTearDown(() => repos.isar.close());

    await repos.groups.createGroup(
      name: 'A',
      memberKeys: ['b:1', 'b:2'],
    );
    await repos.groups.createGroup(
      name: 'B',
      memberKeys: ['b:2', 'b:3'],
    );
    final groups = await repos.groups.getAllGroups();
    // A dissolves (only b:1 left) when b:2 moves to B.
    expect(groups, hasLength(1));
    expect(groups.first.name, 'B');
    expect(
      groups.first.members.map((m) => m.memberKey).toSet(),
      {'b:2', 'b:3'},
    );
  });

  test('setReadingOrder auto-shifts collisions', () async {
    final repos = await createTestRepositories();
    addTearDown(() => repos.isar.close());

    await repos.groups.createGroup(
      name: 'Order',
      memberKeys: ['b:1', 'b:2', 'b:3'],
    );
    await repos.groups.setReadingOrder('b:1', 1);
    await repos.groups.setReadingOrder('b:2', 2);
    await repos.groups.setReadingOrder('b:3', 1);
    final g = (await repos.groups.getAllGroups()).first;
    final byKey = {for (final m in g.members) m.memberKey: m.readingOrder};
    expect(byKey['b:3'], 1);
    expect(byKey['b:1'], 2);
    expect(byKey['b:2'], 3);
  });

  test('parseKey helpers', () {
    expect(LibraryGroupMemberInfo.parseKey('b:12'), ('book', 12));
    expect(LibraryGroupMemberInfo.parseKey('m:9'), ('manga', 9));
    expect(LibraryGroupMemberInfo.parseKey('x:1'), isNull);
  });
}

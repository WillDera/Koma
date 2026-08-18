// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_group_member.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLibraryGroupMemberCollection on Isar {
  IsarCollection<LibraryGroupMember> get libraryGroupMembers =>
      this.collection();
}

const LibraryGroupMemberSchema = CollectionSchema(
  name: r'LibraryGroupMember',
  id: -2052519963578899260,
  properties: {
    r'groupId': PropertySchema(id: 0, name: r'groupId', type: IsarType.long),
    r'itemId': PropertySchema(id: 1, name: r'itemId', type: IsarType.long),
    r'kind': PropertySchema(id: 2, name: r'kind', type: IsarType.string),
    r'memberKey': PropertySchema(
      id: 3,
      name: r'memberKey',
      type: IsarType.string,
    ),
    r'readingOrder': PropertySchema(
      id: 4,
      name: r'readingOrder',
      type: IsarType.long,
    ),
  },

  estimateSize: _libraryGroupMemberEstimateSize,
  serialize: _libraryGroupMemberSerialize,
  deserialize: _libraryGroupMemberDeserialize,
  deserializeProp: _libraryGroupMemberDeserializeProp,
  idName: r'id',
  indexes: {
    r'groupId': IndexSchema(
      id: -8523216633229774932,
      name: r'groupId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'groupId',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'memberKey': IndexSchema(
      id: 4082400729976624266,
      name: r'memberKey',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'memberKey',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _libraryGroupMemberGetId,
  getLinks: _libraryGroupMemberGetLinks,
  attach: _libraryGroupMemberAttach,
  version: '3.3.2',
);

int _libraryGroupMemberEstimateSize(
  LibraryGroupMember object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.kind.length * 3;
  bytesCount += 3 + object.memberKey.length * 3;
  return bytesCount;
}

void _libraryGroupMemberSerialize(
  LibraryGroupMember object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.groupId);
  writer.writeLong(offsets[1], object.itemId);
  writer.writeString(offsets[2], object.kind);
  writer.writeString(offsets[3], object.memberKey);
  writer.writeLong(offsets[4], object.readingOrder);
}

LibraryGroupMember _libraryGroupMemberDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LibraryGroupMember(
    groupId: reader.readLong(offsets[0]),
    id: id,
    itemId: reader.readLong(offsets[1]),
    kind: reader.readString(offsets[2]),
    memberKey: reader.readString(offsets[3]),
    readingOrder: reader.readLongOrNull(offsets[4]),
  );
  return object;
}

P _libraryGroupMemberDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readLongOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _libraryGroupMemberGetId(LibraryGroupMember object) {
  return object.id ?? Isar.autoIncrement;
}

List<IsarLinkBase<dynamic>> _libraryGroupMemberGetLinks(
  LibraryGroupMember object,
) {
  return [];
}

void _libraryGroupMemberAttach(
  IsarCollection<dynamic> col,
  Id id,
  LibraryGroupMember object,
) {
  object.id = id;
}

extension LibraryGroupMemberByIndex on IsarCollection<LibraryGroupMember> {
  Future<LibraryGroupMember?> getByMemberKey(String memberKey) {
    return getByIndex(r'memberKey', [memberKey]);
  }

  LibraryGroupMember? getByMemberKeySync(String memberKey) {
    return getByIndexSync(r'memberKey', [memberKey]);
  }

  Future<bool> deleteByMemberKey(String memberKey) {
    return deleteByIndex(r'memberKey', [memberKey]);
  }

  bool deleteByMemberKeySync(String memberKey) {
    return deleteByIndexSync(r'memberKey', [memberKey]);
  }

  Future<List<LibraryGroupMember?>> getAllByMemberKey(
    List<String> memberKeyValues,
  ) {
    final values = memberKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'memberKey', values);
  }

  List<LibraryGroupMember?> getAllByMemberKeySync(
    List<String> memberKeyValues,
  ) {
    final values = memberKeyValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'memberKey', values);
  }

  Future<int> deleteAllByMemberKey(List<String> memberKeyValues) {
    final values = memberKeyValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'memberKey', values);
  }

  int deleteAllByMemberKeySync(List<String> memberKeyValues) {
    final values = memberKeyValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'memberKey', values);
  }

  Future<Id> putByMemberKey(LibraryGroupMember object) {
    return putByIndex(r'memberKey', object);
  }

  Id putByMemberKeySync(LibraryGroupMember object, {bool saveLinks = true}) {
    return putByIndexSync(r'memberKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByMemberKey(List<LibraryGroupMember> objects) {
    return putAllByIndex(r'memberKey', objects);
  }

  List<Id> putAllByMemberKeySync(
    List<LibraryGroupMember> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'memberKey', objects, saveLinks: saveLinks);
  }
}

extension LibraryGroupMemberQueryWhereSort
    on QueryBuilder<LibraryGroupMember, LibraryGroupMember, QWhere> {
  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterWhere>
  anyGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'groupId'),
      );
    });
  }
}

extension LibraryGroupMemberQueryWhere
    on QueryBuilder<LibraryGroupMember, LibraryGroupMember, QWhereClause> {
  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterWhereClause>
  idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterWhereClause>
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterWhereClause>
  groupIdEqualTo(int groupId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'groupId', value: [groupId]),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterWhereClause>
  groupIdNotEqualTo(int groupId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'groupId',
                lower: [],
                upper: [groupId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'groupId',
                lower: [groupId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'groupId',
                lower: [groupId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'groupId',
                lower: [],
                upper: [groupId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterWhereClause>
  groupIdGreaterThan(int groupId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'groupId',
          lower: [groupId],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterWhereClause>
  groupIdLessThan(int groupId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'groupId',
          lower: [],
          upper: [groupId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterWhereClause>
  groupIdBetween(
    int lowerGroupId,
    int upperGroupId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'groupId',
          lower: [lowerGroupId],
          includeLower: includeLower,
          upper: [upperGroupId],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterWhereClause>
  memberKeyEqualTo(String memberKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'memberKey', value: [memberKey]),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterWhereClause>
  memberKeyNotEqualTo(String memberKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'memberKey',
                lower: [],
                upper: [memberKey],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'memberKey',
                lower: [memberKey],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'memberKey',
                lower: [memberKey],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'memberKey',
                lower: [],
                upper: [memberKey],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension LibraryGroupMemberQueryFilter
    on QueryBuilder<LibraryGroupMember, LibraryGroupMember, QFilterCondition> {
  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  groupIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'groupId', value: value),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  groupIdGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'groupId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  groupIdLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'groupId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  groupIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'groupId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  idIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'id'),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  idIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'id'),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  idEqualTo(Id? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  idGreaterThan(Id? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  idLessThan(Id? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  idBetween(
    Id? lower,
    Id? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  itemIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'itemId', value: value),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  itemIdGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'itemId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  itemIdLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'itemId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  itemIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'itemId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  kindEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  kindGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  kindLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  kindBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'kind',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  kindStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  kindEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  kindContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  kindMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'kind',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  kindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'kind', value: ''),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  kindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'kind', value: ''),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  memberKeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'memberKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  memberKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'memberKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  memberKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'memberKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  memberKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'memberKey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  memberKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'memberKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  memberKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'memberKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  memberKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'memberKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  memberKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'memberKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  memberKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'memberKey', value: ''),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  memberKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'memberKey', value: ''),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  readingOrderIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'readingOrder'),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  readingOrderIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'readingOrder'),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  readingOrderEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'readingOrder', value: value),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  readingOrderGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'readingOrder',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  readingOrderLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'readingOrder',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterFilterCondition>
  readingOrderBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'readingOrder',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension LibraryGroupMemberQueryObject
    on QueryBuilder<LibraryGroupMember, LibraryGroupMember, QFilterCondition> {}

extension LibraryGroupMemberQueryLinks
    on QueryBuilder<LibraryGroupMember, LibraryGroupMember, QFilterCondition> {}

extension LibraryGroupMemberQuerySortBy
    on QueryBuilder<LibraryGroupMember, LibraryGroupMember, QSortBy> {
  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterSortBy>
  sortByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.asc);
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterSortBy>
  sortByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.desc);
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterSortBy>
  sortByItemId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemId', Sort.asc);
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterSortBy>
  sortByItemIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemId', Sort.desc);
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterSortBy>
  sortByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterSortBy>
  sortByKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterSortBy>
  sortByMemberKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memberKey', Sort.asc);
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterSortBy>
  sortByMemberKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memberKey', Sort.desc);
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterSortBy>
  sortByReadingOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'readingOrder', Sort.asc);
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterSortBy>
  sortByReadingOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'readingOrder', Sort.desc);
    });
  }
}

extension LibraryGroupMemberQuerySortThenBy
    on QueryBuilder<LibraryGroupMember, LibraryGroupMember, QSortThenBy> {
  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterSortBy>
  thenByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.asc);
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterSortBy>
  thenByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.desc);
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterSortBy>
  thenByItemId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemId', Sort.asc);
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterSortBy>
  thenByItemIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemId', Sort.desc);
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterSortBy>
  thenByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterSortBy>
  thenByKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterSortBy>
  thenByMemberKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memberKey', Sort.asc);
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterSortBy>
  thenByMemberKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memberKey', Sort.desc);
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterSortBy>
  thenByReadingOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'readingOrder', Sort.asc);
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QAfterSortBy>
  thenByReadingOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'readingOrder', Sort.desc);
    });
  }
}

extension LibraryGroupMemberQueryWhereDistinct
    on QueryBuilder<LibraryGroupMember, LibraryGroupMember, QDistinct> {
  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QDistinct>
  distinctByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'groupId');
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QDistinct>
  distinctByItemId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'itemId');
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QDistinct>
  distinctByKind({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'kind', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QDistinct>
  distinctByMemberKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'memberKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LibraryGroupMember, LibraryGroupMember, QDistinct>
  distinctByReadingOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'readingOrder');
    });
  }
}

extension LibraryGroupMemberQueryProperty
    on QueryBuilder<LibraryGroupMember, LibraryGroupMember, QQueryProperty> {
  QueryBuilder<LibraryGroupMember, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LibraryGroupMember, int, QQueryOperations> groupIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'groupId');
    });
  }

  QueryBuilder<LibraryGroupMember, int, QQueryOperations> itemIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'itemId');
    });
  }

  QueryBuilder<LibraryGroupMember, String, QQueryOperations> kindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'kind');
    });
  }

  QueryBuilder<LibraryGroupMember, String, QQueryOperations>
  memberKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'memberKey');
    });
  }

  QueryBuilder<LibraryGroupMember, int?, QQueryOperations>
  readingOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'readingOrder');
    });
  }
}

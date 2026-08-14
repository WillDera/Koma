// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manga_extras.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMangaExtrasCollection on Isar {
  IsarCollection<MangaExtras> get mangaExtras => this.collection();
}

const MangaExtrasSchema = CollectionSchema(
  name: r'MangaExtras',
  id: 4226601812679603313,
  properties: {
    r'categoryIds': PropertySchema(
      id: 0,
      name: r'categoryIds',
      type: IsarType.longList,
    ),
    r'mangaId': PropertySchema(id: 1, name: r'mangaId', type: IsarType.long),
    r'notes': PropertySchema(id: 2, name: r'notes', type: IsarType.string),
  },

  estimateSize: _mangaExtrasEstimateSize,
  serialize: _mangaExtrasSerialize,
  deserialize: _mangaExtrasDeserialize,
  deserializeProp: _mangaExtrasDeserializeProp,
  idName: r'id',
  indexes: {
    r'mangaId': IndexSchema(
      id: 7466570075891278896,
      name: r'mangaId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'mangaId',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _mangaExtrasGetId,
  getLinks: _mangaExtrasGetLinks,
  attach: _mangaExtrasAttach,
  version: '3.3.2',
);

int _mangaExtrasEstimateSize(
  MangaExtras object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.categoryIds;
    if (value != null) {
      bytesCount += 3 + value.length * 8;
    }
  }
  {
    final value = object.notes;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _mangaExtrasSerialize(
  MangaExtras object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLongList(offsets[0], object.categoryIds);
  writer.writeLong(offsets[1], object.mangaId);
  writer.writeString(offsets[2], object.notes);
}

MangaExtras _mangaExtrasDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MangaExtras(
    categoryIds: reader.readLongList(offsets[0]),
    id: id,
    mangaId: reader.readLong(offsets[1]),
    notes: reader.readStringOrNull(offsets[2]),
  );
  return object;
}

P _mangaExtrasDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongList(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _mangaExtrasGetId(MangaExtras object) {
  return object.id ?? Isar.autoIncrement;
}

List<IsarLinkBase<dynamic>> _mangaExtrasGetLinks(MangaExtras object) {
  return [];
}

void _mangaExtrasAttach(
  IsarCollection<dynamic> col,
  Id id,
  MangaExtras object,
) {
  object.id = id;
}

extension MangaExtrasByIndex on IsarCollection<MangaExtras> {
  Future<MangaExtras?> getByMangaId(int mangaId) {
    return getByIndex(r'mangaId', [mangaId]);
  }

  MangaExtras? getByMangaIdSync(int mangaId) {
    return getByIndexSync(r'mangaId', [mangaId]);
  }

  Future<bool> deleteByMangaId(int mangaId) {
    return deleteByIndex(r'mangaId', [mangaId]);
  }

  bool deleteByMangaIdSync(int mangaId) {
    return deleteByIndexSync(r'mangaId', [mangaId]);
  }

  Future<List<MangaExtras?>> getAllByMangaId(List<int> mangaIdValues) {
    final values = mangaIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'mangaId', values);
  }

  List<MangaExtras?> getAllByMangaIdSync(List<int> mangaIdValues) {
    final values = mangaIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'mangaId', values);
  }

  Future<int> deleteAllByMangaId(List<int> mangaIdValues) {
    final values = mangaIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'mangaId', values);
  }

  int deleteAllByMangaIdSync(List<int> mangaIdValues) {
    final values = mangaIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'mangaId', values);
  }

  Future<Id> putByMangaId(MangaExtras object) {
    return putByIndex(r'mangaId', object);
  }

  Id putByMangaIdSync(MangaExtras object, {bool saveLinks = true}) {
    return putByIndexSync(r'mangaId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByMangaId(List<MangaExtras> objects) {
    return putAllByIndex(r'mangaId', objects);
  }

  List<Id> putAllByMangaIdSync(
    List<MangaExtras> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'mangaId', objects, saveLinks: saveLinks);
  }
}

extension MangaExtrasQueryWhereSort
    on QueryBuilder<MangaExtras, MangaExtras, QWhere> {
  QueryBuilder<MangaExtras, MangaExtras, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterWhere> anyMangaId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'mangaId'),
      );
    });
  }
}

extension MangaExtrasQueryWhere
    on QueryBuilder<MangaExtras, MangaExtras, QWhereClause> {
  QueryBuilder<MangaExtras, MangaExtras, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
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

  QueryBuilder<MangaExtras, MangaExtras, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterWhereClause> idBetween(
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

  QueryBuilder<MangaExtras, MangaExtras, QAfterWhereClause> mangaIdEqualTo(
    int mangaId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'mangaId', value: [mangaId]),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterWhereClause> mangaIdNotEqualTo(
    int mangaId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mangaId',
                lower: [],
                upper: [mangaId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mangaId',
                lower: [mangaId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mangaId',
                lower: [mangaId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mangaId',
                lower: [],
                upper: [mangaId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterWhereClause> mangaIdGreaterThan(
    int mangaId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'mangaId',
          lower: [mangaId],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterWhereClause> mangaIdLessThan(
    int mangaId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'mangaId',
          lower: [],
          upper: [mangaId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterWhereClause> mangaIdBetween(
    int lowerMangaId,
    int upperMangaId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'mangaId',
          lower: [lowerMangaId],
          includeLower: includeLower,
          upper: [upperMangaId],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension MangaExtrasQueryFilter
    on QueryBuilder<MangaExtras, MangaExtras, QFilterCondition> {
  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition>
  categoryIdsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'categoryIds'),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition>
  categoryIdsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'categoryIds'),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition>
  categoryIdsElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'categoryIds', value: value),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition>
  categoryIdsElementGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'categoryIds',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition>
  categoryIdsElementLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'categoryIds',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition>
  categoryIdsElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'categoryIds',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition>
  categoryIdsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'categoryIds', length, true, length, true);
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition>
  categoryIdsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'categoryIds', 0, true, 0, true);
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition>
  categoryIdsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'categoryIds', 0, false, 999999, true);
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition>
  categoryIdsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'categoryIds', 0, true, length, include);
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition>
  categoryIdsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'categoryIds', length, include, 999999, true);
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition>
  categoryIdsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'categoryIds',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition> idIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'id'),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition> idIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'id'),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition> idEqualTo(
    Id? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition> idGreaterThan(
    Id? value, {
    bool include = false,
  }) {
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

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition> idLessThan(
    Id? value, {
    bool include = false,
  }) {
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

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition> idBetween(
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

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition> mangaIdEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'mangaId', value: value),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition>
  mangaIdGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'mangaId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition> mangaIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'mangaId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition> mangaIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'mangaId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition> notesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'notes'),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition>
  notesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'notes'),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition> notesEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition>
  notesGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition> notesLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition> notesBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'notes',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition> notesStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition> notesEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition> notesContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition> notesMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'notes',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition> notesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'notes', value: ''),
      );
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterFilterCondition>
  notesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'notes', value: ''),
      );
    });
  }
}

extension MangaExtrasQueryObject
    on QueryBuilder<MangaExtras, MangaExtras, QFilterCondition> {}

extension MangaExtrasQueryLinks
    on QueryBuilder<MangaExtras, MangaExtras, QFilterCondition> {}

extension MangaExtrasQuerySortBy
    on QueryBuilder<MangaExtras, MangaExtras, QSortBy> {
  QueryBuilder<MangaExtras, MangaExtras, QAfterSortBy> sortByMangaId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mangaId', Sort.asc);
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterSortBy> sortByMangaIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mangaId', Sort.desc);
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterSortBy> sortByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterSortBy> sortByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }
}

extension MangaExtrasQuerySortThenBy
    on QueryBuilder<MangaExtras, MangaExtras, QSortThenBy> {
  QueryBuilder<MangaExtras, MangaExtras, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterSortBy> thenByMangaId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mangaId', Sort.asc);
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterSortBy> thenByMangaIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mangaId', Sort.desc);
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterSortBy> thenByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QAfterSortBy> thenByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }
}

extension MangaExtrasQueryWhereDistinct
    on QueryBuilder<MangaExtras, MangaExtras, QDistinct> {
  QueryBuilder<MangaExtras, MangaExtras, QDistinct> distinctByCategoryIds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'categoryIds');
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QDistinct> distinctByMangaId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mangaId');
    });
  }

  QueryBuilder<MangaExtras, MangaExtras, QDistinct> distinctByNotes({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notes', caseSensitive: caseSensitive);
    });
  }
}

extension MangaExtrasQueryProperty
    on QueryBuilder<MangaExtras, MangaExtras, QQueryProperty> {
  QueryBuilder<MangaExtras, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MangaExtras, List<int>?, QQueryOperations>
  categoryIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'categoryIds');
    });
  }

  QueryBuilder<MangaExtras, int, QQueryOperations> mangaIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mangaId');
    });
  }

  QueryBuilder<MangaExtras, String?, QQueryOperations> notesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notes');
    });
  }
}

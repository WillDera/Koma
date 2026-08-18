// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_pref_value.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSourcePrefValueCollection on Isar {
  IsarCollection<SourcePrefValue> get sourcePrefValues => this.collection();
}

const SourcePrefValueSchema = CollectionSchema(
  name: r'SourcePrefValue',
  id: -1209170575443789103,
  properties: {
    r'prefKey': PropertySchema(id: 0, name: r'prefKey', type: IsarType.string),
    r'sourceId': PropertySchema(
      id: 1,
      name: r'sourceId',
      type: IsarType.string,
    ),
    r'storageKey': PropertySchema(
      id: 2,
      name: r'storageKey',
      type: IsarType.string,
    ),
    r'valueJson': PropertySchema(
      id: 3,
      name: r'valueJson',
      type: IsarType.string,
    ),
  },

  estimateSize: _sourcePrefValueEstimateSize,
  serialize: _sourcePrefValueSerialize,
  deserialize: _sourcePrefValueDeserialize,
  deserializeProp: _sourcePrefValueDeserializeProp,
  idName: r'id',
  indexes: {
    r'storageKey': IndexSchema(
      id: -7366682635250878879,
      name: r'storageKey',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'storageKey',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _sourcePrefValueGetId,
  getLinks: _sourcePrefValueGetLinks,
  attach: _sourcePrefValueAttach,
  version: '3.3.2',
);

int _sourcePrefValueEstimateSize(
  SourcePrefValue object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.prefKey.length * 3;
  bytesCount += 3 + object.sourceId.length * 3;
  bytesCount += 3 + object.storageKey.length * 3;
  bytesCount += 3 + object.valueJson.length * 3;
  return bytesCount;
}

void _sourcePrefValueSerialize(
  SourcePrefValue object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.prefKey);
  writer.writeString(offsets[1], object.sourceId);
  writer.writeString(offsets[2], object.storageKey);
  writer.writeString(offsets[3], object.valueJson);
}

SourcePrefValue _sourcePrefValueDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SourcePrefValue(
    id: id,
    prefKey: reader.readString(offsets[0]),
    sourceId: reader.readString(offsets[1]),
    storageKey: reader.readString(offsets[2]),
    valueJson: reader.readString(offsets[3]),
  );
  return object;
}

P _sourcePrefValueDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _sourcePrefValueGetId(SourcePrefValue object) {
  return object.id ?? Isar.autoIncrement;
}

List<IsarLinkBase<dynamic>> _sourcePrefValueGetLinks(SourcePrefValue object) {
  return [];
}

void _sourcePrefValueAttach(
  IsarCollection<dynamic> col,
  Id id,
  SourcePrefValue object,
) {
  object.id = id;
}

extension SourcePrefValueByIndex on IsarCollection<SourcePrefValue> {
  Future<SourcePrefValue?> getByStorageKey(String storageKey) {
    return getByIndex(r'storageKey', [storageKey]);
  }

  SourcePrefValue? getByStorageKeySync(String storageKey) {
    return getByIndexSync(r'storageKey', [storageKey]);
  }

  Future<bool> deleteByStorageKey(String storageKey) {
    return deleteByIndex(r'storageKey', [storageKey]);
  }

  bool deleteByStorageKeySync(String storageKey) {
    return deleteByIndexSync(r'storageKey', [storageKey]);
  }

  Future<List<SourcePrefValue?>> getAllByStorageKey(
    List<String> storageKeyValues,
  ) {
    final values = storageKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'storageKey', values);
  }

  List<SourcePrefValue?> getAllByStorageKeySync(List<String> storageKeyValues) {
    final values = storageKeyValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'storageKey', values);
  }

  Future<int> deleteAllByStorageKey(List<String> storageKeyValues) {
    final values = storageKeyValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'storageKey', values);
  }

  int deleteAllByStorageKeySync(List<String> storageKeyValues) {
    final values = storageKeyValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'storageKey', values);
  }

  Future<Id> putByStorageKey(SourcePrefValue object) {
    return putByIndex(r'storageKey', object);
  }

  Id putByStorageKeySync(SourcePrefValue object, {bool saveLinks = true}) {
    return putByIndexSync(r'storageKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByStorageKey(List<SourcePrefValue> objects) {
    return putAllByIndex(r'storageKey', objects);
  }

  List<Id> putAllByStorageKeySync(
    List<SourcePrefValue> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'storageKey', objects, saveLinks: saveLinks);
  }
}

extension SourcePrefValueQueryWhereSort
    on QueryBuilder<SourcePrefValue, SourcePrefValue, QWhere> {
  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SourcePrefValueQueryWhere
    on QueryBuilder<SourcePrefValue, SourcePrefValue, QWhereClause> {
  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterWhereClause>
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

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterWhereClause> idBetween(
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

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterWhereClause>
  storageKeyEqualTo(String storageKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'storageKey', value: [storageKey]),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterWhereClause>
  storageKeyNotEqualTo(String storageKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'storageKey',
                lower: [],
                upper: [storageKey],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'storageKey',
                lower: [storageKey],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'storageKey',
                lower: [storageKey],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'storageKey',
                lower: [],
                upper: [storageKey],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension SourcePrefValueQueryFilter
    on QueryBuilder<SourcePrefValue, SourcePrefValue, QFilterCondition> {
  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  idIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'id'),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  idIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'id'),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  idEqualTo(Id? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
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

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
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

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
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

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  prefKeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'prefKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  prefKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'prefKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  prefKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'prefKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  prefKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'prefKey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  prefKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'prefKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  prefKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'prefKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  prefKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'prefKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  prefKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'prefKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  prefKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'prefKey', value: ''),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  prefKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'prefKey', value: ''),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  sourceIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sourceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  sourceIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sourceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  sourceIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sourceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  sourceIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sourceId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  sourceIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'sourceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  sourceIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'sourceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  sourceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'sourceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  sourceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'sourceId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  sourceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sourceId', value: ''),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  sourceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'sourceId', value: ''),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  storageKeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'storageKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  storageKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'storageKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  storageKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'storageKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  storageKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'storageKey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  storageKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'storageKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  storageKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'storageKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  storageKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'storageKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  storageKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'storageKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  storageKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'storageKey', value: ''),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  storageKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'storageKey', value: ''),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  valueJsonEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'valueJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  valueJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'valueJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  valueJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'valueJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  valueJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'valueJson',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  valueJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'valueJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  valueJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'valueJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  valueJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'valueJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  valueJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'valueJson',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  valueJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'valueJson', value: ''),
      );
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterFilterCondition>
  valueJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'valueJson', value: ''),
      );
    });
  }
}

extension SourcePrefValueQueryObject
    on QueryBuilder<SourcePrefValue, SourcePrefValue, QFilterCondition> {}

extension SourcePrefValueQueryLinks
    on QueryBuilder<SourcePrefValue, SourcePrefValue, QFilterCondition> {}

extension SourcePrefValueQuerySortBy
    on QueryBuilder<SourcePrefValue, SourcePrefValue, QSortBy> {
  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterSortBy> sortByPrefKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prefKey', Sort.asc);
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterSortBy>
  sortByPrefKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prefKey', Sort.desc);
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterSortBy>
  sortBySourceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceId', Sort.asc);
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterSortBy>
  sortBySourceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceId', Sort.desc);
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterSortBy>
  sortByStorageKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storageKey', Sort.asc);
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterSortBy>
  sortByStorageKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storageKey', Sort.desc);
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterSortBy>
  sortByValueJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'valueJson', Sort.asc);
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterSortBy>
  sortByValueJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'valueJson', Sort.desc);
    });
  }
}

extension SourcePrefValueQuerySortThenBy
    on QueryBuilder<SourcePrefValue, SourcePrefValue, QSortThenBy> {
  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterSortBy> thenByPrefKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prefKey', Sort.asc);
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterSortBy>
  thenByPrefKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prefKey', Sort.desc);
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterSortBy>
  thenBySourceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceId', Sort.asc);
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterSortBy>
  thenBySourceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceId', Sort.desc);
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterSortBy>
  thenByStorageKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storageKey', Sort.asc);
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterSortBy>
  thenByStorageKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storageKey', Sort.desc);
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterSortBy>
  thenByValueJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'valueJson', Sort.asc);
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QAfterSortBy>
  thenByValueJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'valueJson', Sort.desc);
    });
  }
}

extension SourcePrefValueQueryWhereDistinct
    on QueryBuilder<SourcePrefValue, SourcePrefValue, QDistinct> {
  QueryBuilder<SourcePrefValue, SourcePrefValue, QDistinct> distinctByPrefKey({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'prefKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QDistinct> distinctBySourceId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QDistinct>
  distinctByStorageKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'storageKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SourcePrefValue, SourcePrefValue, QDistinct>
  distinctByValueJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'valueJson', caseSensitive: caseSensitive);
    });
  }
}

extension SourcePrefValueQueryProperty
    on QueryBuilder<SourcePrefValue, SourcePrefValue, QQueryProperty> {
  QueryBuilder<SourcePrefValue, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SourcePrefValue, String, QQueryOperations> prefKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'prefKey');
    });
  }

  QueryBuilder<SourcePrefValue, String, QQueryOperations> sourceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceId');
    });
  }

  QueryBuilder<SourcePrefValue, String, QQueryOperations> storageKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'storageKey');
    });
  }

  QueryBuilder<SourcePrefValue, String, QQueryOperations> valueJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'valueJson');
    });
  }
}

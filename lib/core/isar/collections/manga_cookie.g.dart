// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manga_cookie.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMangaCookieCollection on Isar {
  IsarCollection<MangaCookie> get mangaCookies => this.collection();
}

const MangaCookieSchema = CollectionSchema(
  name: r'MangaCookie',
  id: 2092562585784052704,
  properties: {
    r'cookie': PropertySchema(id: 0, name: r'cookie', type: IsarType.string),
    r'host': PropertySchema(id: 1, name: r'host', type: IsarType.string),
  },

  estimateSize: _mangaCookieEstimateSize,
  serialize: _mangaCookieSerialize,
  deserialize: _mangaCookieDeserialize,
  deserializeProp: _mangaCookieDeserializeProp,
  idName: r'id',
  indexes: {
    r'host': IndexSchema(
      id: -7602099240340412494,
      name: r'host',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'host',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _mangaCookieGetId,
  getLinks: _mangaCookieGetLinks,
  attach: _mangaCookieAttach,
  version: '3.3.2',
);

int _mangaCookieEstimateSize(
  MangaCookie object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.cookie.length * 3;
  bytesCount += 3 + object.host.length * 3;
  return bytesCount;
}

void _mangaCookieSerialize(
  MangaCookie object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cookie);
  writer.writeString(offsets[1], object.host);
}

MangaCookie _mangaCookieDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MangaCookie(
    cookie: reader.readStringOrNull(offsets[0]) ?? '',
    host: reader.readString(offsets[1]),
    id: id,
  );
  return object;
}

P _mangaCookieDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 1:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _mangaCookieGetId(MangaCookie object) {
  return object.id ?? Isar.autoIncrement;
}

List<IsarLinkBase<dynamic>> _mangaCookieGetLinks(MangaCookie object) {
  return [];
}

void _mangaCookieAttach(
  IsarCollection<dynamic> col,
  Id id,
  MangaCookie object,
) {
  object.id = id;
}

extension MangaCookieByIndex on IsarCollection<MangaCookie> {
  Future<MangaCookie?> getByHost(String host) {
    return getByIndex(r'host', [host]);
  }

  MangaCookie? getByHostSync(String host) {
    return getByIndexSync(r'host', [host]);
  }

  Future<bool> deleteByHost(String host) {
    return deleteByIndex(r'host', [host]);
  }

  bool deleteByHostSync(String host) {
    return deleteByIndexSync(r'host', [host]);
  }

  Future<List<MangaCookie?>> getAllByHost(List<String> hostValues) {
    final values = hostValues.map((e) => [e]).toList();
    return getAllByIndex(r'host', values);
  }

  List<MangaCookie?> getAllByHostSync(List<String> hostValues) {
    final values = hostValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'host', values);
  }

  Future<int> deleteAllByHost(List<String> hostValues) {
    final values = hostValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'host', values);
  }

  int deleteAllByHostSync(List<String> hostValues) {
    final values = hostValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'host', values);
  }

  Future<Id> putByHost(MangaCookie object) {
    return putByIndex(r'host', object);
  }

  Id putByHostSync(MangaCookie object, {bool saveLinks = true}) {
    return putByIndexSync(r'host', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByHost(List<MangaCookie> objects) {
    return putAllByIndex(r'host', objects);
  }

  List<Id> putAllByHostSync(
    List<MangaCookie> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'host', objects, saveLinks: saveLinks);
  }
}

extension MangaCookieQueryWhereSort
    on QueryBuilder<MangaCookie, MangaCookie, QWhere> {
  QueryBuilder<MangaCookie, MangaCookie, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension MangaCookieQueryWhere
    on QueryBuilder<MangaCookie, MangaCookie, QWhereClause> {
  QueryBuilder<MangaCookie, MangaCookie, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<MangaCookie, MangaCookie, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterWhereClause> idBetween(
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

  QueryBuilder<MangaCookie, MangaCookie, QAfterWhereClause> hostEqualTo(
    String host,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'host', value: [host]),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterWhereClause> hostNotEqualTo(
    String host,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'host',
                lower: [],
                upper: [host],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'host',
                lower: [host],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'host',
                lower: [host],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'host',
                lower: [],
                upper: [host],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension MangaCookieQueryFilter
    on QueryBuilder<MangaCookie, MangaCookie, QFilterCondition> {
  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition> cookieEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'cookie',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition>
  cookieGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'cookie',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition> cookieLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'cookie',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition> cookieBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'cookie',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition>
  cookieStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'cookie',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition> cookieEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'cookie',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition> cookieContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'cookie',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition> cookieMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'cookie',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition>
  cookieIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cookie', value: ''),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition>
  cookieIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cookie', value: ''),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition> hostEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'host',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition> hostGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'host',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition> hostLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'host',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition> hostBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'host',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition> hostStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'host',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition> hostEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'host',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition> hostContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'host',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition> hostMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'host',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition> hostIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'host', value: ''),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition>
  hostIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'host', value: ''),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition> idIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'id'),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition> idIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'id'),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition> idEqualTo(
    Id? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<MangaCookie, MangaCookie, QAfterFilterCondition> idBetween(
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
}

extension MangaCookieQueryObject
    on QueryBuilder<MangaCookie, MangaCookie, QFilterCondition> {}

extension MangaCookieQueryLinks
    on QueryBuilder<MangaCookie, MangaCookie, QFilterCondition> {}

extension MangaCookieQuerySortBy
    on QueryBuilder<MangaCookie, MangaCookie, QSortBy> {
  QueryBuilder<MangaCookie, MangaCookie, QAfterSortBy> sortByCookie() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cookie', Sort.asc);
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterSortBy> sortByCookieDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cookie', Sort.desc);
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterSortBy> sortByHost() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'host', Sort.asc);
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterSortBy> sortByHostDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'host', Sort.desc);
    });
  }
}

extension MangaCookieQuerySortThenBy
    on QueryBuilder<MangaCookie, MangaCookie, QSortThenBy> {
  QueryBuilder<MangaCookie, MangaCookie, QAfterSortBy> thenByCookie() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cookie', Sort.asc);
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterSortBy> thenByCookieDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cookie', Sort.desc);
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterSortBy> thenByHost() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'host', Sort.asc);
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterSortBy> thenByHostDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'host', Sort.desc);
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }
}

extension MangaCookieQueryWhereDistinct
    on QueryBuilder<MangaCookie, MangaCookie, QDistinct> {
  QueryBuilder<MangaCookie, MangaCookie, QDistinct> distinctByCookie({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cookie', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MangaCookie, MangaCookie, QDistinct> distinctByHost({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'host', caseSensitive: caseSensitive);
    });
  }
}

extension MangaCookieQueryProperty
    on QueryBuilder<MangaCookie, MangaCookie, QQueryProperty> {
  QueryBuilder<MangaCookie, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MangaCookie, String, QQueryOperations> cookieProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cookie');
    });
  }

  QueryBuilder<MangaCookie, String, QQueryOperations> hostProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'host');
    });
  }
}

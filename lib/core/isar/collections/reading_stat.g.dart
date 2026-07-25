// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_stat.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetReadingStatCollection on Isar {
  IsarCollection<ReadingStat> get readingStats => this.collection();
}

const ReadingStatSchema = CollectionSchema(
  name: r'ReadingStat',
  id: -7547329362909185325,
  properties: {
    r'booksCompleted': PropertySchema(
      id: 0,
      name: r'booksCompleted',
      type: IsarType.long,
    ),
    r'date': PropertySchema(id: 1, name: r'date', type: IsarType.dateTime),
    r'readingTimeSeconds': PropertySchema(
      id: 2,
      name: r'readingTimeSeconds',
      type: IsarType.long,
    ),
    r'snippetsCreated': PropertySchema(
      id: 3,
      name: r'snippetsCreated',
      type: IsarType.long,
    ),
  },

  estimateSize: _readingStatEstimateSize,
  serialize: _readingStatSerialize,
  deserialize: _readingStatDeserialize,
  deserializeProp: _readingStatDeserializeProp,
  idName: r'id',
  indexes: {
    r'date': IndexSchema(
      id: -7552997827385218417,
      name: r'date',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'date',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _readingStatGetId,
  getLinks: _readingStatGetLinks,
  attach: _readingStatAttach,
  version: '3.3.2',
);

int _readingStatEstimateSize(
  ReadingStat object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _readingStatSerialize(
  ReadingStat object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.booksCompleted);
  writer.writeDateTime(offsets[1], object.date);
  writer.writeLong(offsets[2], object.readingTimeSeconds);
  writer.writeLong(offsets[3], object.snippetsCreated);
}

ReadingStat _readingStatDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ReadingStat(
    booksCompleted: reader.readLongOrNull(offsets[0]) ?? 0,
    date: reader.readDateTime(offsets[1]),
    id: id,
    readingTimeSeconds: reader.readLongOrNull(offsets[2]) ?? 0,
    snippetsCreated: reader.readLongOrNull(offsets[3]) ?? 0,
  );
  return object;
}

P _readingStatDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 3:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _readingStatGetId(ReadingStat object) {
  return object.id ?? Isar.autoIncrement;
}

List<IsarLinkBase<dynamic>> _readingStatGetLinks(ReadingStat object) {
  return [];
}

void _readingStatAttach(
  IsarCollection<dynamic> col,
  Id id,
  ReadingStat object,
) {
  object.id = id;
}

extension ReadingStatByIndex on IsarCollection<ReadingStat> {
  Future<ReadingStat?> getByDate(DateTime date) {
    return getByIndex(r'date', [date]);
  }

  ReadingStat? getByDateSync(DateTime date) {
    return getByIndexSync(r'date', [date]);
  }

  Future<bool> deleteByDate(DateTime date) {
    return deleteByIndex(r'date', [date]);
  }

  bool deleteByDateSync(DateTime date) {
    return deleteByIndexSync(r'date', [date]);
  }

  Future<List<ReadingStat?>> getAllByDate(List<DateTime> dateValues) {
    final values = dateValues.map((e) => [e]).toList();
    return getAllByIndex(r'date', values);
  }

  List<ReadingStat?> getAllByDateSync(List<DateTime> dateValues) {
    final values = dateValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'date', values);
  }

  Future<int> deleteAllByDate(List<DateTime> dateValues) {
    final values = dateValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'date', values);
  }

  int deleteAllByDateSync(List<DateTime> dateValues) {
    final values = dateValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'date', values);
  }

  Future<Id> putByDate(ReadingStat object) {
    return putByIndex(r'date', object);
  }

  Id putByDateSync(ReadingStat object, {bool saveLinks = true}) {
    return putByIndexSync(r'date', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByDate(List<ReadingStat> objects) {
    return putAllByIndex(r'date', objects);
  }

  List<Id> putAllByDateSync(
    List<ReadingStat> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'date', objects, saveLinks: saveLinks);
  }
}

extension ReadingStatQueryWhereSort
    on QueryBuilder<ReadingStat, ReadingStat, QWhere> {
  QueryBuilder<ReadingStat, ReadingStat, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterWhere> anyDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'date'),
      );
    });
  }
}

extension ReadingStatQueryWhere
    on QueryBuilder<ReadingStat, ReadingStat, QWhereClause> {
  QueryBuilder<ReadingStat, ReadingStat, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<ReadingStat, ReadingStat, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterWhereClause> idBetween(
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

  QueryBuilder<ReadingStat, ReadingStat, QAfterWhereClause> dateEqualTo(
    DateTime date,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'date', value: [date]),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterWhereClause> dateNotEqualTo(
    DateTime date,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'date',
                lower: [],
                upper: [date],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'date',
                lower: [date],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'date',
                lower: [date],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'date',
                lower: [],
                upper: [date],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterWhereClause> dateGreaterThan(
    DateTime date, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'date',
          lower: [date],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterWhereClause> dateLessThan(
    DateTime date, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'date',
          lower: [],
          upper: [date],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterWhereClause> dateBetween(
    DateTime lowerDate,
    DateTime upperDate, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'date',
          lower: [lowerDate],
          includeLower: includeLower,
          upper: [upperDate],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ReadingStatQueryFilter
    on QueryBuilder<ReadingStat, ReadingStat, QFilterCondition> {
  QueryBuilder<ReadingStat, ReadingStat, QAfterFilterCondition>
  booksCompletedEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'booksCompleted', value: value),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterFilterCondition>
  booksCompletedGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'booksCompleted',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterFilterCondition>
  booksCompletedLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'booksCompleted',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterFilterCondition>
  booksCompletedBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'booksCompleted',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterFilterCondition> dateEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'date', value: value),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterFilterCondition> dateGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'date',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterFilterCondition> dateLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'date',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterFilterCondition> dateBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'date',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterFilterCondition> idIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'id'),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterFilterCondition> idIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'id'),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterFilterCondition> idEqualTo(
    Id? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<ReadingStat, ReadingStat, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<ReadingStat, ReadingStat, QAfterFilterCondition> idBetween(
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

  QueryBuilder<ReadingStat, ReadingStat, QAfterFilterCondition>
  readingTimeSecondsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'readingTimeSeconds', value: value),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterFilterCondition>
  readingTimeSecondsGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'readingTimeSeconds',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterFilterCondition>
  readingTimeSecondsLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'readingTimeSeconds',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterFilterCondition>
  readingTimeSecondsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'readingTimeSeconds',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterFilterCondition>
  snippetsCreatedEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'snippetsCreated', value: value),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterFilterCondition>
  snippetsCreatedGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'snippetsCreated',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterFilterCondition>
  snippetsCreatedLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'snippetsCreated',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterFilterCondition>
  snippetsCreatedBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'snippetsCreated',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ReadingStatQueryObject
    on QueryBuilder<ReadingStat, ReadingStat, QFilterCondition> {}

extension ReadingStatQueryLinks
    on QueryBuilder<ReadingStat, ReadingStat, QFilterCondition> {}

extension ReadingStatQuerySortBy
    on QueryBuilder<ReadingStat, ReadingStat, QSortBy> {
  QueryBuilder<ReadingStat, ReadingStat, QAfterSortBy> sortByBooksCompleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'booksCompleted', Sort.asc);
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterSortBy>
  sortByBooksCompletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'booksCompleted', Sort.desc);
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterSortBy> sortByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterSortBy> sortByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterSortBy>
  sortByReadingTimeSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'readingTimeSeconds', Sort.asc);
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterSortBy>
  sortByReadingTimeSecondsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'readingTimeSeconds', Sort.desc);
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterSortBy> sortBySnippetsCreated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snippetsCreated', Sort.asc);
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterSortBy>
  sortBySnippetsCreatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snippetsCreated', Sort.desc);
    });
  }
}

extension ReadingStatQuerySortThenBy
    on QueryBuilder<ReadingStat, ReadingStat, QSortThenBy> {
  QueryBuilder<ReadingStat, ReadingStat, QAfterSortBy> thenByBooksCompleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'booksCompleted', Sort.asc);
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterSortBy>
  thenByBooksCompletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'booksCompleted', Sort.desc);
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterSortBy> thenByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterSortBy> thenByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterSortBy>
  thenByReadingTimeSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'readingTimeSeconds', Sort.asc);
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterSortBy>
  thenByReadingTimeSecondsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'readingTimeSeconds', Sort.desc);
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterSortBy> thenBySnippetsCreated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snippetsCreated', Sort.asc);
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QAfterSortBy>
  thenBySnippetsCreatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snippetsCreated', Sort.desc);
    });
  }
}

extension ReadingStatQueryWhereDistinct
    on QueryBuilder<ReadingStat, ReadingStat, QDistinct> {
  QueryBuilder<ReadingStat, ReadingStat, QDistinct> distinctByBooksCompleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'booksCompleted');
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QDistinct> distinctByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'date');
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QDistinct>
  distinctByReadingTimeSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'readingTimeSeconds');
    });
  }

  QueryBuilder<ReadingStat, ReadingStat, QDistinct>
  distinctBySnippetsCreated() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'snippetsCreated');
    });
  }
}

extension ReadingStatQueryProperty
    on QueryBuilder<ReadingStat, ReadingStat, QQueryProperty> {
  QueryBuilder<ReadingStat, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ReadingStat, int, QQueryOperations> booksCompletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'booksCompleted');
    });
  }

  QueryBuilder<ReadingStat, DateTime, QQueryOperations> dateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'date');
    });
  }

  QueryBuilder<ReadingStat, int, QQueryOperations>
  readingTimeSecondsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'readingTimeSeconds');
    });
  }

  QueryBuilder<ReadingStat, int, QQueryOperations> snippetsCreatedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'snippetsCreated');
    });
  }
}

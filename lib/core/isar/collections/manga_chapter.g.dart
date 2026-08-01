// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manga_chapter.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMangaChapterCollection on Isar {
  IsarCollection<MangaChapter> get mangaChapters => this.collection();
}

const MangaChapterSchema = CollectionSchema(
  name: r'MangaChapter',
  id: 661750507975809523,
  properties: {
    r'dateUpload': PropertySchema(
      id: 0,
      name: r'dateUpload',
      type: IsarType.long,
    ),
    r'index': PropertySchema(id: 1, name: r'index', type: IsarType.long),
    r'isDownloaded': PropertySchema(
      id: 2,
      name: r'isDownloaded',
      type: IsarType.bool,
    ),
    r'isOpened': PropertySchema(id: 3, name: r'isOpened', type: IsarType.bool),
    r'isRead': PropertySchema(id: 4, name: r'isRead', type: IsarType.bool),
    r'lastPageRead': PropertySchema(
      id: 5,
      name: r'lastPageRead',
      type: IsarType.long,
    ),
    r'mangaId': PropertySchema(id: 6, name: r'mangaId', type: IsarType.long),
    r'memo': PropertySchema(id: 7, name: r'memo', type: IsarType.string),
    r'name': PropertySchema(id: 8, name: r'name', type: IsarType.string),
    r'readAt': PropertySchema(id: 9, name: r'readAt', type: IsarType.dateTime),
    r'scanlator': PropertySchema(
      id: 10,
      name: r'scanlator',
      type: IsarType.string,
    ),
    r'scrollPosition': PropertySchema(
      id: 11,
      name: r'scrollPosition',
      type: IsarType.double,
    ),
    r'url': PropertySchema(id: 12, name: r'url', type: IsarType.string),
  },

  estimateSize: _mangaChapterEstimateSize,
  serialize: _mangaChapterSerialize,
  deserialize: _mangaChapterDeserialize,
  deserializeProp: _mangaChapterDeserializeProp,
  idName: r'id',
  indexes: {
    r'mangaId': IndexSchema(
      id: 7466570075891278896,
      name: r'mangaId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'mangaId',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'url': IndexSchema(
      id: -5756857009679432345,
      name: r'url',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'url',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _mangaChapterGetId,
  getLinks: _mangaChapterGetLinks,
  attach: _mangaChapterAttach,
  version: '3.3.2',
);

int _mangaChapterEstimateSize(
  MangaChapter object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.memo;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.name.length * 3;
  {
    final value = object.scanlator;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.url.length * 3;
  return bytesCount;
}

void _mangaChapterSerialize(
  MangaChapter object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.dateUpload);
  writer.writeLong(offsets[1], object.index);
  writer.writeBool(offsets[2], object.isDownloaded);
  writer.writeBool(offsets[3], object.isOpened);
  writer.writeBool(offsets[4], object.isRead);
  writer.writeLong(offsets[5], object.lastPageRead);
  writer.writeLong(offsets[6], object.mangaId);
  writer.writeString(offsets[7], object.memo);
  writer.writeString(offsets[8], object.name);
  writer.writeDateTime(offsets[9], object.readAt);
  writer.writeString(offsets[10], object.scanlator);
  writer.writeDouble(offsets[11], object.scrollPosition);
  writer.writeString(offsets[12], object.url);
}

MangaChapter _mangaChapterDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MangaChapter(
    dateUpload: reader.readLongOrNull(offsets[0]) ?? 0,
    id: id,
    index: reader.readLong(offsets[1]),
    isDownloaded: reader.readBoolOrNull(offsets[2]) ?? false,
    isOpened: reader.readBoolOrNull(offsets[3]) ?? false,
    isRead: reader.readBoolOrNull(offsets[4]) ?? false,
    lastPageRead: reader.readLongOrNull(offsets[5]) ?? 0,
    mangaId: reader.readLong(offsets[6]),
    memo: reader.readStringOrNull(offsets[7]),
    name: reader.readString(offsets[8]),
    readAt: reader.readDateTimeOrNull(offsets[9]),
    scanlator: reader.readStringOrNull(offsets[10]),
    scrollPosition: reader.readDoubleOrNull(offsets[11]) ?? 0.0,
    url: reader.readString(offsets[12]),
  );
  return object;
}

P _mangaChapterDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 3:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 4:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 5:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readDoubleOrNull(offset) ?? 0.0) as P;
    case 12:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _mangaChapterGetId(MangaChapter object) {
  return object.id ?? Isar.autoIncrement;
}

List<IsarLinkBase<dynamic>> _mangaChapterGetLinks(MangaChapter object) {
  return [];
}

void _mangaChapterAttach(
  IsarCollection<dynamic> col,
  Id id,
  MangaChapter object,
) {
  object.id = id;
}

extension MangaChapterQueryWhereSort
    on QueryBuilder<MangaChapter, MangaChapter, QWhere> {
  QueryBuilder<MangaChapter, MangaChapter, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterWhere> anyMangaId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'mangaId'),
      );
    });
  }
}

extension MangaChapterQueryWhere
    on QueryBuilder<MangaChapter, MangaChapter, QWhereClause> {
  QueryBuilder<MangaChapter, MangaChapter, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<MangaChapter, MangaChapter, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterWhereClause> idBetween(
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

  QueryBuilder<MangaChapter, MangaChapter, QAfterWhereClause> mangaIdEqualTo(
    int mangaId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'mangaId', value: [mangaId]),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterWhereClause> mangaIdNotEqualTo(
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

  QueryBuilder<MangaChapter, MangaChapter, QAfterWhereClause>
  mangaIdGreaterThan(int mangaId, {bool include = false}) {
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

  QueryBuilder<MangaChapter, MangaChapter, QAfterWhereClause> mangaIdLessThan(
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

  QueryBuilder<MangaChapter, MangaChapter, QAfterWhereClause> mangaIdBetween(
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

  QueryBuilder<MangaChapter, MangaChapter, QAfterWhereClause> urlEqualTo(
    String url,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'url', value: [url]),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterWhereClause> urlNotEqualTo(
    String url,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'url',
                lower: [],
                upper: [url],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'url',
                lower: [url],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'url',
                lower: [url],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'url',
                lower: [],
                upper: [url],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension MangaChapterQueryFilter
    on QueryBuilder<MangaChapter, MangaChapter, QFilterCondition> {
  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  dateUploadEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'dateUpload', value: value),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  dateUploadGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'dateUpload',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  dateUploadLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'dateUpload',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  dateUploadBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'dateUpload',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> idIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'id'),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  idIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'id'),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> idEqualTo(
    Id? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> idBetween(
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

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> indexEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'index', value: value),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  indexGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'index',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> indexLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'index',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> indexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'index',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  isDownloadedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isDownloaded', value: value),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  isOpenedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isOpened', value: value),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> isReadEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isRead', value: value),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  lastPageReadEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastPageRead', value: value),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  lastPageReadGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastPageRead',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  lastPageReadLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastPageRead',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  lastPageReadBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastPageRead',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  mangaIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'mangaId', value: value),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
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

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  mangaIdLessThan(int value, {bool include = false}) {
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

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  mangaIdBetween(
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

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> memoIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'memo'),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  memoIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'memo'),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> memoEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'memo',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  memoGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'memo',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> memoLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'memo',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> memoBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'memo',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  memoStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'memo',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> memoEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'memo',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> memoContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'memo',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> memoMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'memo',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  memoIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'memo', value: ''),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  memoIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'memo', value: ''),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  nameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> nameContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> nameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  readAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'readAt'),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  readAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'readAt'),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> readAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'readAt', value: value),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  readAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'readAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  readAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'readAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> readAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'readAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  scanlatorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'scanlator'),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  scanlatorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'scanlator'),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  scanlatorEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'scanlator',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  scanlatorGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'scanlator',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  scanlatorLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'scanlator',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  scanlatorBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'scanlator',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  scanlatorStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'scanlator',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  scanlatorEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'scanlator',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  scanlatorContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'scanlator',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  scanlatorMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'scanlator',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  scanlatorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'scanlator', value: ''),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  scanlatorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'scanlator', value: ''),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  scrollPositionEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'scrollPosition',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  scrollPositionGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'scrollPosition',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  scrollPositionLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'scrollPosition',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  scrollPositionBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'scrollPosition',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> urlEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'url',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  urlGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'url',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> urlLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'url',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> urlBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'url',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> urlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'url',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> urlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'url',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> urlContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'url',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> urlMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'url',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition> urlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'url', value: ''),
      );
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterFilterCondition>
  urlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'url', value: ''),
      );
    });
  }
}

extension MangaChapterQueryObject
    on QueryBuilder<MangaChapter, MangaChapter, QFilterCondition> {}

extension MangaChapterQueryLinks
    on QueryBuilder<MangaChapter, MangaChapter, QFilterCondition> {}

extension MangaChapterQuerySortBy
    on QueryBuilder<MangaChapter, MangaChapter, QSortBy> {
  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> sortByDateUpload() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateUpload', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy>
  sortByDateUploadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateUpload', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> sortByIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'index', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> sortByIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'index', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> sortByIsDownloaded() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDownloaded', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy>
  sortByIsDownloadedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDownloaded', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> sortByIsOpened() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOpened', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> sortByIsOpenedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOpened', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> sortByIsRead() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRead', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> sortByIsReadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRead', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> sortByLastPageRead() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPageRead', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy>
  sortByLastPageReadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPageRead', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> sortByMangaId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mangaId', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> sortByMangaIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mangaId', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> sortByMemo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memo', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> sortByMemoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memo', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> sortByReadAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'readAt', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> sortByReadAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'readAt', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> sortByScanlator() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scanlator', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> sortByScanlatorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scanlator', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy>
  sortByScrollPosition() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scrollPosition', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy>
  sortByScrollPositionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scrollPosition', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> sortByUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'url', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> sortByUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'url', Sort.desc);
    });
  }
}

extension MangaChapterQuerySortThenBy
    on QueryBuilder<MangaChapter, MangaChapter, QSortThenBy> {
  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenByDateUpload() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateUpload', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy>
  thenByDateUploadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateUpload', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenByIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'index', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenByIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'index', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenByIsDownloaded() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDownloaded', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy>
  thenByIsDownloadedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDownloaded', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenByIsOpened() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOpened', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenByIsOpenedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOpened', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenByIsRead() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRead', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenByIsReadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRead', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenByLastPageRead() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPageRead', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy>
  thenByLastPageReadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPageRead', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenByMangaId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mangaId', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenByMangaIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mangaId', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenByMemo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memo', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenByMemoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memo', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenByReadAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'readAt', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenByReadAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'readAt', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenByScanlator() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scanlator', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenByScanlatorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scanlator', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy>
  thenByScrollPosition() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scrollPosition', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy>
  thenByScrollPositionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scrollPosition', Sort.desc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenByUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'url', Sort.asc);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QAfterSortBy> thenByUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'url', Sort.desc);
    });
  }
}

extension MangaChapterQueryWhereDistinct
    on QueryBuilder<MangaChapter, MangaChapter, QDistinct> {
  QueryBuilder<MangaChapter, MangaChapter, QDistinct> distinctByDateUpload() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dateUpload');
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QDistinct> distinctByIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'index');
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QDistinct> distinctByIsDownloaded() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDownloaded');
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QDistinct> distinctByIsOpened() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isOpened');
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QDistinct> distinctByIsRead() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isRead');
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QDistinct> distinctByLastPageRead() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastPageRead');
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QDistinct> distinctByMangaId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mangaId');
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QDistinct> distinctByMemo({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'memo', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QDistinct> distinctByReadAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'readAt');
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QDistinct> distinctByScanlator({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'scanlator', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QDistinct>
  distinctByScrollPosition() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'scrollPosition');
    });
  }

  QueryBuilder<MangaChapter, MangaChapter, QDistinct> distinctByUrl({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'url', caseSensitive: caseSensitive);
    });
  }
}

extension MangaChapterQueryProperty
    on QueryBuilder<MangaChapter, MangaChapter, QQueryProperty> {
  QueryBuilder<MangaChapter, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MangaChapter, int, QQueryOperations> dateUploadProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dateUpload');
    });
  }

  QueryBuilder<MangaChapter, int, QQueryOperations> indexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'index');
    });
  }

  QueryBuilder<MangaChapter, bool, QQueryOperations> isDownloadedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDownloaded');
    });
  }

  QueryBuilder<MangaChapter, bool, QQueryOperations> isOpenedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isOpened');
    });
  }

  QueryBuilder<MangaChapter, bool, QQueryOperations> isReadProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isRead');
    });
  }

  QueryBuilder<MangaChapter, int, QQueryOperations> lastPageReadProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastPageRead');
    });
  }

  QueryBuilder<MangaChapter, int, QQueryOperations> mangaIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mangaId');
    });
  }

  QueryBuilder<MangaChapter, String?, QQueryOperations> memoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'memo');
    });
  }

  QueryBuilder<MangaChapter, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<MangaChapter, DateTime?, QQueryOperations> readAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'readAt');
    });
  }

  QueryBuilder<MangaChapter, String?, QQueryOperations> scanlatorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'scanlator');
    });
  }

  QueryBuilder<MangaChapter, double, QQueryOperations>
  scrollPositionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'scrollPosition');
    });
  }

  QueryBuilder<MangaChapter, String, QQueryOperations> urlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'url');
    });
  }
}

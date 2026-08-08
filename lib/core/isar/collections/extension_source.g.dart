// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'extension_source.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetExtensionSourceCollection on Isar {
  IsarCollection<ExtensionSource> get extensionSources => this.collection();
}

const ExtensionSourceSchema = CollectionSchema(
  name: r'ExtensionSource',
  id: -4149751665871021609,
  properties: {
    r'apkPath': PropertySchema(id: 0, name: r'apkPath', type: IsarType.string),
    r'baseUrl': PropertySchema(id: 1, name: r'baseUrl', type: IsarType.string),
    r'className': PropertySchema(
      id: 2,
      name: r'className',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 3,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'iconUrl': PropertySchema(id: 4, name: r'iconUrl', type: IsarType.string),
    r'isActive': PropertySchema(id: 5, name: r'isActive', type: IsarType.bool),
    r'isInstalled': PropertySchema(
      id: 6,
      name: r'isInstalled',
      type: IsarType.bool,
    ),
    r'isNsfw': PropertySchema(id: 7, name: r'isNsfw', type: IsarType.bool),
    r'isObsolete': PropertySchema(
      id: 8,
      name: r'isObsolete',
      type: IsarType.bool,
    ),
    r'isPinned': PropertySchema(id: 9, name: r'isPinned', type: IsarType.bool),
    r'isUpdateAvailable': PropertySchema(
      id: 10,
      name: r'isUpdateAvailable',
      type: IsarType.bool,
    ),
    r'lang': PropertySchema(id: 11, name: r'lang', type: IsarType.string),
    r'name': PropertySchema(id: 12, name: r'name', type: IsarType.string),
    r'pkgName': PropertySchema(id: 13, name: r'pkgName', type: IsarType.string),
    r'repoUrl': PropertySchema(id: 14, name: r'repoUrl', type: IsarType.string),
    r'signatureHash': PropertySchema(
      id: 15,
      name: r'signatureHash',
      type: IsarType.string,
    ),
    r'sourceCodeLanguage': PropertySchema(
      id: 16,
      name: r'sourceCodeLanguage',
      type: IsarType.string,
    ),
    r'sourceCodeUrl': PropertySchema(
      id: 17,
      name: r'sourceCodeUrl',
      type: IsarType.string,
    ),
    r'sourceId': PropertySchema(
      id: 18,
      name: r'sourceId',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 19,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'version': PropertySchema(id: 20, name: r'version', type: IsarType.string),
    r'versionCode': PropertySchema(
      id: 21,
      name: r'versionCode',
      type: IsarType.long,
    ),
    r'versionLast': PropertySchema(
      id: 22,
      name: r'versionLast',
      type: IsarType.string,
    ),
  },

  estimateSize: _extensionSourceEstimateSize,
  serialize: _extensionSourceSerialize,
  deserialize: _extensionSourceDeserialize,
  deserializeProp: _extensionSourceDeserializeProp,
  idName: r'id',
  indexes: {
    r'sourceId': IndexSchema(
      id: 2155220942429093580,
      name: r'sourceId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'sourceId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _extensionSourceGetId,
  getLinks: _extensionSourceGetLinks,
  attach: _extensionSourceAttach,
  version: '3.3.2',
);

int _extensionSourceEstimateSize(
  ExtensionSource object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.apkPath.length * 3;
  {
    final value = object.baseUrl;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.className.length * 3;
  {
    final value = object.iconUrl;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.lang.length * 3;
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.pkgName.length * 3;
  {
    final value = object.repoUrl;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.signatureHash.length * 3;
  bytesCount += 3 + object.sourceCodeLanguage.length * 3;
  {
    final value = object.sourceCodeUrl;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.sourceId.length * 3;
  bytesCount += 3 + object.version.length * 3;
  {
    final value = object.versionLast;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _extensionSourceSerialize(
  ExtensionSource object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.apkPath);
  writer.writeString(offsets[1], object.baseUrl);
  writer.writeString(offsets[2], object.className);
  writer.writeDateTime(offsets[3], object.createdAt);
  writer.writeString(offsets[4], object.iconUrl);
  writer.writeBool(offsets[5], object.isActive);
  writer.writeBool(offsets[6], object.isInstalled);
  writer.writeBool(offsets[7], object.isNsfw);
  writer.writeBool(offsets[8], object.isObsolete);
  writer.writeBool(offsets[9], object.isPinned);
  writer.writeBool(offsets[10], object.isUpdateAvailable);
  writer.writeString(offsets[11], object.lang);
  writer.writeString(offsets[12], object.name);
  writer.writeString(offsets[13], object.pkgName);
  writer.writeString(offsets[14], object.repoUrl);
  writer.writeString(offsets[15], object.signatureHash);
  writer.writeString(offsets[16], object.sourceCodeLanguage);
  writer.writeString(offsets[17], object.sourceCodeUrl);
  writer.writeString(offsets[18], object.sourceId);
  writer.writeDateTime(offsets[19], object.updatedAt);
  writer.writeString(offsets[20], object.version);
  writer.writeLong(offsets[21], object.versionCode);
  writer.writeString(offsets[22], object.versionLast);
}

ExtensionSource _extensionSourceDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ExtensionSource(
    apkPath: reader.readString(offsets[0]),
    baseUrl: reader.readStringOrNull(offsets[1]),
    className: reader.readString(offsets[2]),
    createdAt: reader.readDateTimeOrNull(offsets[3]),
    iconUrl: reader.readStringOrNull(offsets[4]),
    id: id,
    isActive: reader.readBoolOrNull(offsets[5]) ?? true,
    isInstalled: reader.readBoolOrNull(offsets[6]) ?? true,
    isNsfw: reader.readBoolOrNull(offsets[7]) ?? false,
    isObsolete: reader.readBoolOrNull(offsets[8]) ?? false,
    isPinned: reader.readBoolOrNull(offsets[9]) ?? false,
    lang: reader.readString(offsets[11]),
    name: reader.readString(offsets[12]),
    pkgName: reader.readStringOrNull(offsets[13]) ?? '',
    repoUrl: reader.readStringOrNull(offsets[14]),
    signatureHash: reader.readStringOrNull(offsets[15]) ?? '',
    sourceCodeLanguage: reader.readStringOrNull(offsets[16]) ?? 'mihon',
    sourceCodeUrl: reader.readStringOrNull(offsets[17]),
    sourceId: reader.readString(offsets[18]),
    updatedAt: reader.readDateTimeOrNull(offsets[19]),
    version: reader.readString(offsets[20]),
    versionCode: reader.readLongOrNull(offsets[21]) ?? 0,
    versionLast: reader.readStringOrNull(offsets[22]),
  );
  return object;
}

P _extensionSourceDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readBoolOrNull(offset) ?? true) as P;
    case 6:
      return (reader.readBoolOrNull(offset) ?? true) as P;
    case 7:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 8:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 9:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 10:
      return (reader.readBool(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 16:
      return (reader.readStringOrNull(offset) ?? 'mihon') as P;
    case 17:
      return (reader.readStringOrNull(offset)) as P;
    case 18:
      return (reader.readString(offset)) as P;
    case 19:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 20:
      return (reader.readString(offset)) as P;
    case 21:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 22:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _extensionSourceGetId(ExtensionSource object) {
  return object.id ?? Isar.autoIncrement;
}

List<IsarLinkBase<dynamic>> _extensionSourceGetLinks(ExtensionSource object) {
  return [];
}

void _extensionSourceAttach(
  IsarCollection<dynamic> col,
  Id id,
  ExtensionSource object,
) {
  object.id = id;
}

extension ExtensionSourceByIndex on IsarCollection<ExtensionSource> {
  Future<ExtensionSource?> getBySourceId(String sourceId) {
    return getByIndex(r'sourceId', [sourceId]);
  }

  ExtensionSource? getBySourceIdSync(String sourceId) {
    return getByIndexSync(r'sourceId', [sourceId]);
  }

  Future<bool> deleteBySourceId(String sourceId) {
    return deleteByIndex(r'sourceId', [sourceId]);
  }

  bool deleteBySourceIdSync(String sourceId) {
    return deleteByIndexSync(r'sourceId', [sourceId]);
  }

  Future<List<ExtensionSource?>> getAllBySourceId(List<String> sourceIdValues) {
    final values = sourceIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'sourceId', values);
  }

  List<ExtensionSource?> getAllBySourceIdSync(List<String> sourceIdValues) {
    final values = sourceIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'sourceId', values);
  }

  Future<int> deleteAllBySourceId(List<String> sourceIdValues) {
    final values = sourceIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'sourceId', values);
  }

  int deleteAllBySourceIdSync(List<String> sourceIdValues) {
    final values = sourceIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'sourceId', values);
  }

  Future<Id> putBySourceId(ExtensionSource object) {
    return putByIndex(r'sourceId', object);
  }

  Id putBySourceIdSync(ExtensionSource object, {bool saveLinks = true}) {
    return putByIndexSync(r'sourceId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllBySourceId(List<ExtensionSource> objects) {
    return putAllByIndex(r'sourceId', objects);
  }

  List<Id> putAllBySourceIdSync(
    List<ExtensionSource> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'sourceId', objects, saveLinks: saveLinks);
  }
}

extension ExtensionSourceQueryWhereSort
    on QueryBuilder<ExtensionSource, ExtensionSource, QWhere> {
  QueryBuilder<ExtensionSource, ExtensionSource, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ExtensionSourceQueryWhere
    on QueryBuilder<ExtensionSource, ExtensionSource, QWhereClause> {
  QueryBuilder<ExtensionSource, ExtensionSource, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterWhereClause>
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

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterWhereClause> idBetween(
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

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterWhereClause>
  sourceIdEqualTo(String sourceId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'sourceId', value: [sourceId]),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterWhereClause>
  sourceIdNotEqualTo(String sourceId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'sourceId',
                lower: [],
                upper: [sourceId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'sourceId',
                lower: [sourceId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'sourceId',
                lower: [sourceId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'sourceId',
                lower: [],
                upper: [sourceId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension ExtensionSourceQueryFilter
    on QueryBuilder<ExtensionSource, ExtensionSource, QFilterCondition> {
  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  apkPathEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'apkPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  apkPathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'apkPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  apkPathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'apkPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  apkPathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'apkPath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  apkPathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'apkPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  apkPathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'apkPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  apkPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'apkPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  apkPathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'apkPath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  apkPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'apkPath', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  apkPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'apkPath', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  baseUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'baseUrl'),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  baseUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'baseUrl'),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  baseUrlEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'baseUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  baseUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'baseUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  baseUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'baseUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  baseUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'baseUrl',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  baseUrlStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'baseUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  baseUrlEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'baseUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  baseUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'baseUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  baseUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'baseUrl',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  baseUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'baseUrl', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  baseUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'baseUrl', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  classNameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'className',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  classNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'className',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  classNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'className',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  classNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'className',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  classNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'className',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  classNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'className',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  classNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'className',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  classNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'className',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  classNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'className', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  classNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'className', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  createdAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'createdAt'),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  createdAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'createdAt'),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  createdAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  createdAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  createdAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  createdAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  iconUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'iconUrl'),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  iconUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'iconUrl'),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  iconUrlEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'iconUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  iconUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'iconUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  iconUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'iconUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  iconUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'iconUrl',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  iconUrlStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'iconUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  iconUrlEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'iconUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  iconUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'iconUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  iconUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'iconUrl',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  iconUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'iconUrl', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  iconUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'iconUrl', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  idIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'id'),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  idIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'id'),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  idEqualTo(Id? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
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

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
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

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
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

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  isActiveEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isActive', value: value),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  isInstalledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isInstalled', value: value),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  isNsfwEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isNsfw', value: value),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  isObsoleteEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isObsolete', value: value),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  isPinnedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isPinned', value: value),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  isUpdateAvailableEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isUpdateAvailable', value: value),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  langEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lang',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  langGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lang',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  langLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lang',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  langBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lang',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  langStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'lang',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  langEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'lang',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  langContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'lang',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  langMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'lang',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  langIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lang', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  langIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'lang', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  nameEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
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

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  nameLessThan(
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

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  nameBetween(
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

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
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

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  nameEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  nameContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  nameMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  pkgNameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'pkgName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  pkgNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'pkgName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  pkgNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'pkgName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  pkgNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'pkgName',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  pkgNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'pkgName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  pkgNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'pkgName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  pkgNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'pkgName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  pkgNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'pkgName',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  pkgNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'pkgName', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  pkgNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'pkgName', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  repoUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'repoUrl'),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  repoUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'repoUrl'),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  repoUrlEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'repoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  repoUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'repoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  repoUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'repoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  repoUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'repoUrl',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  repoUrlStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'repoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  repoUrlEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'repoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  repoUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'repoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  repoUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'repoUrl',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  repoUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'repoUrl', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  repoUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'repoUrl', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  signatureHashEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'signatureHash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  signatureHashGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'signatureHash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  signatureHashLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'signatureHash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  signatureHashBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'signatureHash',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  signatureHashStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'signatureHash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  signatureHashEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'signatureHash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  signatureHashContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'signatureHash',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  signatureHashMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'signatureHash',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  signatureHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'signatureHash', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  signatureHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'signatureHash', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceCodeLanguageEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sourceCodeLanguage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceCodeLanguageGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sourceCodeLanguage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceCodeLanguageLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sourceCodeLanguage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceCodeLanguageBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sourceCodeLanguage',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceCodeLanguageStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'sourceCodeLanguage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceCodeLanguageEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'sourceCodeLanguage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceCodeLanguageContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'sourceCodeLanguage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceCodeLanguageMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'sourceCodeLanguage',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceCodeLanguageIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sourceCodeLanguage', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceCodeLanguageIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'sourceCodeLanguage', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceCodeUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'sourceCodeUrl'),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceCodeUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'sourceCodeUrl'),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceCodeUrlEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sourceCodeUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceCodeUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sourceCodeUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceCodeUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sourceCodeUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceCodeUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sourceCodeUrl',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceCodeUrlStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'sourceCodeUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceCodeUrlEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'sourceCodeUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceCodeUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'sourceCodeUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceCodeUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'sourceCodeUrl',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceCodeUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sourceCodeUrl', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceCodeUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'sourceCodeUrl', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
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

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
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

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
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

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
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

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
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

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
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

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
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

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
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

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sourceId', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  sourceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'sourceId', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  updatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'updatedAt'),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  updatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'updatedAt'),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  updatedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  updatedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  updatedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  updatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'version',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'version',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'version', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'version', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionCodeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'versionCode', value: value),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionCodeGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'versionCode',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionCodeLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'versionCode',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionCodeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'versionCode',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionLastIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'versionLast'),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionLastIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'versionLast'),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionLastEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'versionLast',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionLastGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'versionLast',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionLastLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'versionLast',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionLastBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'versionLast',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionLastStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'versionLast',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionLastEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'versionLast',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionLastContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'versionLast',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionLastMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'versionLast',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionLastIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'versionLast', value: ''),
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterFilterCondition>
  versionLastIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'versionLast', value: ''),
      );
    });
  }
}

extension ExtensionSourceQueryObject
    on QueryBuilder<ExtensionSource, ExtensionSource, QFilterCondition> {}

extension ExtensionSourceQueryLinks
    on QueryBuilder<ExtensionSource, ExtensionSource, QFilterCondition> {}

extension ExtensionSourceQuerySortBy
    on QueryBuilder<ExtensionSource, ExtensionSource, QSortBy> {
  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy> sortByApkPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'apkPath', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByApkPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'apkPath', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy> sortByBaseUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseUrl', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByBaseUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseUrl', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByClassName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'className', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByClassNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'className', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy> sortByIconUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'iconUrl', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByIconUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'iconUrl', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByIsActiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByIsInstalled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isInstalled', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByIsInstalledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isInstalled', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy> sortByIsNsfw() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isNsfw', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByIsNsfwDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isNsfw', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByIsObsolete() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isObsolete', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByIsObsoleteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isObsolete', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByIsPinned() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPinned', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByIsPinnedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPinned', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByIsUpdateAvailable() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUpdateAvailable', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByIsUpdateAvailableDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUpdateAvailable', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy> sortByLang() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lang', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByLangDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lang', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy> sortByPkgName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pkgName', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByPkgNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pkgName', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy> sortByRepoUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repoUrl', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByRepoUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repoUrl', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortBySignatureHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signatureHash', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortBySignatureHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signatureHash', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortBySourceCodeLanguage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceCodeLanguage', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortBySourceCodeLanguageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceCodeLanguage', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortBySourceCodeUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceCodeUrl', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortBySourceCodeUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceCodeUrl', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortBySourceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceId', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortBySourceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceId', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy> sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByVersionCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionCode', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByVersionCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionCode', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByVersionLast() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionLast', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  sortByVersionLastDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionLast', Sort.desc);
    });
  }
}

extension ExtensionSourceQuerySortThenBy
    on QueryBuilder<ExtensionSource, ExtensionSource, QSortThenBy> {
  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy> thenByApkPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'apkPath', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByApkPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'apkPath', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy> thenByBaseUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseUrl', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByBaseUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseUrl', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByClassName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'className', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByClassNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'className', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy> thenByIconUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'iconUrl', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByIconUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'iconUrl', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByIsActiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByIsInstalled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isInstalled', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByIsInstalledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isInstalled', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy> thenByIsNsfw() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isNsfw', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByIsNsfwDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isNsfw', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByIsObsolete() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isObsolete', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByIsObsoleteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isObsolete', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByIsPinned() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPinned', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByIsPinnedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPinned', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByIsUpdateAvailable() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUpdateAvailable', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByIsUpdateAvailableDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUpdateAvailable', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy> thenByLang() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lang', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByLangDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lang', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy> thenByPkgName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pkgName', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByPkgNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pkgName', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy> thenByRepoUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repoUrl', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByRepoUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'repoUrl', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenBySignatureHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signatureHash', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenBySignatureHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signatureHash', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenBySourceCodeLanguage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceCodeLanguage', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenBySourceCodeLanguageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceCodeLanguage', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenBySourceCodeUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceCodeUrl', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenBySourceCodeUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceCodeUrl', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenBySourceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceId', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenBySourceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceId', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy> thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByVersionCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionCode', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByVersionCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionCode', Sort.desc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByVersionLast() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionLast', Sort.asc);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QAfterSortBy>
  thenByVersionLastDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionLast', Sort.desc);
    });
  }
}

extension ExtensionSourceQueryWhereDistinct
    on QueryBuilder<ExtensionSource, ExtensionSource, QDistinct> {
  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct> distinctByApkPath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'apkPath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct> distinctByBaseUrl({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'baseUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct>
  distinctByClassName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'className', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct> distinctByIconUrl({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'iconUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct>
  distinctByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isActive');
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct>
  distinctByIsInstalled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isInstalled');
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct> distinctByIsNsfw() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isNsfw');
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct>
  distinctByIsObsolete() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isObsolete');
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct>
  distinctByIsPinned() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isPinned');
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct>
  distinctByIsUpdateAvailable() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isUpdateAvailable');
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct> distinctByLang({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lang', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct> distinctByPkgName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pkgName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct> distinctByRepoUrl({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'repoUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct>
  distinctBySignatureHash({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'signatureHash',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct>
  distinctBySourceCodeLanguage({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'sourceCodeLanguage',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct>
  distinctBySourceCodeUrl({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'sourceCodeUrl',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct> distinctBySourceId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct>
  distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct> distinctByVersion({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct>
  distinctByVersionCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'versionCode');
    });
  }

  QueryBuilder<ExtensionSource, ExtensionSource, QDistinct>
  distinctByVersionLast({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'versionLast', caseSensitive: caseSensitive);
    });
  }
}

extension ExtensionSourceQueryProperty
    on QueryBuilder<ExtensionSource, ExtensionSource, QQueryProperty> {
  QueryBuilder<ExtensionSource, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ExtensionSource, String, QQueryOperations> apkPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'apkPath');
    });
  }

  QueryBuilder<ExtensionSource, String?, QQueryOperations> baseUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'baseUrl');
    });
  }

  QueryBuilder<ExtensionSource, String, QQueryOperations> classNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'className');
    });
  }

  QueryBuilder<ExtensionSource, DateTime?, QQueryOperations>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<ExtensionSource, String?, QQueryOperations> iconUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'iconUrl');
    });
  }

  QueryBuilder<ExtensionSource, bool, QQueryOperations> isActiveProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isActive');
    });
  }

  QueryBuilder<ExtensionSource, bool, QQueryOperations> isInstalledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isInstalled');
    });
  }

  QueryBuilder<ExtensionSource, bool, QQueryOperations> isNsfwProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isNsfw');
    });
  }

  QueryBuilder<ExtensionSource, bool, QQueryOperations> isObsoleteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isObsolete');
    });
  }

  QueryBuilder<ExtensionSource, bool, QQueryOperations> isPinnedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isPinned');
    });
  }

  QueryBuilder<ExtensionSource, bool, QQueryOperations>
  isUpdateAvailableProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isUpdateAvailable');
    });
  }

  QueryBuilder<ExtensionSource, String, QQueryOperations> langProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lang');
    });
  }

  QueryBuilder<ExtensionSource, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<ExtensionSource, String, QQueryOperations> pkgNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pkgName');
    });
  }

  QueryBuilder<ExtensionSource, String?, QQueryOperations> repoUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'repoUrl');
    });
  }

  QueryBuilder<ExtensionSource, String, QQueryOperations>
  signatureHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'signatureHash');
    });
  }

  QueryBuilder<ExtensionSource, String, QQueryOperations>
  sourceCodeLanguageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceCodeLanguage');
    });
  }

  QueryBuilder<ExtensionSource, String?, QQueryOperations>
  sourceCodeUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceCodeUrl');
    });
  }

  QueryBuilder<ExtensionSource, String, QQueryOperations> sourceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceId');
    });
  }

  QueryBuilder<ExtensionSource, DateTime?, QQueryOperations>
  updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<ExtensionSource, String, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }

  QueryBuilder<ExtensionSource, int, QQueryOperations> versionCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'versionCode');
    });
  }

  QueryBuilder<ExtensionSource, String?, QQueryOperations>
  versionLastProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'versionLast');
    });
  }
}

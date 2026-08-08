class Filter {
  final String key;
  final String name;
  final FilterType type;
  final dynamic value;
  final List<FilterOption>? options;
  final List<Filter>? subFilters;

  /// Mangayomi `type` field (e.g. `"searchType"`) — distinct from [type] enum.
  final String? filterTypeId;

  /// Mangayomi `type_name` (e.g. `"SelectFilter"`).
  final String? typeName;

  const Filter({
    required this.key,
    required this.name,
    required this.type,
    this.value,
    this.options,
    this.subFilters,
    this.filterTypeId,
    this.typeName,
  });

  /// Keiyoushi / Mihon APK shape (`type` + `value` + `options` strings).
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'name': name, 'type': _typeToKotlin(type)};
    if (type == FilterType.sort) {
      final sel = value;
      json['value'] = sel != null
          ? {'index': (sel as Map)['index'], 'ascending': (sel)['ascending']}
          : null;
    } else if (type == FilterType.group) {
      json['value'] = subFilters?.map((f) => f.toJson()).toList() ?? [];
    } else {
      json['value'] = value;
    }
    if (options != null && options!.isNotEmpty) {
      json['options'] = options!.map((o) => o.name).toList();
    }
    return json;
  }

  /// Mangayomi JS shape (`type_name` + `state` + `values`) for `search()`.
  Map<String, dynamic> toJsJson() {
    final id = filterTypeId ?? key;
    return switch (type) {
      FilterType.text => {
        'type': id,
        'name': name,
        'state': value as String? ?? '',
        'type_name': 'TextFilter',
      },
      FilterType.check => {
        'type': id,
        'name': name,
        'value': options?.isNotEmpty == true ? options!.first.value : name,
        'state': value as bool? ?? false,
        'type_name': 'CheckBox',
      },
      FilterType.triState => {
        'type': id,
        'name': name,
        'value': options?.isNotEmpty == true ? options!.first.value : name,
        'state': value as int? ?? 0,
        'type_name': 'TriState',
      },
      FilterType.select => {
        'type': id,
        'name': name,
        'state': value as int? ?? 0,
        'values': (options ?? [])
            .map(
              (o) => {
                'name': o.name,
                'value': o.value,
                'type_name': 'SelectOption',
              },
            )
            .toList(),
        'type_name': 'SelectFilter',
      },
      FilterType.sort => {
        'type': id,
        'name': name,
        'state': value is Map
            ? {
                'index': (value as Map)['index'] ?? 0,
                'ascending': (value as Map)['ascending'] ?? false,
                'type_name': 'SortState',
              }
            : {'index': 0, 'ascending': false, 'type_name': 'SortState'},
        'values': (options ?? [])
            .map(
              (o) => {
                'name': o.name,
                'value': o.value,
                'type_name': 'SelectOption',
              },
            )
            .toList(),
        'type_name': 'SortFilter',
      },
      FilterType.group => {
        'type': id,
        'name': name,
        'state': (subFilters ?? []).map((f) => f.toJsJson()).toList(),
        'type_name': 'GroupFilter',
      },
      FilterType.header => {
        'type': id.isEmpty ? '' : id,
        'name': name,
        'type_name': 'HeaderFilter',
      },
      FilterType.separator => {
        'type': id.isEmpty ? '' : id,
        'type_name': 'SeparatorFilter',
      },
    };
  }

  factory Filter.fromJson(Map<String, dynamic> json) {
    final typeName = json['type_name'] as String?;
    if (typeName != null && typeName.isNotEmpty) {
      return Filter._fromMangayomi(json, typeName);
    }
    return Filter._fromKeiyoushi(json);
  }

  factory Filter._fromKeiyoushi(Map<String, dynamic> json) {
    final kotlinType = json['type'] as String? ?? 'text';
    final type = _typeFromKotlin(kotlinType);
    dynamic value = json['value'];
    List<Filter>? subFilters;
    List<FilterOption>? opts;

    if (type == FilterType.group) {
      if (value is List) {
        subFilters = value
            .map((e) => Filter.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      value = null;
    } else if (type == FilterType.select || type == FilterType.sort) {
      final rawOpts = json['options'] as List?;
      if (rawOpts != null) {
        opts = rawOpts
            .map((o) => FilterOption(name: o.toString(), value: o.toString()))
            .toList();
      }
    }

    return Filter(
      key: json['name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: type,
      value: value,
      options: opts,
      subFilters: subFilters,
    );
  }

  factory Filter._fromMangayomi(Map<String, dynamic> json, String typeName) {
    final name = json['name'] as String? ?? '';
    final typeId = json['type'] as String? ?? '';
    final key = typeId.isNotEmpty ? typeId : name;

    switch (typeName) {
      case 'SelectFilter':
        return Filter(
          key: key,
          name: name,
          type: FilterType.select,
          value: json['state'] as int? ??
              (json['state'] is num ? (json['state'] as num).toInt() : 0),
          options: _optionsFromValues(json['values']),
          filterTypeId: typeId.isNotEmpty ? typeId : null,
          typeName: typeName,
        );
      case 'TextFilter':
        return Filter(
          key: key,
          name: name,
          type: FilterType.text,
          value: json['state'] as String? ?? '',
          filterTypeId: typeId.isNotEmpty ? typeId : null,
          typeName: typeName,
        );
      case 'CheckBox':
        return Filter(
          key: key,
          name: name,
          type: FilterType.check,
          value: json['state'] as bool? ?? false,
          options: [
            FilterOption(
              name: name,
              value: json['value'] as String? ?? name,
            ),
          ],
          filterTypeId: typeId.isNotEmpty ? typeId : null,
          typeName: typeName,
        );
      case 'TriState':
        return Filter(
          key: key,
          name: name,
          type: FilterType.triState,
          value: json['state'] as int? ?? 0,
          options: [
            FilterOption(
              name: name,
              value: json['value'] as String? ?? name,
            ),
          ],
          filterTypeId: typeId.isNotEmpty ? typeId : null,
          typeName: typeName,
        );
      case 'SortFilter':
        final rawState = json['state'];
        Map<String, dynamic>? sortState;
        if (rawState is Map) {
          sortState = {
            'index': rawState['index'] ?? 0,
            'ascending': rawState['ascending'] ?? false,
          };
        }
        return Filter(
          key: key,
          name: name,
          type: FilterType.sort,
          value: sortState,
          options: _optionsFromValues(json['values']),
          filterTypeId: typeId.isNotEmpty ? typeId : null,
          typeName: typeName,
        );
      case 'GroupFilter':
        final rawState = json['state'];
        final subs = <Filter>[];
        if (rawState is List) {
          for (final e in rawState) {
            if (e is Map) {
              subs.add(Filter.fromJson(Map<String, dynamic>.from(e)));
            }
          }
        }
        return Filter(
          key: key,
          name: name,
          type: FilterType.group,
          subFilters: subs,
          filterTypeId: typeId.isNotEmpty ? typeId : null,
          typeName: typeName,
        );
      case 'HeaderFilter':
        return Filter(
          key: key,
          name: name,
          type: FilterType.header,
          filterTypeId: typeId.isNotEmpty ? typeId : null,
          typeName: typeName,
        );
      case 'SeparatorFilter':
        return Filter(
          key: key,
          name: name.isEmpty ? 'separator' : name,
          type: FilterType.separator,
          filterTypeId: typeId.isNotEmpty ? typeId : null,
          typeName: typeName,
        );
      default:
        return Filter(
          key: key,
          name: name,
          type: FilterType.text,
          value: json['state'] ?? json['value'] ?? '',
          filterTypeId: typeId.isNotEmpty ? typeId : null,
          typeName: typeName,
        );
    }
  }

  static List<FilterOption>? _optionsFromValues(dynamic raw) {
    if (raw is! List) return null;
    return raw.map((o) {
      if (o is Map) {
        final m = Map<String, dynamic>.from(o);
        final n = m['name']?.toString() ?? '';
        final v = m['value']?.toString() ?? n;
        return FilterOption(name: n, value: v);
      }
      return FilterOption(name: o.toString(), value: o.toString());
    }).toList();
  }

  static String _typeToKotlin(FilterType t) => switch (t) {
    FilterType.text => 'text',
    FilterType.check => 'check',
    FilterType.select => 'select',
    FilterType.sort => 'sort',
    FilterType.group => 'group',
    FilterType.header => 'header',
    FilterType.separator => 'separator',
    FilterType.triState => 'triState',
  };

  static FilterType _typeFromKotlin(String t) => switch (t) {
    'text' => FilterType.text,
    'check' => FilterType.check,
    'select' => FilterType.select,
    'sort' => FilterType.sort,
    'group' => FilterType.group,
    'header' => FilterType.header,
    'separator' => FilterType.separator,
    'triState' => FilterType.triState,
    _ => FilterType.text,
  };
}

class FilterOption {
  final String name;
  final String value;

  const FilterOption({required this.name, required this.value});

  Map<String, dynamic> toJson() => {'name': name, 'value': value};

  factory FilterOption.fromJson(Map<String, dynamic> json) => FilterOption(
    name: json['name'] as String? ?? '',
    value: json['value'] as String? ?? '',
  );
}

enum FilterType {
  text,
  check,
  select,
  sort,
  group,
  header,
  separator,
  triState,
}

class FilterList {
  final List<Filter> filters;

  const FilterList({this.filters = const []});

  factory FilterList.fromJson(List<dynamic> json) => FilterList(
    filters: json
        .map((e) => Filter.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );

  List<Map<String, dynamic>> toJson() =>
      filters.map((f) => f.toJson()).toList();

  /// Mangayomi-compatible filter array for JS `search(query, page, filters)`.
  List<Map<String, dynamic>> toJsJson() =>
      filters.map((f) => f.toJsJson()).toList();
}

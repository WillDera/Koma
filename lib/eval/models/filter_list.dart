class Filter {
  final String key;
  final String name;
  final FilterType type;
  final dynamic value;
  final List<FilterOption>? options;
  final List<Filter>? subFilters;

  const Filter({
    required this.key,
    required this.name,
    required this.type,
    this.value,
    this.options,
    this.subFilters,
  });

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

  factory Filter.fromJson(Map<String, dynamic> json) {
    final kotlinType = json['type'] as String? ?? 'text';
    final type = _typeFromKotlin(kotlinType);
    dynamic value = json['value'];
    List<Filter>? subFilters;
    List<FilterOption>? opts;

    if (type == FilterType.group) {
      if (value is List) {
        subFilters = value
            .map((e) => Filter.fromJson(Map<String, dynamic>.from(e)))
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
        .map((e) => Filter.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );

  List<Map<String, dynamic>> toJson() =>
      filters.map((f) => f.toJson()).toList();
}

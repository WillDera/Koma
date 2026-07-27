class Filter {
  final String key;
  final String name;
  final FilterType type;
  final dynamic value;
  final List<FilterOption>? options;

  const Filter({
    required this.key,
    required this.name,
    required this.type,
    this.value,
    this.options,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'type': type.name,
        'value': value,
        if (options != null) 'options': options!.map((o) => o.toJson()).toList(),
      };

  factory Filter.fromJson(Map<String, dynamic> json) => Filter(
        key: json['key'] as String? ?? '',
        name: json['name'] as String? ?? '',
        type: FilterType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => FilterType.text,
        ),
        value: json['value'],
        options: json['options'] != null
            ? (json['options'] as List).map((o) => FilterOption.fromJson(Map<String, dynamic>.from(o))).toList()
            : null,
      );
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

enum FilterType { text, check, select, sort, group, header, separator, triState }

class FilterList {
  final List<Filter> filters;

  const FilterList({this.filters = const []});

  factory FilterList.fromJson(List<dynamic> json) => FilterList(
        filters: json.map((e) => Filter.fromJson(Map<String, dynamic>.from(e))).toList(),
      );
}

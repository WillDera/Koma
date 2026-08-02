class MPage {
  final int index;
  final String url;
  final Map<String, String>? headers;

  const MPage({required this.index, required this.url, this.headers});

  Map<String, dynamic> toJson() => {
    'index': index,
    'url': url,
    if (headers != null) 'headers': headers,
  };

  factory MPage.fromJson(Map<String, dynamic> json) => MPage(
    index: json['index'] as int? ?? 0,
    url: json['url'] as String? ?? '',
    headers: json['headers'] != null
        ? Map<String, String>.from(json['headers'] as Map)
        : null,
  );

  factory MPage.fromMap(Map<String, dynamic> map) => MPage.fromJson(map);

  factory MPage.fromDynamic(dynamic d) {
    if (d is Map<String, dynamic>) return MPage.fromJson(d);
    if (d is Map) {
      return MPage.fromJson(Map<String, dynamic>.from(d));
    }
    throw ArgumentError('Expected Map, got ${d.runtimeType}');
  }
}

class MPages {
  final List<MPage> pages;

  const MPages({required this.pages});

  factory MPages.fromJson(List<dynamic> json) => MPages(
    pages: json
        .map((e) => MPage.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );

  factory MPages.fromList(List<Map<String, dynamic>> list) =>
      MPages(pages: list.map(MPage.fromJson).toList());
}

import 'package:koma/eval/javascript/http_map_extensions.dart';

/// Chapter page URL returned by Dart `getPageList` (mangayomi [PageUrl]).
class PageUrl {
  String url;
  String? fileName;
  Map<String, String>? headers;

  PageUrl(this.url, {this.fileName, this.headers});

  factory PageUrl.fromJson(Map<String, dynamic> json) {
    return PageUrl(
      json['url'].toString().trim(),
      headers: (json['headers'] as Map?)?.toMapStringString,
      fileName: json['fileName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'headers': headers,
        'fileName': fileName,
      };

  @override
  String toString() {
    return 'PageUrl(url: $url, headers: $headers, fileName: $fileName)';
  }
}

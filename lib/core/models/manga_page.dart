class MangaPage {
  final int index;
  final String imageUrl;
  final Map<String, String>? headers;
  final String? localPath;
  /// The chapter URL this page belongs to, for multi-chapter seamless reading.
  /// Empty string means the current chapter loaded by the reader.
  final String chapterUrl;

  const MangaPage({
    required this.index,
    required this.imageUrl,
    this.headers,
    this.localPath,
    this.chapterUrl = '',
  });
}

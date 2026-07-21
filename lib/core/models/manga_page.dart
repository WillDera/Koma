class MangaPage {
  final int index;
  final String imageUrl;
  final Map<String, String>? headers;
  final String? localPath;

  const MangaPage({
    required this.index,
    required this.imageUrl,
    this.headers,
    this.localPath,
  });
}

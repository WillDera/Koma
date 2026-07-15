class MangaPage {
  final int index;
  final String imageUrl;
  final Map<String, String>? headers;

  const MangaPage({
    required this.index,
    required this.imageUrl,
    this.headers,
  });
}

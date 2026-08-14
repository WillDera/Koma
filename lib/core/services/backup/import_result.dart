class ImportResult {
  final int booksImported;
  final int booksSkipped;
  final int chaptersImported;
  final int chaptersSkipped;
  final int snippetsImported;
  final int snippetsSkipped;
  final int mangaImported;
  final int mangaSkipped;
  final int mangaChaptersImported;
  final int categoriesImported;
  final int reposImported;
  final int cookiesImported;
  final List<String> missingSources;
  final int skippedAnime;
  final int skippedNovels;
  final int version;

  const ImportResult({
    required this.booksImported,
    required this.booksSkipped,
    required this.chaptersImported,
    required this.chaptersSkipped,
    required this.snippetsImported,
    required this.snippetsSkipped,
    this.mangaImported = 0,
    this.mangaSkipped = 0,
    this.mangaChaptersImported = 0,
    this.categoriesImported = 0,
    this.reposImported = 0,
    this.cookiesImported = 0,
    this.missingSources = const [],
    this.skippedAnime = 0,
    this.skippedNovels = 0,
    required this.version,
  });

  @override
  String toString() {
    final parts = <String>[];
    final totalBooks = booksImported + booksSkipped;
    if (totalBooks > 0) {
      final newCount = booksSkipped > 0
          ? '$booksImported new'
          : '$booksImported';
      parts.add(
        '$newCount book${booksImported == 1 ? '' : 's'}'
        '${booksSkipped > 0 ? ' ($booksSkipped duplicate${booksSkipped == 1 ? '' : 's'} skipped)' : ''}',
      );
    }
    final totalManga = mangaImported + mangaSkipped;
    if (totalManga > 0) {
      final newCount = mangaSkipped > 0
          ? '$mangaImported new'
          : '$mangaImported';
      parts.add(
        '$newCount manga'
        '${mangaSkipped > 0 ? ' ($mangaSkipped already in library)' : ''}',
      );
    }
    if (chaptersImported > 0) {
      parts.add(
        '$chaptersImported chapter${chaptersImported == 1 ? '' : 's'} restored',
      );
    }
    if (mangaChaptersImported > 0) {
      parts.add(
        '$mangaChaptersImported manga chapter${mangaChaptersImported == 1 ? '' : 's'} restored',
      );
    }
    if (chaptersSkipped > 0) {
      parts.add(
        '$chaptersSkipped chapter${chaptersSkipped == 1 ? '' : 's'} skipped',
      );
    }
    if (categoriesImported > 0) {
      parts.add(
        '$categoriesImported categor${categoriesImported == 1 ? 'y' : 'ies'}',
      );
    }
    if (snippetsImported > 0 || snippetsSkipped > 0) {
      parts.add(
        '$snippetsImported snippet${snippetsImported == 1 ? '' : 's'}',
      );
      if (snippetsSkipped > 0) {
        parts.add('$snippetsSkipped skipped');
      }
    }
    if (reposImported > 0) {
      parts.add(
        '$reposImported repo${reposImported == 1 ? '' : 's'}',
      );
    }
    var text = parts.isEmpty ? 'Nothing to import' : 'Imported: ${parts.join(', ')}';
    if (missingSources.isNotEmpty) {
      text +=
          '\n${missingSources.length} source${missingSources.length == 1 ? '' : 's'} not installed: ${missingSources.take(8).join(', ')}'
          '${missingSources.length > 8 ? '…' : ''}';
    }
    if (skippedAnime > 0 || skippedNovels > 0) {
      final skip = <String>[];
      if (skippedAnime > 0) skip.add('$skippedAnime anime');
      if (skippedNovels > 0) skip.add('$skippedNovels novel${skippedNovels == 1 ? '' : 's'}');
      text += '\nSkipped ${skip.join(' and ')}.';
    }
    if (mangaImported + mangaSkipped > 0) {
      text += '\nDownloads and extension APKs are not in the backup.';
    }
    return text;
  }
}

import '../models/manga.dart';
import '../models/manga_chapter.dart';
import '../repositories/extension_repository.dart';
import '../repositories/manga_repository.dart';
import '../repositories/repositories.dart';

/// Thrown when two titles are too different to merge safely.
class MergeValidationException implements Exception {
  MergeValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Absorbs one library manga into another (same / similar title).
///
/// Keeps [keep], merges chapter progress by URL **and** chapter number/name
/// so reading history transfers across sources, unions categories, then removes
/// [absorb] from the library (or deletes it).
class MergeMangaUseCase {
  MergeMangaUseCase(Repositories repositories)
    : _manga = repositories.manga,
      _extensions = repositories.extensions;

  final MangaRepository _manga;
  final ExtensionRepository _extensions;

  Future<Manga> invoke({
    required Manga keep,
    required Manga absorb,
    bool deleteAbsorb = false,
  }) async {
    if (keep.id == absorb.id) {
      throw MergeValidationException('Cannot merge a manga into itself');
    }

    if (!titlesLookCompatible(keep.name, absorb.name)) {
      throw MergeValidationException(
        'These titles look different from each other '
        '("${keep.name}" vs "${absorb.name}"). Merge cancelled — both stay in '
        'the library.',
      );
    }

    final keepChapters = await _manga.getMangaChapters(keep.id);
    final absorbChapters = await _manga.getMangaChapters(absorb.id);

    final keepByUrl = <String, MangaChapter>{
      for (final c in keepChapters)
        if (c.url.isNotEmpty) c.url.trim(): c,
    };
    final absorbByUrl = <String, MangaChapter>{
      for (final c in absorbChapters)
        if (c.url.isNotEmpty) c.url.trim(): c,
    };

    // Progress lookup by chapter number / normalized name when URLs differ.
    final keepByNumber = <double, MangaChapter>{};
    final keepByName = <String, MangaChapter>{};
    for (final c in keepChapters) {
      if (c.chapterNumber > 0) {
        keepByNumber.putIfAbsent(c.chapterNumber, () => c);
      }
      final nk = _normChapterName(c.name);
      if (nk.isNotEmpty) keepByName.putIfAbsent(nk, () => c);
    }

    final absorbProgressByNumber = <double, MangaChapter>{};
    final absorbProgressByName = <String, MangaChapter>{};
    for (final c in absorbChapters) {
      if (c.chapterNumber > 0) {
        absorbProgressByNumber.putIfAbsent(c.chapterNumber, () => c);
      }
      final nk = _normChapterName(c.name);
      if (nk.isNotEmpty) absorbProgressByName.putIfAbsent(nk, () => c);
    }

    final allUrls = {...keepByUrl.keys, ...absorbByUrl.keys};
    final merged = <MangaChapter>[];
    final usedAbsorbUrls = <String>{};
    var index = 0;

    for (final url in allUrls) {
      final k = keepByUrl[url];
      final a = absorbByUrl[url];
      if (k != null && a != null) {
        usedAbsorbUrls.add(url);
        merged.add(_mergeProgress(k, a, index: index++));
      } else if (k != null) {
        // Cross-source: pull progress from absorb by chapter number / name.
        final aProg = (k.chapterNumber > 0
                ? absorbProgressByNumber[k.chapterNumber]
                : null) ??
            absorbProgressByName[_normChapterName(k.name)];
        if (aProg != null) usedAbsorbUrls.add(aProg.url.trim());
        merged.add(
          aProg == null
              ? k.copyWith(index: index++)
              : _mergeProgress(k, aProg, index: index++),
        );
      } else if (a != null) {
        usedAbsorbUrls.add(url);
        // Only add absorb chapter if keep has no equivalent number/name.
        final hasKeep = (a.chapterNumber > 0 &&
                keepByNumber.containsKey(a.chapterNumber)) ||
            keepByName.containsKey(_normChapterName(a.name));
        if (!hasKeep) {
          merged.add(
            a.copyWith(id: 0, mangaId: keep.id, index: index++),
          );
        }
      }
    }

    // Absorb-only chapters not matched above (empty keep chapter list, etc.).
    for (final a in absorbChapters) {
      final url = a.url.trim();
      if (url.isEmpty || usedAbsorbUrls.contains(url)) continue;
      final hasKeep = (a.chapterNumber > 0 &&
              keepByNumber.containsKey(a.chapterNumber)) ||
          keepByName.containsKey(_normChapterName(a.name));
      if (hasKeep) continue;
      merged.add(a.copyWith(id: 0, mangaId: keep.id, index: index++));
    }

    if (merged.isNotEmpty) {
      await _manga.deleteMangaChapters(keep.id);
      await _manga.insertMangaChapters(keep.id, merged);
    }

    final categoryIds = <int>{
      ...keep.categoryIds,
      ...absorb.categoryIds,
    }.toList();
    final notes =
        (keep.notes != null && keep.notes!.trim().isNotEmpty)
        ? keep.notes
        : absorb.notes;
    final customCover =
        (keep.customCoverPath != null && keep.customCoverPath!.isNotEmpty)
        ? keep.customCoverPath
        : absorb.customCoverPath;

    await _manga.updateMangaExtras(
      keep.id,
      categoryIds: categoryIds,
      notes: notes,
      customCoverPath: customCover,
      viewerFlags: keep.viewerFlags != 0 ? keep.viewerFlags : absorb.viewerFlags,
      chapterFlags:
          keep.chapterFlags != 0 ? keep.chapterFlags : absorb.chapterFlags,
    );

    var updatedKeep = (await _manga.getMangaById(keep.id)) ?? keep;
    final absorbImage = absorb.imageUrl?.trim() ?? '';
    final keepImage = updatedKeep.imageUrl?.trim() ?? '';
    if (keepImage.isEmpty && absorbImage.isNotEmpty) {
      updatedKeep = updatedKeep.copyWith(imageUrl: absorb.imageUrl);
    }
    final absorbDesc = absorb.description?.trim() ?? '';
    final keepDesc = updatedKeep.description?.trim() ?? '';
    if (keepDesc.isEmpty && absorbDesc.isNotEmpty) {
      updatedKeep = updatedKeep.copyWith(description: absorb.description);
    }
    // Prefer absorb author/artist when keep is blank — never fail on mismatch.
    if ((updatedKeep.author == null || updatedKeep.author!.trim().isEmpty) &&
        (absorb.author != null && absorb.author!.trim().isNotEmpty)) {
      updatedKeep = updatedKeep.copyWith(author: absorb.author);
    }
    if ((updatedKeep.artist == null || updatedKeep.artist!.trim().isEmpty) &&
        (absorb.artist != null && absorb.artist!.trim().isNotEmpty)) {
      updatedKeep = updatedKeep.copyWith(artist: absorb.artist);
    }
    updatedKeep = updatedKeep.copyWith(
      inLibrary: true,
      updatedAt: DateTime.now(),
    );
    await _manga.updateManga(updatedKeep);

    if (deleteAbsorb) {
      await _manga.deleteManga(absorb.id);
    } else {
      await _manga.setMangaInLibrary(absorb.id, false);
    }

    return (await _manga.getMangaById(keep.id)) ?? updatedKeep;
  }

  /// Resolve a human source label for merge confirmations.
  Future<String> sourceLabel(Manga manga) async {
    final bySource = await _extensions.getBySourceId(manga.sourceId);
    if (bySource != null && bySource.name.trim().isNotEmpty) {
      return bySource.name.trim();
    }
    final installed = await _extensions.getInstalledExtensions();
    for (final e in installed) {
      if (e.id == manga.sourceId || e.sourceId == manga.sourceId) {
        if (e.name.trim().isNotEmpty) return e.name.trim();
      }
    }
    // Last resort: host from URL, never the raw extension id.
    final url = manga.url.trim();
    if (url.startsWith('http')) {
      try {
        return Uri.parse(url).host;
      } catch (_) {}
    }
    return 'Unknown source';
  }

  static MangaChapter _mergeProgress(
    MangaChapter keep,
    MangaChapter absorb, {
    required int index,
  }) {
    final keepReadAt = keep.readAt;
    final absorbReadAt = absorb.readAt;
    DateTime? readAt;
    if (keepReadAt != null && absorbReadAt != null) {
      readAt = keepReadAt.isAfter(absorbReadAt) ? keepReadAt : absorbReadAt;
    } else {
      readAt = keepReadAt ?? absorbReadAt;
    }
    return keep.copyWith(
      isRead: keep.isRead || absorb.isRead,
      isBookmarked: keep.isBookmarked || absorb.isBookmarked,
      isOpened: keep.isOpened || absorb.isOpened,
      isDownloaded: keep.isDownloaded || absorb.isDownloaded,
      lastPageRead: keep.lastPageRead >= absorb.lastPageRead
          ? keep.lastPageRead
          : absorb.lastPageRead,
      scrollPosition: keep.scrollPosition >= absorb.scrollPosition
          ? keep.scrollPosition
          : absorb.scrollPosition,
      readAt: readAt,
      scanlator: (keep.scanlator != null && keep.scanlator!.isNotEmpty)
          ? keep.scanlator
          : absorb.scanlator,
      memo: (keep.memo != null && keep.memo!.isNotEmpty) ? keep.memo : absorb.memo,
      index: index,
    );
  }

  /// Exact (case-insensitive) or substring match after stripping punctuation.
  static bool titlesLookCompatible(String a, String b) {
    final na = _normTitle(a);
    final nb = _normTitle(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    if (na.contains(nb) || nb.contains(na)) return true;
    // Token overlap: at least half of the shorter title's tokens appear in the longer.
    final ta = na.split(RegExp(r'\s+')).where((t) => t.length > 1).toSet();
    final tb = nb.split(RegExp(r'\s+')).where((t) => t.length > 1).toSet();
    if (ta.isEmpty || tb.isEmpty) return false;
    final shorter = ta.length <= tb.length ? ta : tb;
    final longer = ta.length <= tb.length ? tb : ta;
    final hits = shorter.where(longer.contains).length;
    return hits >= (shorter.length + 1) ~/ 2;
  }

  static String _normTitle(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _normChapterName(String s) {
    return s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}

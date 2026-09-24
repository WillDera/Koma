import 'dart:io';
import 'dart:math';

import 'package:recommendation_engine/recommendation_engine.dart';

import '../models/book.dart';
import '../models/manga.dart';
import '../repositories/manga_repository.dart';

enum LibraryHubKind {
  continueReading,
  libraryRecommended,
  exploration,
}

extension LibraryHubKindLabel on LibraryHubKind {
  String get title => switch (this) {
        LibraryHubKind.continueReading => 'Continue reading',
        LibraryHubKind.libraryRecommended => 'Try reading this next',
        LibraryHubKind.exploration => 'You might like this',
      };

  String get subtitle => switch (this) {
        LibraryHubKind.continueReading => 'Pick up where you left off',
        LibraryHubKind.libraryRecommended => 'From your shelf',
        LibraryHubKind.exploration => 'From your sources',
      };
}

/// One title shown inside a hub face / expand grid.
class LibraryHubEntry {
  const LibraryHubEntry({
    required this.title,
    this.subtitle,
    this.coverPathOrUrl,
    this.book,
    this.inProgressManga,
    this.manga,
    this.recommendation,
  });

  final String title;
  final String? subtitle;
  final String? coverPathOrUrl;
  final Book? book;
  final InProgressManga? inProgressManga;
  final Manga? manga;
  final RecommendationItem? recommendation;

  Manga? get mangaRef => manga ?? inProgressManga?.manga;

  bool get hasCoverHint {
    final url = coverPathOrUrl?.trim();
    if (url != null && url.isNotEmpty) return true;
    if (book?.coverPath != null && book!.coverPath!.trim().isNotEmpty) {
      return true;
    }
    final m = mangaRef;
    if (m?.customCoverPath != null && m!.customCoverPath!.trim().isNotEmpty) {
      return true;
    }
    if (m?.imageUrl != null && m!.imageUrl!.trim().isNotEmpty) return true;
    return false;
  }
}

/// One of the three carousel faces.
class LibraryHubFace {
  const LibraryHubFace({
    required this.kind,
    required this.entries,
    required this.coverEntry,
  });

  final LibraryHubKind kind;
  final List<LibraryHubEntry> entries;
  final LibraryHubEntry? coverEntry;

  bool get isEmpty => entries.isEmpty;

  String get title => kind.title;
  String get subtitle => kind.subtitle;
}

class LibraryHubSnapshot {
  const LibraryHubSnapshot({
    required this.faces,
  });

  final List<LibraryHubFace> faces;

  static LibraryHubFace faceFor(
    LibraryHubKind kind,
    List<LibraryHubEntry> entries, {
    int salt = 0,
  }) {
    LibraryHubEntry? cover;
    if (entries.isNotEmpty) {
      final withCovers = [
        for (final e in entries)
          if (e.hasCoverHint) e,
      ];
      final pool = withCovers.isNotEmpty ? withCovers : entries;
      // Continue always shows the most-recent title so the card updates as
      // the user reads. Other faces keep a day-stable random cover.
      if (kind == LibraryHubKind.continueReading) {
        cover = entries.first;
      } else {
        final rng = Random(kind.index * 97 + salt);
        cover = pool[rng.nextInt(pool.length)];
      }
    }
    return LibraryHubFace(kind: kind, entries: entries, coverEntry: cover);
  }
}

/// Resolve a cover path/URL for display (local file or http).
String? hubCoverUrl(LibraryHubEntry? entry) {
  if (entry == null) return null;
  final direct = entry.coverPathOrUrl?.trim();
  if (direct != null && direct.isNotEmpty) return direct;
  final bookPath = entry.book?.coverPath?.trim();
  if (bookPath != null && bookPath.isNotEmpty) return bookPath;
  final m = entry.mangaRef;
  final custom = m?.customCoverPath?.trim();
  if (custom != null && custom.isNotEmpty) return custom;
  final image = m?.imageUrl?.trim();
  if (image != null && image.isNotEmpty) return image;
  return null;
}

bool hubCoverIsLocalFile(String url) {
  final t = url.trim();
  if (t.startsWith('http://') || t.startsWith('https://')) return false;
  if (t.startsWith('file://')) return true;
  return t.startsWith('/') || t.contains(r'\');
}

String hubLocalCoverPath(String url) {
  final t = url.trim();
  if (t.startsWith('file://')) return Uri.parse(t).toFilePath();
  return t;
}

bool hubLocalCoverExists(String url) {
  try {
    return File(hubLocalCoverPath(url)).existsSync();
  } catch (_) {
    return false;
  }
}

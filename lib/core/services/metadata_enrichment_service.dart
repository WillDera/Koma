import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'app_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';
import '../providers.dart';
import '../repositories/book_repository.dart';
import 'cover_enhance_service.dart';
import 'discover_metadata_cache.dart';
import 'http/m_client.dart';
import '../../src/rust/api/metadata.dart' as rust;

const kGoogleBooksApiKeyPref = 'google_books_api_key';

class MetadataEnrichmentProgress {
  const MetadataEnrichmentProgress({
    this.running = false,
    this.current = 0,
    this.total = 0,
    this.lastMessage,
    this.errors = const [],
  });

  final bool running;
  final int current;
  final int total;
  final String? lastMessage;
  final List<String> errors;

  MetadataEnrichmentProgress copyWith({
    bool? running,
    int? current,
    int? total,
    String? lastMessage,
    List<String>? errors,
  }) {
    return MetadataEnrichmentProgress(
      running: running ?? this.running,
      current: current ?? this.current,
      total: total ?? this.total,
      lastMessage: lastMessage ?? this.lastMessage,
      errors: errors ?? this.errors,
    );
  }
}

class MetadataEnrichmentService {
  MetadataEnrichmentService(this._books);

  final BookRepository _books;

  Future<String?> _googleApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(kGoogleBooksApiKeyPref)?.trim();
    if (key == null || key.isEmpty) return null;
    return key;
  }

  Future<rust.BookMetadataResult?> enrichBook(Book book) async {
    final results = await enrichBooks([book]);
    return results.isEmpty ? null : results.first;
  }

  Future<List<rust.BookMetadataResult>> enrichBooks(List<Book> books) async {
    if (books.isEmpty) return const [];

    final key = await _googleApiKey();
    final byId = {for (final b in books) b.id: b};
    final queries = books
        .map(
          (b) => rust.BookLookupQuery(
            id: b.id,
            title: b.title,
            author: b.author,
          ),
        )
        .toList(growable: false);

    final results = await rust.lookupBooks(
      queries: queries,
      googleApiKey: key,
    );

    for (final result in results) {
      if (!result.found) continue;
      final bookId = result.id;
      final existing = byId[bookId];
      String? localCover = existing?.coverPath;
      if (result.coverUrl != null && result.coverUrl!.isNotEmpty) {
        final downloaded = await _downloadCover(bookId, result.coverUrl!);
        if (downloaded != null) {
          localCover = downloaded;
        }
      }

      DateTime? releaseDate;
      if (result.releaseDate != null && result.releaseDate!.isNotEmpty) {
        releaseDate = DateTime.tryParse(result.releaseDate!);
      }

      await _books.applyEnrichment(
        bookId: bookId,
        author: result.author,
        localCoverPath: localCover,
        genres: result.genres,
        releaseDate: releaseDate,
        source: result.source,
        remoteId: result.remoteId,
        coverUrl: result.coverUrl,
        rawTitle: result.title,
      );
    }

    return results;
  }

  /// Apply a Discover-session [DiscoverMetadataHit] after the book is imported.
  /// Skips another Open Library / Google lookup.
  ///
  /// [coverUrlOverride] is the URL actually shown on the Discover card
  /// (enriched cover or LibGen poster). When set, that image is downloaded,
  /// enhanced, and stored as the library cover.
  Future<void> applyDiscoverHit(
    int bookId,
    DiscoverMetadataHit hit, {
    String? coverUrlOverride,
  }) async {
    if (!hit.found &&
        (coverUrlOverride == null || coverUrlOverride.isEmpty)) {
      return;
    }
    String? localCover;
    final coverUrl = (coverUrlOverride != null && coverUrlOverride.isNotEmpty)
        ? coverUrlOverride
        : hit.coverUrl;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      localCover = await downloadAndEnhanceCover(bookId, coverUrl);
    }
    if (!hit.found) {
      if (localCover != null) {
        await _books.applyEnrichment(
          bookId: bookId,
          author: null,
          localCoverPath: localCover,
          genres: const [],
          releaseDate: null,
          source: 'discover',
          remoteId: null,
          coverUrl: coverUrl,
          rawTitle: null,
        );
      }
      return;
    }
    DateTime? releaseDate;
    if (hit.releaseDate != null && hit.releaseDate!.isNotEmpty) {
      releaseDate = DateTime.tryParse(hit.releaseDate!);
    }
    await _books.applyEnrichment(
      bookId: bookId,
      author: hit.author,
      localCoverPath: localCover,
      genres: hit.genres,
      releaseDate: releaseDate,
      source: hit.source,
      remoteId: hit.remoteId,
      coverUrl: hit.coverUrl ?? coverUrl,
      rawTitle: null,
    );
  }

  /// Download [url], enhance for library display, write under `covers/`.
  Future<String?> downloadAndEnhanceCover(int bookId, String url) =>
      _downloadCover(bookId, url);

  Future<String?> _downloadCover(int bookId, String url) async {
    try {
      var resolved = preferMediumCoverUrl(url);
      if (resolved.startsWith('http://')) {
        resolved = resolved.replaceFirst('http://', 'https://');
      }
      final uri = Uri.parse(resolved);
      final client = http.Client();
      try {
        final request = http.Request('GET', uri);
        request.headers['User-Agent'] = kBrowserUserAgent;
        request.headers['Accept'] = 'image/avif,image/webp,image/*,*/*;q=0.8';
        if (uri.host.contains('openlibrary.org')) {
          request.headers['Referer'] = 'https://openlibrary.org/';
        } else if (uri.host.contains('googleapis.com') ||
            uri.host.contains('googleusercontent.com')) {
          request.headers['Referer'] = 'https://books.google.com/';
        } else if (uri.host.contains('libgen')) {
          request.headers['Referer'] = 'https://libgen.li/';
        }
        final streamed = await client
            .send(request)
            .timeout(const Duration(seconds: 45));
        if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
          return null;
        }
        final body = await streamed.stream.toBytes().timeout(
          const Duration(seconds: 45),
        );
        if (body.isEmpty) return null;

        final enhanced = await CoverEnhanceService.enhance(body);

        final appDir = await AppStorage.documents();
        final coverDir = Directory(p.join(appDir.path, 'covers'));
        if (!await coverDir.exists()) {
          await coverDir.create(recursive: true);
        }
        // Enhanced output is always JPEG.
        final file = File(
          p.join(
            coverDir.path,
            '${bookId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        );
        await file.writeAsBytes(enhanced, flush: true);
        return file.path;
      } finally {
        client.close();
      }
    } catch (e, st) {
      debugPrint('cover download failed: $e\n$st');
      return null;
    }
  }
}

class MetadataEnrichmentNotifier extends Notifier<MetadataEnrichmentProgress> {
  @override
  MetadataEnrichmentProgress build() => const MetadataEnrichmentProgress();

  MetadataEnrichmentService get _service =>
      MetadataEnrichmentService(ref.read(repositoriesProvider).books);

  Future<void> enrichOne(Book book) async {
    if (state.running) return;
    state = MetadataEnrichmentProgress(
      running: true,
      current: 0,
      total: 1,
      lastMessage: 'Looking up ${book.title}…',
    );
    try {
      final result = await _service.enrichBook(book);
      final errors = <String>[];
      if (result == null || !result.found) {
        errors.add(result?.error ?? 'No metadata found for "${book.title}"');
      }
      state = MetadataEnrichmentProgress(
        running: false,
        current: 1,
        total: 1,
        lastMessage: errors.isEmpty
            ? 'Updated "${book.title}"'
            : errors.first,
        errors: errors,
      );
    } catch (e) {
      state = MetadataEnrichmentProgress(
        running: false,
        current: 1,
        total: 1,
        lastMessage: 'Failed: $e',
        errors: ['$e'],
      );
    }
  }

  Future<void> enrichAll(List<Book> books) async {
    if (state.running || books.isEmpty) return;
    state = MetadataEnrichmentProgress(
      running: true,
      current: 0,
      total: books.length,
      lastMessage: 'Looking up ${books.length} books…',
    );
    final errors = <String>[];
    var found = 0;
    try {
      // Process in small batches so progress updates are visible.
      const batchSize = 5;
      for (var i = 0; i < books.length; i += batchSize) {
        final batch = books.sublist(
          i,
          i + batchSize > books.length ? books.length : i + batchSize,
        );
        final results = await _service.enrichBooks(batch);
        for (final r in results) {
          if (r.found) {
            found++;
          } else if (r.error != null) {
            errors.add('${r.title}: ${r.error}');
          } else {
            errors.add('No metadata for "${r.title}"');
          }
        }
        state = state.copyWith(
          current: i + batch.length,
          lastMessage: 'Processed ${i + batch.length}/${books.length}…',
          errors: List<String>.from(errors),
        );
      }
      state = MetadataEnrichmentProgress(
        running: false,
        current: books.length,
        total: books.length,
        lastMessage: 'Updated $found of ${books.length} books',
        errors: errors,
      );
    } catch (e) {
      state = MetadataEnrichmentProgress(
        running: false,
        current: state.current,
        total: books.length,
        lastMessage: 'Failed: $e',
        errors: [...errors, '$e'],
      );
    }
  }
}

final metadataEnrichmentProvider =
    NotifierProvider<MetadataEnrichmentNotifier, MetadataEnrichmentProgress>(
  MetadataEnrichmentNotifier.new,
);

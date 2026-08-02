import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';
import '../providers.dart';
import '../repositories/book_repository.dart';
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

  Future<String?> _downloadCover(int bookId, String url) async {
    try {
      final resp = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 20),
          );
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      if (resp.bodyBytes.isEmpty) return null;

      final appDir = await getApplicationDocumentsDirectory();
      final coverDir = Directory(p.join(appDir.path, 'covers'));
      if (!await coverDir.exists()) {
        await coverDir.create(recursive: true);
      }
      final ext = _guessExt(url, resp.headers['content-type']);
      final file = File(
        p.join(
          coverDir.path,
          '${bookId}_${DateTime.now().millisecondsSinceEpoch}$ext',
        ),
      );
      await file.writeAsBytes(resp.bodyBytes, flush: true);
      return file.path;
    } catch (e, st) {
      debugPrint('cover download failed: $e\n$st');
      return null;
    }
  }

  String _guessExt(String url, String? contentType) {
    final lower = url.toLowerCase();
    if (lower.contains('.png')) return '.png';
    if (lower.contains('.webp')) return '.webp';
    if (contentType != null) {
      if (contentType.contains('png')) return '.png';
      if (contentType.contains('webp')) return '.webp';
    }
    return '.jpg';
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

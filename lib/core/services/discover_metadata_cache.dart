import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../src/rust/api/metadata.dart' as rust;
import 'http/m_client.dart';
import 'source_service.dart';

/// Same SharedPreferences key as [MetadataEnrichmentService] / Settings.
const _googleBooksApiKeyPref = 'google_books_api_key';

/// Cached Open Library / Google Books hit for a Discover search row.
///
/// Keyed by [discoverMetadataCacheKey] (title + author), not Isar id —
/// Discover results are not library books yet. [coverUrl] drives the card
/// thumbnail; the JPEG is only downloaded when the book is added to library.
@immutable
class DiscoverMetadataHit {
  const DiscoverMetadataHit({
    this.coverUrl,
    this.author,
    this.genres = const [],
    this.releaseDate,
    this.source = '',
    this.remoteId,
    this.found = false,
    this.loading = false,
    this.error,
  });

  final String? coverUrl;
  final String? author;
  final List<String> genres;
  final String? releaseDate;
  final String source;
  final String? remoteId;
  final bool found;
  final bool loading;
  final String? error;

  static const loadingPlaceholder = DiscoverMetadataHit(loading: true);
}

/// Stable cache key: lowercase trimmed title + author.
String discoverMetadataCacheKey(String title, String? author) {
  final t = title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final a = (author ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  return '$t|$a';
}

/// Prefer medium Open Library covers — `-L` can hang on slow mobile networks.
String preferMediumCoverUrl(String url) {
  if (url.contains('covers.openlibrary.org') && url.contains('-L.')) {
    return url.replaceFirst('-L.', '-M.');
  }
  return url;
}

/// Headers for loading enriched cover URLs in Discover cards.
Map<String, String> discoverCoverHeaders(String url) {
  final headers = <String, String>{'User-Agent': kBrowserUserAgent};
  final host = Uri.tryParse(url)?.host ?? '';
  if (host.contains('openlibrary.org')) {
    headers['Referer'] = 'https://openlibrary.org/';
  } else if (host.contains('googleapis.com') ||
      host.contains('googleusercontent.com') ||
      host.contains('books.google')) {
    headers['Referer'] = 'https://books.google.com/';
  }
  return headers;
}

int _syntheticId(String key) => key.hashCode & 0x7fffffff;

/// Session cache + one-at-a-time queue for Discover ebook cover enrichment.
class DiscoverMetadataNotifier
    extends Notifier<Map<String, DiscoverMetadataHit>> {
  final Queue<({String key, String title, String? author})> _queue = Queue();
  final Set<String> _queued = {};
  bool _draining = false;
  int _generation = 0;

  @override
  Map<String, DiscoverMetadataHit> build() => const {};

  DiscoverMetadataHit? hitFor(String title, String? author) =>
      state[discoverMetadataCacheKey(title, author)];

  /// Drop pending work when the user clears / re-searches.
  void clearQueue() {
    _generation++;
    _queue.clear();
    _queued.clear();
    _draining = false;
  }

  /// Enqueue rows that do not yet have a cache entry. Processes one lookup at
  /// a time so Open Library / Google Books are not flooded.
  void enqueue(List<SourceSearchResult> results) {
    for (final r in results) {
      final key = discoverMetadataCacheKey(r.title, r.author);
      if (state.containsKey(key) || !_queued.add(key)) continue;
      state = {...state, key: DiscoverMetadataHit.loadingPlaceholder};
      _queue.add((key: key, title: r.title, author: r.author));
    }
    _drain();
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    final gen = _generation;
    while (_queue.isNotEmpty && gen == _generation) {
      final next = _queue.removeFirst();
      _queued.remove(next.key);
      await _lookupOne(next.key, next.title, next.author, gen);
      // Pace OL / Google — sequential alone still trips quotas on large grids.
      if (_queue.isNotEmpty && gen == _generation) {
        await Future<void>.delayed(const Duration(milliseconds: 450));
      }
    }
    if (gen == _generation) _draining = false;
  }

  Future<void> _lookupOne(
    String key,
    String title,
    String? author,
    int gen,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final googleKey = prefs.getString(_googleBooksApiKeyPref)?.trim();
      final results = await rust.lookupBooks(
        queries: [
          rust.BookLookupQuery(
            id: _syntheticId(key),
            title: title,
            author: author,
          ),
        ],
        googleApiKey: (googleKey == null || googleKey.isEmpty)
            ? null
            : googleKey,
      );
      if (gen != _generation) return;
      final r = results.isEmpty ? null : results.first;
      if (r == null || !r.found) {
        state = {
          ...state,
          key: DiscoverMetadataHit(
            found: false,
            error: r?.error ?? 'not found',
          ),
        };
        return;
      }
      final cover = r.coverUrl == null || r.coverUrl!.isEmpty
          ? null
          : preferMediumCoverUrl(r.coverUrl!);
      state = {
        ...state,
        key: DiscoverMetadataHit(
          coverUrl: cover,
          author: r.author,
          genres: r.genres,
          releaseDate: r.releaseDate,
          source: r.source,
          remoteId: r.remoteId,
          found: true,
        ),
      };
    } catch (e, st) {
      debugPrint('discover metadata lookup failed: $e\n$st');
      if (gen != _generation) return;
      state = {
        ...state,
        key: DiscoverMetadataHit(found: false, error: '$e'),
      };
    }
  }
}

final discoverMetadataProvider =
    NotifierProvider<DiscoverMetadataNotifier, Map<String, DiscoverMetadataHit>>(
      DiscoverMetadataNotifier.new,
    );

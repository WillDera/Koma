import 'dart:async';
import 'package:isar_community/isar.dart';

import '../models/book.dart';
import '../models/chapter.dart';
import '../models/snippet.dart';
import '../repositories/repositories.dart';

class SearchResult {
  final String type;
  final dynamic item;
  final String matchPreview;

  SearchResult({
    required this.type,
    required this.item,
    required this.matchPreview,
  });
}

class SearchService {
  final Repositories _repos;

  SearchService(this._repos);

  Future<List<SearchResult>> searchAll(String query) async {
    if (query.trim().isEmpty) return [];
    final results = <SearchResult>[];
    final term = query.trim().toLowerCase();

    results.addAll(await searchBooks(query));
    results.addAll(await searchChapters(query));
    results.addAll(await searchSnippets(query));

    return results;
  }

  Future<List<SearchResult>> searchBooks(String query) async {
    if (query.trim().isEmpty) return [];
    final term = query.trim().toLowerCase();
    final rows = await _repos.books.searchBooks(term);
    return rows.map((b) => SearchResult(
      type: 'book',
      item: b,
      matchPreview: b.title,
    )).toList();
  }

  Future<List<SearchResult>> searchChapters(String query) async {
    if (query.trim().isEmpty) return [];
    final term = query.trim().toLowerCase();
    final rows = await _repos.books.searchChapters(term);
    return rows.map((ch) {
      final content = ch.content;
      final preview =
          content.length > 150 ? '${content.substring(0, 150)}...' : content;
      return SearchResult(
        type: 'chapter',
        item: ch,
        matchPreview: preview.replaceAll(RegExp(r'<[^>]*>'), ' '),
      );
    }).toList();
  }

  Future<List<SearchResult>> searchSnippets(String query) async {
    if (query.trim().isEmpty) return [];
    final term = query.trim().toLowerCase();
    final rows = await _repos.snippets.searchSnippets(term);
    return rows.map((s) {
      final text = s.text;
      final preview =
          text.length > 150 ? '${text.substring(0, 150)}...' : text;
      return SearchResult(
        type: 'snippet',
        item: s,
        matchPreview: preview.replaceAll(RegExp(r'<[^>]*>'), ' '),
      );
    }).toList();
  }
}

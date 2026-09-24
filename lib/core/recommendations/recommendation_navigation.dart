import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:recommendation_engine/recommendation_engine.dart';

import '../providers.dart';
import 'koma_catalog_source.dart';
import '../../router/book_navigation.dart';
import '../../router/router.dart';

/// Open a recommendation — library row or Discover / extension hit.
Future<void> openRecommendationItem(
  BuildContext context,
  WidgetRef ref,
  RecommendationItem item,
) async {
  final id = item.id;

  if (id != null && id.startsWith('book:')) {
    final bookId = int.tryParse(id.substring(5));
    if (bookId != null) {
      openBookFromCollection(context, bookId);
      return;
    }
  }

  if (id != null && id.startsWith('manga:')) {
    final mangaId = int.tryParse(id.substring(6));
    if (mangaId != null) {
      final manga =
          await ref.read(repositoriesProvider).manga.getMangaById(mangaId);
      if (manga == null || !context.mounted) return;
      context.pushNamed(
        Routes.mangaDetail,
        extra: (
          sourceId: manga.sourceId,
          url: manga.url,
          title: manga.name,
          manga: manga,
          memo: manga.memo,
        ) as MangaDetailArgs,
      );
      return;
    }
  }

  final sourceId = item.sourceId;
  final sourceUrl = item.sourceUrl;
  if (sourceId != null &&
      sourceId.isNotEmpty &&
      sourceUrl != null &&
      sourceUrl.isNotEmpty) {
    if (!context.mounted) return;
    context.pushNamed(
      Routes.mangaDetail,
      extra: (
        sourceId: sourceId,
        url: sourceUrl,
        title: item.title,
        manga: null,
        memo: null,
      ) as MangaDetailArgs,
    );
    return;
  }

  if (id != null) {
    final parsed = parseExtensionCatalogId(id);
    if (parsed != null && context.mounted) {
      context.pushNamed(
        Routes.mangaDetail,
        extra: (
          sourceId: parsed.sourceId,
          url: parsed.url,
          title: item.title,
          manga: null,
          memo: null,
        ) as MangaDetailArgs,
      );
    }
  }
}

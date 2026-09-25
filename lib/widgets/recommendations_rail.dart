import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recommendation_engine/recommendation_engine.dart';

import '../core/recommendations/koma_catalog_source.dart';
import '../core/recommendations/recommendation_navigation.dart';
import 'catalog_cover_card.dart';
import 'library_book_card.dart' show LibraryCardVariant;
import 'media_rail.dart';
import 'screen_chrome.dart';

/// Horizontal “Recommended” rail. Renders nothing when [items] is empty.
class RecommendationsRail extends ConsumerWidget {
  const RecommendationsRail({
    super.key,
    required this.items,
    this.title = 'Recommended for you',
    this.subtitle,
    this.height = 200,
    this.minimalChrome = false,
  });

  final List<RecommendationItem> items;
  final String title;
  final String? subtitle;
  final double height;
  final bool minimalChrome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();

    return MediaRail(
      title: title,
      subtitle: subtitle ?? '${items.length} picks',
      height: height,
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return MediaRailCover(
          width: 118,
          child: StaggeredFadeScale(
            index: i,
            child: CatalogCoverCard(
              minimalChrome: minimalChrome,
              title: item.title,
              subtitle: item.reason ?? item.author,
              imageProvider: _coverProvider(item.coverPathOrUrl),
              imageUrl: _remoteUrl(item.coverPathOrUrl),
              formatBadge: recommendationIdIsDiscover(item.id)
                  ? (item.sourceLabel ?? 'Discover')
                  : (item.kind == RecommendationContentKind.ebook
                      ? 'Book'
                      : null),
              variant: LibraryCardVariant.grid,
              onTap: () => openRecommendationItem(context, ref, item),
            ),
          ),
        );
      },
    );
  }

  static ImageProvider? _coverProvider(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) return null;
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return null;
    }
    final file = File(pathOrUrl);
    if (!file.existsSync()) return null;
    return FileImage(file);
  }

  static String? _remoteUrl(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) return null;
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl;
    }
    return null;
  }
}

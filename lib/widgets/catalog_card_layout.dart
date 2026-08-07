import 'package:flutter/material.dart';

import '../theme/tokens/app_spacing.dart';
import 'library_book_card.dart';

/// Shared geometry for cover grids — keeps Library / Discover / Global Search
/// / Source Browse aligned with Appearance → grid columns + card variant.
abstract final class CatalogCardLayout {
  /// List style is a shelf mode; inside a grid cell fall back to comfortable.
  static LibraryCardVariant gridVariant(LibraryCardVariant variant) =>
      variant == LibraryCardVariant.list ? LibraryCardVariant.grid : variant;

  static EdgeInsetsGeometry paddingFor(LibraryCardVariant variant) {
    final v = gridVariant(variant);
    final tight =
        v == LibraryCardVariant.compact || v == LibraryCardVariant.overlay;
    return EdgeInsets.symmetric(horizontal: tight ? 12 : 20);
  }

  static double mainAxisSpacing(LibraryCardVariant variant) {
    final v = gridVariant(variant);
    if (v == LibraryCardVariant.overlay) return 8;
    if (v == LibraryCardVariant.compact) return 10;
    return 14;
  }

  static double crossAxisSpacing(LibraryCardVariant variant) {
    final v = gridVariant(variant);
    if (v == LibraryCardVariant.overlay) return 8;
    if (v == LibraryCardVariant.compact) return 10;
    return 14;
  }

  static double childAspectRatio(LibraryCardVariant variant) {
    final v = gridVariant(variant);
    if (v == LibraryCardVariant.overlay) return AppSpacing.coverAspectRatio;
    if (v == LibraryCardVariant.compact) return 0.62;
    return 0.58;
  }

  static SliverGridDelegateWithFixedCrossAxisCount gridDelegate({
    required int columns,
    required LibraryCardVariant variant,
  }) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns.clamp(1, 6),
      mainAxisSpacing: mainAxisSpacing(variant),
      crossAxisSpacing: crossAxisSpacing(variant),
      childAspectRatio: childAspectRatio(variant),
    );
  }
}

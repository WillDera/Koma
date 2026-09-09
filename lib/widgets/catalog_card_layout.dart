import 'package:flutter/material.dart';

import '../theme/tokens/app_spacing.dart';
import 'library_book_card.dart';

/// Shared geometry for cover grids — keeps Library / Discover / Global Search
/// / Source Browse aligned with Library layout sheet columns + card variant.
abstract final class CatalogCardLayout {
  /// List style is a shelf mode; inside a grid cell fall back to comfortable.
  static LibraryCardVariant gridVariant(LibraryCardVariant variant) =>
      variant == LibraryCardVariant.list ? LibraryCardVariant.grid : variant;

  static EdgeInsetsGeometry paddingFor(LibraryCardVariant variant) {
    final v = gridVariant(variant);
    final tight = v == LibraryCardVariant.compact ||
        v == LibraryCardVariant.overlay ||
        v == LibraryCardVariant.coverOnly;
    return EdgeInsets.symmetric(horizontal: tight ? 12 : 24);
  }

  static double mainAxisSpacing(LibraryCardVariant variant) {
    final v = gridVariant(variant);
    if (v == LibraryCardVariant.overlay ||
        v == LibraryCardVariant.coverOnly) {
      return 8;
    }
    if (v == LibraryCardVariant.compact) return 10;
    return 16;
  }

  static double crossAxisSpacing(LibraryCardVariant variant) {
    final v = gridVariant(variant);
    if (v == LibraryCardVariant.overlay ||
        v == LibraryCardVariant.coverOnly) {
      return 8;
    }
    if (v == LibraryCardVariant.compact) return 10;
    return 14;
  }

  static double childAspectRatio(LibraryCardVariant variant) {
    final v = gridVariant(variant);
    if (v == LibraryCardVariant.overlay ||
        v == LibraryCardVariant.coverOnly) {
      return AppSpacing.coverAspectRatio;
    }
    if (v == LibraryCardVariant.compact) return 0.70;
    // Kenji cover ~123×178 + title line ≈ 0.60.
    return 0.60;
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

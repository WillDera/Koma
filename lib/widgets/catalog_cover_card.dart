import 'package:flutter/material.dart';

import '../core/utils/custom_extended_image_provider.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';
import 'library_book_card.dart';

/// Generic cover card used outside the Book model — Discover / Global Search /
/// Source Browse. Mirrors [LibraryBookCard] Grid / Compact / Overlay / List.
class CatalogCoverCard extends StatelessWidget {
  const CatalogCoverCard({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.imageUrl,
    this.imageProvider,
    this.headers,
    this.badge,
    this.showBadge = true,
    this.variant = LibraryCardVariant.grid,
    this.downloadProgress,
  });

  final String title;
  final String? subtitle;
  final String? imageUrl;
  final ImageProvider? imageProvider;
  final Map<String, String>? headers;
  final String? badge;
  final bool showBadge;
  final LibraryCardVariant variant;
  final VoidCallback onTap;
  final double? downloadProgress;

  bool get _busy => downloadProgress != null;

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case LibraryCardVariant.list:
        return _list(context);
      case LibraryCardVariant.compact:
        return _compact(context);
      case LibraryCardVariant.overlay:
        return _overlay(context);
      case LibraryCardVariant.grid:
        return _grid(context);
    }
  }

  Widget _coverImage(KomaColors c) {
    if (imageProvider != null) {
      return Image(
        image: imageProvider!,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(c),
      );
    }
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image(
        image: CustomExtendedNetworkImageProvider(
          imageUrl!,
          headers: headers,
          showCloudFlareError: true,
        ),
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(c),
      );
    }
    return _placeholder(c);
  }

  Widget _placeholder(KomaColors c) {
    return Container(
      color: c.surfaceMuted,
      child: Center(
        child: Icon(Icons.image_outlined, size: 28, color: c.textTertiary),
      ),
    );
  }

  Widget? _badgeChip({double fontSize = 10}) {
    if (!showBadge || badge == null || badge!.isEmpty) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: AppSpacing.brPill,
      ),
      child: Text(
        badge!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _grid(BuildContext context) {
    final c = context.colors;
    final chip = _badgeChip();
    return AnimatedPress(
      onTap: _busy ? null : onTap,
      scaleDown: 0.97,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: AppSpacing.brMd,
                  child: _coverImage(c),
                ),
                if (chip != null) Positioned(top: 6, left: 6, child: chip),
                if (_busy)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: downloadProgress,
                      minHeight: 3,
                      backgroundColor: c.surfaceMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.2,
              letterSpacing: -0.1,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.textSecondary, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _compact(BuildContext context) {
    final c = context.colors;
    final chip = _badgeChip(fontSize: 9);
    return AnimatedPress(
      onTap: _busy ? null : onTap,
      scaleDown: 0.97,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: AppSpacing.brSm,
                  child: _coverImage(c),
                ),
                if (chip != null) Positioned(top: 4, left: 4, child: chip),
                if (_busy)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: downloadProgress,
                      minHeight: 2,
                      backgroundColor: c.surfaceMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    final c = context.colors;
    final chip = _badgeChip();
    return AnimatedPress(
      onTap: _busy ? null : onTap,
      scaleDown: 0.97,
      child: ClipRRect(
        borderRadius: AppSpacing.brMd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _coverImage(c),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xBF000000),
                    Color(0x59000000),
                    Color(0x00000000),
                  ],
                  stops: [0.0, 0.35, 1.0],
                ),
              ),
            ),
            if (chip != null) Positioned(top: 6, left: 6, child: chip),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  shadows: [
                    Shadow(
                      blurRadius: 4,
                      color: Colors.black54,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
            if (_busy)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: downloadProgress,
                  minHeight: 3,
                  backgroundColor: Colors.white24,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final c = context.colors;
    final chip = _badgeChip(fontSize: 9);
    return AnimatedPress(
      onTap: _busy ? null : onTap,
      scaleDown: 0.99,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: AppSpacing.brLg,
        ),
        child: Row(
          children: [
            Stack(
              children: [
                SizedBox(
                  width: 48,
                  height: 64,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: _coverImage(c),
                  ),
                ),
                if (chip != null) Positioned(top: 2, left: 2, child: chip),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textSecondary, fontSize: 13),
                    ),
                  ],
                  if (_busy) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: downloadProgress,
                      minHeight: 3,
                      backgroundColor: c.border,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}

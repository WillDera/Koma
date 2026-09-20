import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';
import 'library_book_card.dart';

/// Cover descriptors for the group collage (resolved by the caller).
class GroupCoverSlot {
  const GroupCoverSlot({
    required this.title,
    required this.memberKey,
    this.image,
    this.readingOrder,
    this.badge,
  });

  final String title;
  final String memberKey;
  final ImageProvider? image;
  final int? readingOrder;

  /// Optional source / type pill on the collage (respects badge settings).
  final String? badge;
}

/// Composite cover art for a library group — first 1–3 member covers.
///
/// - 1 title → full cover
/// - 2 titles → vertical panels side by side
/// - 3 titles → H layout (large left, two stacked on the right)
///
/// Honors [variant] / [minimalChrome] like other catalog cards.
class LibraryGroupStackCard extends StatelessWidget {
  const LibraryGroupStackCard({
    super.key,
    required this.groupId,
    required this.name,
    required this.covers,
    required this.onTap,
    this.onLongPress,
    this.memberCount = 0,
    this.maxVisible = 3,
    this.enableHero = true,
    this.listLayout = false,
    this.variant = LibraryCardVariant.grid,
    this.minimalChrome = false,
    this.showSourcePills = true,
  });

  final int groupId;
  final String name;
  final List<GroupCoverSlot> covers;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final int memberCount;
  final int maxVisible;
  final bool enableHero;
  final bool listLayout;
  final LibraryCardVariant variant;
  final bool minimalChrome;
  final bool showSourcePills;

  static String coverHeroTag(int groupId, String memberKey) =>
      'library-group-$groupId-$memberKey';

  bool get _isList => listLayout || variant == LibraryCardVariant.list;
  bool get _showTitle => variant != LibraryCardVariant.coverOnly;
  bool get _overlayTitle =>
      variant == LibraryCardVariant.overlay ||
      variant == LibraryCardVariant.coverOnly;
  bool get _showBadges => !minimalChrome;
  bool get _showSource => _showBadges && showSourcePills;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final visible = covers.take(maxVisible).toList();
    final count = memberCount > 0 ? memberCount : covers.length;
    final frontBadge = _frontBadge(visible);

    if (_isList) {
      return AnimatedPress(
        onTap: onTap,
        onLongPress: onLongPress,
        scaleDown: 0.99,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                height: 110,
                child: _GroupCollage(
                  groupId: groupId,
                  covers: visible,
                  colors: c,
                  enableHero: enableHero,
                  showReadingOrder: _showBadges,
                  sourceBadge: _showSource ? frontBadge : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count titles',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final titleStyle = TextStyle(
      color: _overlayTitle ? Colors.white : c.textPrimary,
      fontSize: variant == LibraryCardVariant.compact ? 11 : 13,
      fontWeight: FontWeight.w600,
      height: variant == LibraryCardVariant.compact ? 1.15 : 1.2,
      letterSpacing: -0.1,
      decoration: TextDecoration.none,
      shadows: _overlayTitle
          ? const [
              Shadow(
                blurRadius: 4,
                color: Colors.black54,
                offset: Offset(0, 1),
              ),
            ]
          : null,
    );
    final subtitleStyle = TextStyle(
      color: _overlayTitle
          ? Colors.white.withValues(alpha: 0.85)
          : c.textSecondary,
      fontSize: variant == LibraryCardVariant.compact ? 10 : 11,
      decoration: TextDecoration.none,
    );

    final collage = _GroupCollage(
      groupId: groupId,
      covers: visible,
      colors: c,
      enableHero: enableHero,
      showReadingOrder: _showBadges,
      sourceBadge: _showSource ? frontBadge : null,
    );

    return AnimatedPress(
      onTap: onTap,
      onLongPress: onLongPress,
      scaleDown: 0.97,
      child: _overlayTitle
          ? Stack(
              fit: StackFit.expand,
              children: [
                collage,
                if (_showTitle)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AspectRatio(
                      aspectRatio: AppSpacing.coverAspectRatio,
                      child: ClipRRect(
                        borderRadius: AppSpacing.brMd,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
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
                            Positioned(
                              left: 8,
                              right: 8,
                              bottom: 8,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: titleStyle,
                                  ),
                                  const SizedBox(height: 2),
                                  Text('$count titles', style: subtitleStyle),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: collage),
                if (_showTitle) ...[
                  SizedBox(
                    height: variant == LibraryCardVariant.compact ? 4 : 6,
                  ),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count titles',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: subtitleStyle,
                  ),
                ],
              ],
            ),
    );
  }

  String? _frontBadge(List<GroupCoverSlot> visible) {
    if (visible.isEmpty) return null;
    final badge = visible.first.badge?.trim();
    if (badge == null || badge.isEmpty) return null;
    return badge;
  }
}

/// Composite cover from 1–3 [GroupCoverSlot]s.
class _GroupCollage extends StatelessWidget {
  const _GroupCollage({
    required this.groupId,
    required this.covers,
    required this.colors,
    required this.enableHero,
    required this.showReadingOrder,
    this.sourceBadge,
  });

  final int groupId;
  final List<GroupCoverSlot> covers;
  final KomaColors colors;
  final bool enableHero;
  final bool showReadingOrder;
  final String? sourceBadge;

  static const _gap = 1.5;

  @override
  Widget build(BuildContext context) {
    final body = ClipRRect(
      borderRadius: AppSpacing.brMd,
      child: ColoredBox(
        color: colors.surfaceMuted,
        child: covers.isEmpty
            ? Center(
                child: Icon(Icons.layers_outlined, color: colors.textTertiary),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  _layout(),
                  if (showReadingOrder &&
                      covers.first.readingOrder != null)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: ReadingOrderPill(order: covers.first.readingOrder!),
                    ),
                  if (sourceBadge != null && sourceBadge!.isNotEmpty)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _SourcePill(label: sourceBadge!),
                    ),
                ],
              ),
      ),
    );

    if (!enableHero || covers.isEmpty) return body;
    return Hero(
      tag: LibraryGroupStackCard.coverHeroTag(groupId, covers.first.memberKey),
      createRectTween: (begin, end) =>
          MaterialRectArcTween(begin: begin, end: end),
      child: Material(type: MaterialType.transparency, child: body),
    );
  }

  Widget _layout() {
    final n = covers.length;
    if (n == 1) {
      return _panel(covers[0]);
    }
    if (n == 2) {
      // Two vertical panels side by side.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _panel(covers[0])),
          const SizedBox(width: _gap),
          Expanded(child: _panel(covers[1])),
        ],
      );
    }
    // H layout: large left, two stacked on the right.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 5, child: _panel(covers[0])),
        const SizedBox(width: _gap),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _panel(covers[1])),
              const SizedBox(height: _gap),
              Expanded(child: _panel(covers[2])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _panel(GroupCoverSlot cover) {
    if (cover.image != null) {
      return Image(
        image: cover.image!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        errorBuilder: (_, _, _) => _placeholder(cover.title),
      );
    }
    return _placeholder(cover.title);
  }

  Widget _placeholder(String title) {
    final letters = title.trim().isEmpty
        ? '?'
        : title
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
            .join();
    return ColoredBox(
      color: colors.surfaceMuted,
      child: Center(
        child: Text(
          letters,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _SourcePill extends StatelessWidget {
  const _SourcePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: AppSpacing.brPill,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// High-contrast reading-order badge for covers.
class ReadingOrderPill extends StatelessWidget {
  const ReadingOrderPill({super.key, required this.order});

  final int order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: AppSpacing.brPill,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      child: Text(
        '$order',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.1,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';

/// Cover descriptors for the fan stack (resolved by the caller).
class GroupCoverSlot {
  const GroupCoverSlot({
    required this.title,
    required this.memberKey,
    this.image,
    this.readingOrder,
  });

  final String title;
  final String memberKey;
  final ImageProvider? image;
  final int? readingOrder;
}

/// Fanned stack of covers used as a single library card for a group.
class LibraryGroupStackCard extends StatelessWidget {
  const LibraryGroupStackCard({
    super.key,
    required this.groupId,
    required this.name,
    required this.covers,
    required this.onTap,
    this.onLongPress,
    this.memberCount = 0,
    this.maxVisible = 4,
    this.enableHero = true,
  });

  final int groupId;
  final String name;
  final List<GroupCoverSlot> covers;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final int memberCount;
  final int maxVisible;
  final bool enableHero;

  static String coverHeroTag(int groupId, String memberKey) =>
      'library-group-$groupId-$memberKey';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final visible = covers.take(maxVisible).toList();
    final count = memberCount > 0 ? memberCount : covers.length;

    final card = AnimatedPress(
      onTap: onTap,
      onLongPress: onLongPress,
      scaleDown: 0.97,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _FanStack(
                  groupId: groupId,
                  covers: visible,
                  colors: c,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  enableHero: enableHero,
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
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
          const SizedBox(height: 2),
          Text(
            '$count titles',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );

    return card;
  }
}

class _FanStack extends StatelessWidget {
  const _FanStack({
    required this.groupId,
    required this.covers,
    required this.colors,
    required this.width,
    required this.height,
    required this.enableHero,
  });

  final int groupId;
  final List<GroupCoverSlot> covers;
  final KomaColors colors;
  final double width;
  final double height;
  final bool enableHero;

  @override
  Widget build(BuildContext context) {
    if (covers.isEmpty) {
      return ClipRRect(
        borderRadius: AppSpacing.brMd,
        child: ColoredBox(
          color: colors.surfaceMuted,
          child: Center(
            child: Icon(Icons.layers_outlined, color: colors.textTertiary),
          ),
        ),
      );
    }

    final n = covers.length;
    // Reserve horizontal room so peeks stay inside the grid cell.
    final spread = math.min(width * 0.14, 18.0);
    final coverW = math.max(width - spread * (n - 1), width * 0.62);
    final coverH = math.min(
      height * 0.96,
      coverW / AppSpacing.coverAspectRatio,
    );

    // Draw back → front so index 0 (reading order) sits on top.
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomLeft,
      children: [
        for (var i = n - 1; i >= 0; i--)
          _FanCover(
            groupId: groupId,
            cover: covers[i],
            index: i,
            total: n,
            coverW: coverW,
            coverH: coverH,
            spread: spread,
            colors: colors,
            enableHero: enableHero,
          ),
      ],
    );
  }
}

class _FanCover extends StatelessWidget {
  const _FanCover({
    required this.groupId,
    required this.cover,
    required this.index,
    required this.total,
    required this.coverW,
    required this.coverH,
    required this.spread,
    required this.colors,
    required this.enableHero,
  });

  final int groupId;
  final GroupCoverSlot cover;
  final int index;
  final int total;
  final double coverW;
  final double coverH;
  final double spread;
  final KomaColors colors;
  final bool enableHero;

  @override
  Widget build(BuildContext context) {
    final t = total <= 1 ? 0.0 : index / (total - 1);
    final dx = spread * index;
    final dy = 5.0 * index;
    final angle = (0.02 + 0.07 * t) * (index == 0 ? 0.15 : 1.0);
    final scale = 1.0 - 0.04 * index;

    final face = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppSpacing.brMd,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28 - 0.04 * index),
            blurRadius: 10 + index * 2.5,
            offset: Offset(1.5 * index, 3.0 + index * 1.5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppSpacing.brMd,
        child: SizedBox(
          width: coverW,
          height: coverH,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _coverFace(cover),
              if (index == 0 && cover.readingOrder != null)
                Positioned(
                  top: 6,
                  left: 6,
                  child: ReadingOrderPill(order: cover.readingOrder!),
                ),
            ],
          ),
        ),
      ),
    );

    final heroChild = enableHero
        ? Hero(
            tag: LibraryGroupStackCard.coverHeroTag(groupId, cover.memberKey),
            createRectTween: (begin, end) =>
                MaterialRectArcTween(begin: begin, end: end),
            child: Material(type: MaterialType.transparency, child: face),
          )
        : face;

    return Positioned(
      left: dx,
      bottom: dy,
      width: coverW,
      height: coverH,
      child: Transform.rotate(
        angle: angle,
        alignment: Alignment.bottomLeft,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.bottomLeft,
          child: heroChild,
        ),
      ),
    );
  }

  Widget _coverFace(GroupCoverSlot cover) {
    if (cover.image != null) {
      return Image(
        image: cover.image!,
        fit: BoxFit.cover,
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
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
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
        ),
      ),
    );
  }
}

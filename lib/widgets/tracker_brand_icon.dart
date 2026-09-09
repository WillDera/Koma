import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/repositories/track_repository.dart';

/// Brand mark for a tracker service (MAL / AniList / MangaUpdates).
class TrackerBrandIcon extends StatelessWidget {
  final int syncId;
  final double size;
  final BorderRadius? borderRadius;

  const TrackerBrandIcon({
    super.key,
    required this.syncId,
    this.size = 36,
    this.borderRadius,
  });

  static String? assetFor(int syncId) => switch (syncId) {
        TrackIds.mal => 'assets/trackers/myanimelist.svg',
        TrackIds.anilist => 'assets/trackers/anilist.svg',
        TrackIds.mangaUpdates => 'assets/trackers/mangaupdates.svg',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final asset = assetFor(syncId);
    final radius = borderRadius ?? BorderRadius.circular(size * 0.22);
    if (asset == null) {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.track_changes_rounded, size: size * 0.55),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: SvgPicture.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

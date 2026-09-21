import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

import '../utils/custom_extended_image_provider.dart';

/// App-wide decoded-image / frame hygiene for long sessions.
///
/// The bottom-nav [StatefulShellRoute.indexedStack] keeps every tab's widgets
/// alive, so cover bitmaps stay "live" in [ImageCache] and resist normal LRU
/// eviction. After browsing / reading for a while that pressure shows up as
/// hitchy route transitions and list scrolls everywhere — not as a low Hz cap.
abstract final class SessionMemory {
  /// Drop live image handles so LRU can reclaim. Safe while backgrounds are
  /// paused; next paint reloads from disk/network cache as needed.
  static void releaseLiveImages() {
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  /// Hard clear under OS memory pressure (Flutter + encoded-byte LRUs).
  static void purgeImageCache() {
    final cache = PaintingBinding.instance.imageCache;
    cache.clearLiveImages();
    cache.clear();
    clearEncodedImageMemoryCache();
  }

  /// Schedule a trim after the current frame so we don't fight an in-flight
  /// transition's raster work.
  static void trimAfterFrame({bool aggressive = false}) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (aggressive) {
        purgeImageCache();
      } else {
        releaseLiveImages();
        // Encoded bytes don't pin UI layers; reclaim them when backgrounded.
        clearEncodedImageMemoryCache();
      }
    });
  }
}

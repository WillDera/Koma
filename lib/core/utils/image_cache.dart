import 'package:flutter/material.dart';

import 'cached_network.dart';
import 'custom_extended_image_provider.dart';

/// Returns an [ImageProvider] for a cover URL decoded at thumbnail size.
///
/// Thin wrapper over mangayomi-style [coverProvider]:
///   - Disk + memory cache (see [CustomExtendedNetworkImageProvider]).
///   - [ExtendedResizeImage] cap so the decoded bitmap is thumbnail-sized,
///     keeping [imageCache] small during grid scrolling.
///
/// Existing [width] / [height] parameters are honored: when provided, the
/// resize is delegated to [ResizeImage] (Flutter built-in) for parity with
/// the previous implementation; otherwise (the common case) the mangayomi
/// 200 KB [ExtendedResizeImage] cap is used. Either path lands in the disk
/// cache via the custom provider.
///
/// Usage: `Image(image: cachedCover(url), fit: BoxFit.cover)`
ImageProvider cachedCover(
  String url, {
  Map<String, String>? headers,
  int? width,
  int? height,
}) {
  if (width != null || height != null) {
    return ResizeImage(
      CustomExtendedNetworkImageProvider(
        url,
        headers: headers,
        showCloudFlareError: true,
      ),
      width: width,
      height: height,
    );
  }
  return coverProvider(url, headers: headers);
}

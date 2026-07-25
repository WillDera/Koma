import 'package:flutter/material.dart';

/// Returns an [ImageProvider] for a cover URL decoded at thumbnail size.
///
/// Uses [cacheWidth] / [cacheHeight] to downsample at decode time,
/// keeping memory usage low during grid scrolling — same principle
/// as mangayomi's coverProvider with ExtendedResizeImage.
///
/// Usage: `Image(image: cachedCover(url), fit: BoxFit.cover)`
ImageProvider cachedCover(String url, {Map<String, String>? headers, int? width, int? height}) {
  if (width != null || height != null) {
    return ResizeImage(
      NetworkImage(url, headers: headers),
      width: width,
      height: height,
    );
  }
  return NetworkImage(url, headers: headers);
}

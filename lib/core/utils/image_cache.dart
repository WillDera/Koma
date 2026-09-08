import 'dart:io';

import 'package:flutter/material.dart';

import 'cached_network.dart';
import 'custom_extended_image_provider.dart';

/// Returns an [ImageProvider] for a cover URL decoded at thumbnail size.
///
/// - Local / `file://` paths → [FileImage] (CBZ covers).
/// - Network URLs → [CustomExtendedNetworkImageProvider] (+ optional resize).
///
/// Usage: `Image(image: cachedCover(url), fit: BoxFit.cover)`
ImageProvider cachedCover(
  String url, {
  Map<String, String>? headers,
  int? width,
  int? height,
}) {
  // Local CBZ / file covers: never send these through the network provider.
  if (isLocalCoverPath(url)) {
    final fileImage = FileImage(File(localCoverFsPath(url)));
    if (width != null || height != null) {
      return ResizeImage(fileImage, width: width, height: height);
    }
    return fileImage;
  }

  // Network: keep the previous sized-thumbnail path (ResizeImage + custom
  // network provider). Wrapping [ExtendedResizeImage] in [ResizeImage] broke
  // remote manga covers in history / lists.
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

import 'dart:io';

import 'package:flutter/material.dart';

import '../models/manga.dart';
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
    return ResizeImage(fileImage, width: 600);
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

/// Prefer custom cover → cached thumbnail → [Manga.imageUrl] (local or remote).
ImageProvider? mangaCoverProvider(
  Manga manga, {
  String? localThumbPath,
  Map<String, String>? headers,
}) {
  final custom = manga.customCoverPath?.trim();
  if (custom != null && custom.isNotEmpty && File(custom).existsSync()) {
    return FileImage(File(custom));
  }
  final thumb = localThumbPath?.trim();
  if (thumb != null && thumb.isNotEmpty && File(thumb).existsSync()) {
    return FileImage(File(thumb));
  }
  final url = manga.imageUrl?.trim();
  if (url == null || url.isEmpty) return null;
  return cachedCover(url, headers: headers);
}

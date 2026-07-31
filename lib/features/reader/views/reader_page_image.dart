import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/utils/custom_extended_image_provider.dart';
import '../models/page_data.dart';

/// Shared image renderer for a single manga page. Used by both the paged
/// and webtoon views so image loading, local-file vs network handling,
/// and the loading/error placeholders stay identical across modes.
///
/// [webtoon] mode uses `BoxFit.contain` at full width with a 16:9
/// placeholder box (matching mangayomi's ImageViewWebtoon); paged mode
/// fills the viewport and honors [cropBorders].
class ReaderPageImage extends StatelessWidget {
  final PageData page;
  final bool webtoon;
  final bool cropBorders;
  final VoidCallback? onRetry;

  const ReaderPageImage({
    super.key,
    required this.page,
    this.webtoon = false,
    this.cropBorders = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final imgUrl = page.imageUrl;

    if (webtoon) {
      if (imgUrl.isEmpty) return _brokenBox();
      return Image(
        image: page.localPath != null
            ? FileImage(File(page.localPath!))
            : CustomExtendedNetworkImageProvider(
                imgUrl,
                headers: page.headers,
                cacheMaxAge: const Duration(days: 7),
                imageCacheFolderName: 'cacheimagemanga',
          showCloudFlareError: true,
              ),
        key: ValueKey('p${page.chapter?.id ?? 0}-${page.index}'),
        fit: BoxFit.contain,
        width: double.infinity,
        loadingBuilder: (_, child, progress) => progress != null
            ? const AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white54),
                ),
              )
            : child,
        errorBuilder: (_, _, _) => _brokenBox(),
      );
    }

    // Paged mode
    final fit = cropBorders ? BoxFit.cover : BoxFit.contain;
    if (page.localPath != null) {
      return Image.file(
        File(page.localPath!),
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => _retryColumn(),
      );
    }
    return Image(
      image: CustomExtendedNetworkImageProvider(
        page.imageUrl,
        headers: page.headers,
        cacheMaxAge: const Duration(days: 7),
        imageCacheFolderName: 'cacheimagemanga',
        showCloudFlareError: true,
      ),
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (_, child, progress) => progress != null
          ? const Center(child: CircularProgressIndicator(color: Colors.white54))
          : child,
      errorBuilder: (_, _, _) => _retryColumn(),
    );
  }

  Widget _brokenBox() => const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(
          child: Icon(Icons.broken_image, color: Colors.white38, size: 48),
        ),
      );

  Widget _retryColumn() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image, color: Colors.white38, size: 48),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, color: Colors.white54),
              label: const Text('Retry',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      );
}

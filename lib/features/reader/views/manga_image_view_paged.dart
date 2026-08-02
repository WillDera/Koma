import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/utils/custom_extended_image_provider.dart';
import '../reader_settings_sheet.dart';
import '../subsampling_scale_image_view/subsampling_scale_image_view.dart';
import '../widgets/transition_view_paged.dart';
import 'reader_view_props.dart';

/// Paged reader (default L2R, right-to-left, and landscape book/spread mode).
///
/// Mirrors mangayomi's `image_view_paged.dart`: a [PageView.builder] where
/// each page is a pinch-zoomable [InteractiveViewer] wrapping
/// [ReaderPageImage], with chapter separators rendered as
/// [TransitionViewPaged]. Book mode packs two pages per spread.
class MangaImageViewPaged extends StatelessWidget {
  final ReaderViewProps props;
  final PageController pageController;
  final Axis axis;
  final bool reverse;
  final bool bookMode;

  const MangaImageViewPaged({
    super.key,
    required this.props,
    required this.pageController,
    required this.axis,
    required this.reverse,
    this.bookMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final pages = props.pages;
    if (bookMode) {
      return PageView.builder(
        controller: pageController,
        scrollDirection: axis,
        reverse: reverse,
        itemCount: (pages.length / 2).ceil(),
        onPageChanged: (i) => props.onPageChanged(i * 2),
        itemBuilder: (_, spreadIndex) {
          final leftIdx = spreadIndex * 2;
          final rightIdx = leftIdx + 1;
          return Row(
            children: [
              Expanded(
                child: leftIdx < pages.length
                    ? _buildPage(context, leftIdx)
                    : const SizedBox(),
              ),
              Container(width: 1, color: Colors.white12),
              Expanded(
                child: rightIdx < pages.length
                    ? _buildPage(context, rightIdx)
                    : const SizedBox(),
              ),
            ],
          );
        },
      );
    }

    return PageView.builder(
      controller: pageController,
      scrollDirection: axis,
      reverse: reverse,
      itemCount: pages.length,
      onPageChanged: props.onPageChanged,
      itemBuilder: (_, i) => _buildPage(context, i),
    );
  }

  Widget _buildPage(BuildContext context, int index) {
    final pages = props.pages;
    final settings = props.settings;
    if (index >= pages.length) return const SizedBox();
    final page = pages[index];

    if (page.isTransitionPage) {
      return TransitionViewPaged(data: page, readerMode: settings.readingMode);
    }

    // ── Build the image provider / path for the subsampling viewer ──────
    // If the page is a downloaded local file, pass the path directly to
    // bypass the ImageProvider resolution pipeline. Otherwise pass the
    // CustomExtendedNetworkImageProvider — the viewer's internal
    // _loadFromProvider() will find the MD5-keyed cached file in the
    // cacheimagemanga/ folder (Phase 6 disk cache) and feed it to the FFI
    // decoder for region-decoded tiling. This is the exact flow mangayomi
    // uses in its image_view_paged.dart.
    final ImageProvider imageProvider;
    final String? resolvedFilePath;
    if (page.localPath != null) {
      imageProvider = FileImage(File(page.localPath!));
      resolvedFilePath = page.localPath;
    } else if (page.imageUrl.isNotEmpty) {
      imageProvider = CustomExtendedNetworkImageProvider(
        page.imageUrl,
        headers: page.headers,
        cacheMaxAge: const Duration(days: 7),
        imageCacheFolderName: 'cacheimagemanga',
        showCloudFlareError: true,
      );
      resolvedFilePath = null;
    } else {
      // No image URL and no local path — broken page
      return _BrokenPage(onRetry: () => props.onRetryPage(index));
    }

    final padding = settings.sidePadding;
    final hPad = (MediaQuery.of(context).size.width * padding) / 2;
    final vPad = (MediaQuery.of(context).size.height * padding) / 2;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      child: SubsamplingScaleImageView(
        image: imageProvider,
        resolvedFilePath: resolvedFilePath,
        preloadData: page,
        cropBorders: settings.cropBorders,
        fit: BoxFit.contain,
        panEnabled: !settings.disableDoubleTap || !settings.disableZoomOut,
        zoomEnabled: !settings.disableZoomOut,
        doubleTapZoomScale: settings.disableDoubleTap ? 1.0 : null,
        pageController: pageController,
        onError: (msg) {
          // Surface the error so the parent can offer retry
          if (settings.disableDoubleTap) props.onRetryPage(index);
        },
      ),
    );
  }
}

/// The tap-zone overlay for paged mode: divides the viewport into
/// previous-page / toggle-toolbar / next-page regions per the user's
/// [TapZoneMode] preference. Rendered as a [Positioned.fill] overlay by
/// the parent state above the [MangaImageViewPaged].
class ReaderTapZones extends StatelessWidget {
  final ReaderViewProps props;
  const ReaderTapZones({super.key, required this.props});

  @override
  Widget build(BuildContext context) {
    final settings = props.settings;
    final current = props.currentPage;
    void prev() => props.onGoToPage(current.value - 1);
    void next() => props.onGoToPage(current.value + 1);

    switch (settings.tapZones) {
      case TapZoneMode.leftTopRightBottom:
        return LayoutBuilder(
          builder: (_, constraints) => Stack(
            children: [
              Positioned.fill(
                child: ClipPath(
                  clipper: const _TopLeftClipper(),
                  child: GestureDetector(
                    onTap: prev,
                    onLongPress: props.onLongPress,
                    behavior: HitTestBehavior.translucent,
                  ),
                ),
              ),
              Positioned.fill(
                child: ClipPath(
                  clipper: const _BottomRightClipper(),
                  child: GestureDetector(
                    onTap: next,
                    onLongPress: props.onLongPress,
                    behavior: HitTestBehavior.translucent,
                  ),
                ),
              ),
              // Center tap region to toggle the toolbar/overview so the
              // L/T/R/B layout never fully locks the user out of settings.
              Center(
                child: GestureDetector(
                  onTap: props.onToggleToolbar,
                  onLongPress: props.onLongPress,
                  behavior: HitTestBehavior.translucent,
                  child: SizedBox(
                    width: constraints.maxWidth * 0.34,
                    height: constraints.maxHeight * 0.34,
                  ),
                ),
              ),
            ],
          ),
        );
      case TapZoneMode.leftRight:
        return Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: prev,
                onLongPress: props.onLongPress,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: props.onToggleToolbar,
                onLongPress: props.onLongPress,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: next,
                onLongPress: props.onLongPress,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        );
      case TapZoneMode.leftCenterRight:
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: prev,
                onLongPress: props.onLongPress,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
            Expanded(
              flex: 6,
              child: GestureDetector(
                onTap: props.onToggleToolbar,
                onLongPress: props.onLongPress,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: next,
                onLongPress: props.onLongPress,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        );
    }
  }
}

class _TopLeftClipper extends CustomClipper<Path> {
  const _TopLeftClipper();
  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(0, size.height)
    ..close();
  @override
  bool shouldReclip(_) => false;
}

class _BottomRightClipper extends CustomClipper<Path> {
  const _BottomRightClipper();
  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();
  @override
  bool shouldReclip(_) => false;
}

/// Fallback shown when a page has no image (no URL and no local file).
/// Mirrors the broken-image placeholder used by [ReaderPageImage].
class _BrokenPage extends StatelessWidget {
  final VoidCallback onRetry;
  const _BrokenPage({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image, color: Colors.white38, size: 48),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, color: Colors.white54),
            label: const Text('Retry', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}

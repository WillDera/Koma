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
/// each page is a pinch-zoomable [SubsamplingScaleImageView], with chapter
/// separators rendered as [TransitionViewPaged]. Book mode packs two pages
/// per spread.
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
        allowImplicitScrolling: true,
        itemCount: (pages.length / 2).ceil(),
        onPageChanged: (i) => props.onPageChanged(i * 2),
        itemBuilder: (_, spreadIndex) {
          final leftIdx = spreadIndex * 2;
          final rightIdx = leftIdx + 1;
          return _KeepAlivePage(
            child: Row(
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
            ),
          );
        },
      );
    }

    return PageView.builder(
      controller: pageController,
      scrollDirection: axis,
      reverse: reverse,
      allowImplicitScrolling: true,
      itemCount: pages.length,
      onPageChanged: props.onPageChanged,
      itemBuilder: (_, i) => _KeepAlivePage(child: _buildPage(context, i)),
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

    // Prefer a previously resolved on-disk cache path so revisiting a page
    // skips the network/provider pipeline (mangayomi UChapDataPreload seam).
    final ImageProvider imageProvider;
    final String? resolvedFilePath;
    if (page.localPath != null) {
      imageProvider = FileImage(File(page.localPath!));
      resolvedFilePath = page.localPath;
    } else if (page.resolvedFilePath != null &&
        File(page.resolvedFilePath!).existsSync()) {
      imageProvider = FileImage(File(page.resolvedFilePath!));
      resolvedFilePath = page.resolvedFilePath;
    } else if (page.imageUrl.isNotEmpty) {
      imageProvider = CustomExtendedNetworkImageProvider(
        page.imageUrl,
        headers: page.headers,
        cacheMaxAge: const Duration(days: 7),
        imageCacheFolderName: 'cacheimagemanga',
        showCloudFlareError: true,
      );
      resolvedFilePath = page.resolvedFilePath;
    } else {
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
          if (settings.disableDoubleTap) props.onRetryPage(index);
        },
      ),
    );
  }
}

/// Keeps visited pages alive in the [PageView] so flipping back does not
/// dispose/rebuild the subsampling viewer (visible reload flash).
class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Tap-zone overlay for paged mode.
///
/// - L/R: three full-height columns — L/R navigate (top+mid+bottom of each
///   side), M toggles the toolbar only.
/// - L/M/R: mangayomi default — same L|M|R columns plus full-width top
///   (prev) / bottom (next) strips so middle-top and middle-bottom navigate.
class ReaderTapZones extends StatelessWidget {
  final ReaderViewProps props;
  const ReaderTapZones({super.key, required this.props});

  @override
  Widget build(BuildContext context) {
    final settings = props.settings;
    final current = props.currentPage;
    final isRtl = settings.readingMode == ReadingMode.rightToLeft;

    void goPrev() => props.onGoToPage(current.value - 1);
    void goNext() => props.onGoToPage(current.value + 1);
    // In RTL the visual left edge advances reading direction (= next page).
    final leftAction = isRtl ? goNext : goPrev;
    final rightAction = isRtl ? goPrev : goNext;

    Widget zone(VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      onLongPress: props.onLongPress,
      behavior: HitTestBehavior.translucent,
      child: const SizedBox.expand(),
    );

    Widget threeColumn() => Row(
      children: [
        Expanded(child: zone(leftAction)),
        Expanded(child: zone(props.onToggleToolbar)),
        Expanded(child: zone(rightAction)),
      ],
    );

    final mode = settings.tapZones == TapZoneMode.leftTopRightBottom
        ? TapZoneMode.leftRight
        : settings.tapZones;

    switch (mode) {
      case TapZoneMode.leftRight:
        // L | M | R — M is toolbar-only so the center remains tappable.
        return threeColumn();

      case TapZoneMode.leftMiddleRight:
        // Mangayomi default: L|M|R under full-width top/bottom strips.
        return Stack(
          children: [
            threeColumn(),
            Column(
              children: [
                Expanded(flex: 2, child: zone(goPrev)),
                const Expanded(flex: 5, child: SizedBox.shrink()),
                Expanded(flex: 2, child: zone(goNext)),
              ],
            ),
          ],
        );

      case TapZoneMode.leftTopRightBottom:
        // Unreachable after the remapping above; keep for exhaustiveness.
        return threeColumn();
    }
  }
}

/// Fallback shown when a page has no image (no URL and no local file).
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

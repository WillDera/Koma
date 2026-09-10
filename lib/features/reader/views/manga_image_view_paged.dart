import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/utils/custom_extended_image_provider.dart';
import '../models/page_data.dart';
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
///
/// Swipe uses [PageScrollPhysics] at rest; when any page is zoomed past
/// `minScale * 1.05`, physics switches to [NeverScrollableScrollPhysics] so
/// pan stays on the image (same idea as [KrePageView] `onZoomed`).
/// The "Animated page transition" setting only affects tap-driven jumps via
/// [PageController.animateToPage] vs [PageController.jumpToPage].
class MangaImageViewPaged extends StatefulWidget {
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
  State<MangaImageViewPaged> createState() => _MangaImageViewPagedState();

  /// Packs pages into spreads for book mode. Transition pages occupy a
  /// solo spread so they are never paired with an image page.
  static List<({int left, int? right})> packSpreads(List<PageData> pages) {
    final spreads = <({int left, int? right})>[];
    var i = 0;
    while (i < pages.length) {
      if (pages[i].isTransitionPage) {
        spreads.add((left: i, right: null));
        i++;
        continue;
      }
      final next = i + 1;
      if (next < pages.length && !pages[next].isTransitionPage) {
        spreads.add((left: i, right: next));
        i += 2;
      } else {
        spreads.add((left: i, right: null));
        i++;
      }
    }
    return spreads;
  }

  /// Maps a flat page index onto a book-mode spread index.
  static int spreadIndexForPage(List<PageData> pages, int flatIndex) {
    final spreads = packSpreads(pages);
    for (var s = 0; s < spreads.length; s++) {
      final sp = spreads[s];
      if (sp.left == flatIndex || sp.right == flatIndex) return s;
    }
    return 0;
  }
}

class _MangaImageViewPagedState extends State<MangaImageViewPaged> {
  bool _pageZoomed = false;
  final Map<int, SubsamplingScaleImageViewController> _controllers = {};
  final Set<int> _zoomedPages = {};

  ReaderViewProps get props => widget.props;
  PageController get pageController => widget.pageController;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MangaImageViewPaged oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.props.pages, widget.props.pages)) {
      final stale = List<SubsamplingScaleImageViewController>.from(
        _controllers.values,
      );
      _controllers.clear();
      _zoomedPages.clear();
      if (_pageZoomed) {
        _pageZoomed = false;
      }
      // Dispose after children detach so notifyListeners isn't called on a
      // disposed ChangeNotifier during the same rebuild.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final c in stale) {
          c.dispose();
        }
      });
    }
  }

  SubsamplingScaleImageViewController _controllerFor(int index) {
    return _controllers.putIfAbsent(
      index,
      SubsamplingScaleImageViewController.new,
    );
  }

  void _onScaleChanged(int pageIndex, double scale) {
    final ctrl = _controllers[pageIndex];
    if (ctrl == null || !ctrl.isReady) return;
    final zoomed = scale > ctrl.minScale * 1.05;
    final was = _zoomedPages.isNotEmpty;
    if (zoomed) {
      _zoomedPages.add(pageIndex);
    } else {
      _zoomedPages.remove(pageIndex);
    }
    final now = _zoomedPages.isNotEmpty;
    if (was != now && mounted) {
      setState(() => _pageZoomed = now);
    }
  }

  void _onPageChanged(int flatPageIndex) {
    // Changing pages is only possible when not zoomed; clear stale zoom flags.
    if (_pageZoomed || _zoomedPages.isNotEmpty) {
      _zoomedPages.clear();
      setState(() => _pageZoomed = false);
    }
    props.onPageChanged(flatPageIndex);
  }

  @override
  Widget build(BuildContext context) {
    final pages = props.pages;
    final physics =
        _pageZoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics();

    if (widget.bookMode) {
      final spreads = MangaImageViewPaged.packSpreads(pages);
      return PageView.builder(
        controller: pageController,
        scrollDirection: widget.axis,
        reverse: widget.reverse,
        physics: physics,
        allowImplicitScrolling: true,
        itemCount: spreads.length,
        onPageChanged: (i) {
          if (i < 0 || i >= spreads.length) return;
          _onPageChanged(spreads[i].left);
        },
        itemBuilder: (_, spreadIndex) {
          final spread = spreads[spreadIndex];
          final leftIdx = spread.left;
          final rightIdx = spread.right;
          if (rightIdx == null) {
            return _KeepAlivePage(
              pageIndex: leftIdx,
              currentPage: props.currentPage,
              child: _buildPage(context, leftIdx),
            );
          }
          return _KeepAlivePage(
            pageIndex: leftIdx,
            currentPage: props.currentPage,
            child: Row(
              children: [
                Expanded(child: _buildPage(context, leftIdx)),
                Container(width: 1, color: Colors.white12),
                Expanded(child: _buildPage(context, rightIdx)),
              ],
            ),
          );
        },
      );
    }

    return PageView.builder(
      controller: pageController,
      scrollDirection: widget.axis,
      reverse: widget.reverse,
      physics: physics,
      allowImplicitScrolling: true,
      itemCount: pages.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (_, i) => _KeepAlivePage(
        pageIndex: i,
        currentPage: props.currentPage,
        child: _buildPage(context, i),
      ),
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
    } else if (page.resolvedFilePath != null) {
      // Trust the path written by SubsamplingScaleImageView after the first
      // resolve — avoid sync filesystem checks on the UI isolate.
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
      return _BrokenPage(
        onRetry: () => props.onRetryPage(index),
        onToggleToolbar: props.onToggleToolbar,
      );
    }

    final padding = settings.sidePadding;
    final hPad = (MediaQuery.of(context).size.width * padding) / 2;
    final vPad = (MediaQuery.of(context).size.height * padding) / 2;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      child: SubsamplingScaleImageView(
        key: ValueKey(
          'page-$index-r${props.pageRetryTokens[index] ?? 0}',
        ),
        image: imageProvider,
        resolvedFilePath: resolvedFilePath,
        preloadData: page,
        cropBorders: settings.cropBorders,
        // Book mode starts zoomed out (contain). Pinch to zoom in; double-tap
        // fits the panel to the half-spread cell (centerCrop).
        fit: BoxFit.contain,
        minimumScaleType: ScaleType.centerInside,
        initialScaleType: ScaleType.centerInside,
        doubleTapScaleType:
            settings.disableDoubleTap ? null : ScaleType.centerCrop,
        panEnabled: !settings.disableDoubleTap || !settings.disableZoomOut,
        zoomEnabled: !settings.disableZoomOut,
        doubleTapZoomScale: settings.disableDoubleTap ? 1.0 : null,
        controller: _controllerFor(index),
        pageController: pageController,
        onScaleChanged: (scale) => _onScaleChanged(index, scale),
        onTap: props.onToggleToolbar,
        onError: (msg) {
          if (settings.disableDoubleTap) props.onRetryPage(index);
        },
      ),
    );
  }
}

/// Keeps nearby pages alive so flipping back does not dispose the
/// subsampling viewer. Windowed to ±[_keepRadius] of the current page to
/// bound RAM on long chapters.
class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  final int pageIndex;
  final ValueNotifier<int> currentPage;

  static const int _keepRadius = 2;

  const _KeepAlivePage({
    required this.child,
    required this.pageIndex,
    required this.currentPage,
  });

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive =>
      (widget.pageIndex - widget.currentPage.value).abs() <=
      _KeepAlivePage._keepRadius;

  @override
  void initState() {
    super.initState();
    widget.currentPage.addListener(_onCurrentPage);
  }

  @override
  void didUpdateWidget(covariant _KeepAlivePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage) {
      oldWidget.currentPage.removeListener(_onCurrentPage);
      widget.currentPage.addListener(_onCurrentPage);
    }
    updateKeepAlive();
  }

  void _onCurrentPage() => updateKeepAlive();

  @override
  void dispose() {
    widget.currentPage.removeListener(_onCurrentPage);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Tap-zone overlay for paged mode.
///
/// - L/R: three full-height columns — L/R navigate; center passes through so
///   page content (image tap → toolbar, Reload button) can receive hits.
/// - L/M/R: same L|M|R columns plus full-width top (prev) / bottom (next)
///   strips; the center band still passes through.
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

    // Center column must NOT absorb hits — broken-page "Reload image" and
    // the image itself live under this overlay. Toolbar toggle is handled by
    // onTap on the page content (see SubsamplingScaleImageView / webtoon wrap).
    Widget threeColumn() => Row(
      children: [
        Expanded(child: zone(leftAction)),
        const Expanded(child: SizedBox.expand()),
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
  final VoidCallback? onToggleToolbar;
  const _BrokenPage({required this.onRetry, this.onToggleToolbar});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggleToolbar,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image, color: Colors.white38, size: 48),
            const SizedBox(height: 8),
            // Absorb pointer so parent toolbar tap does not fire with reload.
            TextButton.icon(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              icon: const Icon(Icons.refresh, color: Colors.white54),
              label: const Text(
                'Reload image',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

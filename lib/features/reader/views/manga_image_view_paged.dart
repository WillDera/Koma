import 'package:flutter/material.dart';

import '../reader_settings_sheet.dart';
import '../widgets/transition_view_paged.dart';
import 'reader_page_image.dart';
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
      return TransitionViewPaged(
        data: page,
        readerMode: settings.readingMode,
      );
    }

    final zc = index < props.zoomControllers.length
        ? props.zoomControllers[index]
        : TransformationController();
    final padding = settings.sidePadding;
    final hPad = (MediaQuery.of(context).size.width * padding) / 2;
    final vPad = (MediaQuery.of(context).size.height * padding) / 2;

    final imageWidget = ReaderPageImage(
      page: page,
      cropBorders: settings.cropBorders,
      onRetry: () => props.onRetryPage(index),
    );

    if (settings.disableDoubleTap && settings.disableZoomOut) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        child: imageWidget,
      );
    }
    return GestureDetector(
      onDoubleTap: settings.disableDoubleTap
          ? null
          : () {
              final matrix = zc.value;
              if (matrix.getMaxScaleOnAxis() > 1.1) {
                zc.value = Matrix4.identity();
              } else {
                zc.value = Matrix4.identity()..scale(2.0);
              }
            },
      child: InteractiveViewer(
        transformationController: zc,
        minScale: settings.disableZoomOut ? 1.0 : 0.5,
        maxScale: 5.0,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          child: imageWidget,
        ),
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

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'page_curl_config.dart';
import 'page_curl_controller.dart';
import 'page_curl_gesture_handler.dart';
import 'page_curl_mesh.dart';
import 'page_curl_renderer.dart';

/// Builds the page at [index]. Returning null means "no page there" and
/// disables turning in that direction.
typedef PageCurlBuilder = Widget? Function(BuildContext context, int index);

/// An Apple Books-style interactive page curl.
///
/// Engine-agnostic: it accepts any widget per page, so it works equally for
/// EPUB text, PDF renders, manga panels or arbitrary Flutter content.
///
/// ## How text stays sharp
///
/// While idle, the current page is a live widget subtree — real text, real
/// selection, real hit-testing, vector-crisp at any zoom. Mesh deformation
/// requires a texture, so the moment a turn begins the page is rasterized at
/// `devicePixelRatio * config.textureOversample` and the mesh resamples that
/// bitmap. The instant the turn settles, the live widget is restored. Glyphs
/// are only ever resampled mid-motion, where the eye cannot resolve the
/// difference — the same trade Apple Books makes.
class PageCurlView extends StatefulWidget {
  const PageCurlView({
    super.key,
    required this.pageBuilder,
    required this.pageIndex,
    required this.onPageChanged,
    this.config = const PageCurlConfig(),
    this.controller,
    this.edgeWidth = 56.0,
    this.enabled = true,
    this.tapToTurn = true,
  });

  /// Supplies page content by index.
  final PageCurlBuilder pageBuilder;

  /// The page currently displayed.
  final int pageIndex;

  /// Called when a turn completes. The host updates [pageIndex] in response.
  final ValueChanged<int> onPageChanged;

  final PageCurlConfig config;

  /// Optional external controller, for programmatic turns. One is created
  /// internally when omitted.
  final PageCurlController? controller;

  final double edgeWidth;
  final bool enabled;
  final bool tapToTurn;

  @override
  State<PageCurlView> createState() => _PageCurlViewState();
}

class _PageCurlViewState extends State<PageCurlView>
    with SingleTickerProviderStateMixin {
  late PageCurlController _controller;
  bool _ownsController = false;
  late PageCurlMesh _mesh;

  final GlobalKey _currentKey = GlobalKey();
  final GlobalKey _nextKey = GlobalKey();

  ui.Image? _currentSnapshot;
  ui.Image? _nextSnapshot;

  /// True while a turn is running: pages render as textures, not live widgets.
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _mesh = PageCurlMesh(widget.config);
    _controller =
        widget.controller ??
        PageCurlController(vsync: this, config: widget.config);
    _ownsController = widget.controller == null;
    _controller
      ..onTurnCompleted = _handleCompleted
      ..onTurnCancelled = _handleCancelled;
    _controller.addListener(_handleStateChange);
  }

  @override
  void didUpdateWidget(covariant PageCurlView old) {
    super.didUpdateWidget(old);
    if (widget.config != old.config) {
      _controller.config = widget.config;
      _mesh.config = widget.config;
    }
    if (widget.pageIndex != old.pageIndex) {
      _releaseSnapshots();
    }
  }

  void _handleStateChange() {
    final active = _controller.value.active;
    if (active && !_capturing) {
      _beginCapture();
    }
  }

  /// Rasterizes both pages and switches to texture rendering for the turn.
  void _beginCapture() {
    final current = _snapshot(_currentKey);
    final next = _snapshot(_nextKey);
    if (current == null) return;
    _currentSnapshot?.dispose();
    _nextSnapshot?.dispose();
    _currentSnapshot = current;
    _nextSnapshot = next;
    setState(() => _capturing = true);
  }

  /// Synchronously rasterizes a subtree.
  ///
  /// `toImageSync` keeps the pixels on the GPU and does not await a frame, so
  /// the first frame of the turn is never blank.
  ui.Image? _snapshot(GlobalKey key) {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    return boundary.toImageSync(
      pixelRatio: dpr * widget.config.textureOversample,
    );
  }

  void _handleCompleted(CurlEdge edge) {
    final delta = edge == CurlEdge.right ? 1 : -1;
    widget.onPageChanged(widget.pageIndex + delta);
    _endCapture();
  }

  void _handleCancelled(CurlEdge edge) => _endCapture();

  void _endCapture() {
    if (!mounted) return;
    setState(() => _capturing = false);
    // Hold the textures one frame past the swap so the live subtree has a
    // chance to lay out before they are freed — otherwise the page flickers.
    WidgetsBinding.instance.addPostFrameCallback((_) => _releaseSnapshots());
  }

  void _releaseSnapshots() {
    _currentSnapshot?.dispose();
    _nextSnapshot?.dispose();
    _currentSnapshot = null;
    _nextSnapshot = null;
  }

  @override
  void dispose() {
    _controller.removeListener(_handleStateChange);
    if (_ownsController) _controller.dispose();
    _releaseSnapshots();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.pageBuilder(context, widget.pageIndex);
    final forward = widget.pageBuilder(context, widget.pageIndex + 1);
    final backward = widget.pageBuilder(context, widget.pageIndex - 1);

    // Which page is revealed depends on the direction being dragged.
    final edge = _controller.value.edge;
    final incoming = edge == CurlEdge.right ? forward : backward;

    return LayoutBuilder(
      builder: (context, constraints) {
        _controller.updatePageWidth(constraints.maxWidth);

        return PageCurlGestureHandler(
          controller: _controller,
          edgeWidth: widget.edgeWidth,
          enabled: widget.enabled,
          tapToTurn: widget.tapToTurn,
          canTurnForward: forward != null,
          canTurnBackward: backward != null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The incoming page sits underneath, revealed as the sheet lifts.
              // Kept in the tree (offstage-ish) so its snapshot is available
              // the instant a drag starts.
              RepaintBoundary(
                key: _nextKey,
                child: incoming ?? const SizedBox.shrink(),
              ),

              // The outgoing page. Hidden during the turn — the painter draws
              // its texture instead — but still mounted so state is preserved.
              Offstage(
                offstage: _capturing,
                child: RepaintBoundary(
                  key: _currentKey,
                  child: current ?? const SizedBox.shrink(),
                ),
              ),

              // The curl itself. Repaints off the controller, so a drag never
              // rebuilds the widget tree.
              if (_capturing)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: PageCurlRenderer(
                        state: _controller.value,
                        mesh: _mesh,
                        config: widget.config,
                        currentPage: _currentSnapshot,
                        nextPage: _nextSnapshot,
                        repaint: _controller,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'page_curl_config.dart';
import 'page_curl_controller.dart';

/// Translates raw pointer input into curl gestures.
///
/// Wraps its child in a horizontal-drag recognizer that only claims the
/// pointer when the drag starts within [edgeWidth] of either side, so
/// vertically-scrolling or horizontally-panning page content keeps working
/// everywhere else on the page.
class PageCurlGestureHandler extends StatefulWidget {
  const PageCurlGestureHandler({
    super.key,
    required this.controller,
    required this.child,
    this.edgeWidth = 56.0,
    this.enabled = true,
    this.canTurnForward = true,
    this.canTurnBackward = true,
    this.tapToTurn = true,
  });

  final PageCurlController controller;
  final Widget child;

  /// Width of the drag-sensitive strip at each edge, in logical pixels.
  final double edgeWidth;

  final bool enabled;

  /// Whether a forward turn (drag from the right edge) is available.
  final bool canTurnForward;

  /// Whether a backward turn (drag from the left edge) is available.
  final bool canTurnBackward;

  /// Whether tapping an edge strip turns the page.
  final bool tapToTurn;

  @override
  State<PageCurlGestureHandler> createState() => _PageCurlGestureHandlerState();
}

class _PageCurlGestureHandlerState extends State<PageCurlGestureHandler> {
  Offset _dragStart = Offset.zero;
  CurlEdge? _activeEdge;

  /// Resolves which edge a pointer-down at [local] belongs to, or null if the
  /// touch landed outside both strips or that direction is unavailable.
  CurlEdge? _edgeFor(Offset local, Size size) {
    if (local.dx <= widget.edgeWidth) {
      return widget.canTurnBackward ? CurlEdge.left : null;
    }
    if (local.dx >= size.width - widget.edgeWidth) {
      return widget.canTurnForward ? CurlEdge.right : null;
    }
    return null;
  }

  void _onDragDown(DragDownDetails details, Size size) {
    _activeEdge = _edgeFor(details.localPosition, size);
    _dragStart = details.localPosition;
  }

  void _onDragStart(DragStartDetails details) {
    final edge = _activeEdge;
    if (edge == null) return;
    widget.controller.beginDrag(edge: edge, origin: _dragStart.dy);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_activeEdge == null) return;
    widget.controller.updateDrag(details.localPosition - _dragStart);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_activeEdge == null) return;
    widget.controller.endDrag(velocity: details.velocity.pixelsPerSecond.dx);
    _activeEdge = null;
  }

  void _onDragCancel() {
    if (_activeEdge == null) return;
    widget.controller.endDrag(velocity: 0);
    _activeEdge = null;
  }

  void _onTapUp(TapUpDetails details, Size size) {
    if (!widget.tapToTurn) return;
    final edge = _edgeFor(details.localPosition, size);
    if (edge == null) return;
    widget.controller.turn(edge);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return RawGestureDetector(
          behavior: HitTestBehavior.translucent,
          gestures: <Type, GestureRecognizerFactory>{
            _EdgeHorizontalDragRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  _EdgeHorizontalDragRecognizer
                >(
                  () => _EdgeHorizontalDragRecognizer(
                    isEdgeTouch: (position) => _edgeFor(position, size) != null,
                  ),
                  (recognizer) {
                    recognizer.onDown = (d) => _onDragDown(d, size);
                    recognizer.onStart = _onDragStart;
                    recognizer.onUpdate = _onDragUpdate;
                    recognizer.onEnd = _onDragEnd;
                    recognizer.onCancel = _onDragCancel;
                  },
                ),
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(),
                  (recognizer) {
                    recognizer.onTapUp = (d) => _onTapUp(d, size);
                  },
                ),
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Horizontal drag recognizer that declines pointers starting away from an
/// edge, letting page content win the arena instead.
class _EdgeHorizontalDragRecognizer extends HorizontalDragGestureRecognizer {
  _EdgeHorizontalDragRecognizer({required this.isEdgeTouch});

  final bool Function(Offset localPosition) isEdgeTouch;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (!isEdgeTouch(event.localPosition)) {
      // Not our gesture — never enter the arena, so nested scrollables and
      // image panning behave exactly as they would without the curl layer.
      resolve(GestureDisposition.rejected);
      return;
    }
    super.addAllowedPointer(event);
  }
}

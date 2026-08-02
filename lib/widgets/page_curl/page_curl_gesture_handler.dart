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

  /// Pointer being tracked for a possible edge tap, and where it went down.
  int? _tapPointer;
  Offset _tapDown = Offset.zero;

  /// Whether the active drag ever moved, distinguishing a drag from a tap.
  bool _dragMoved = false;

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
    _dragMoved = true;
    widget.controller.updateDrag(details.localPosition - _dragStart);
  }

  void _onDragEnd(DragEndDetails details) {
    final wasDrag = _dragMoved;
    _dragMoved = false;
    if (_activeEdge == null) return;
    _activeEdge = null;
    // A press inside an edge strip that never moved is a tap, and the drag
    // recognizer is the only arena member so it wins by default. Settling it
    // here would spring the curl straight back to flat and undo the turn the
    // tap handler just started, so the tap is left to own the gesture.
    if (!wasDrag) return;
    widget.controller.endDrag(velocity: details.velocity.pixelsPerSecond.dx);
  }

  void _onDragCancel() {
    final wasDrag = _dragMoved;
    _dragMoved = false;
    if (_activeEdge == null) return;
    _activeEdge = null;
    // Rejection without movement means another recognizer claimed the tap —
    // selectable page text does exactly this. As in [_onDragEnd], settling here
    // would undo the tap's turn, so the gesture is left alone.
    if (!wasDrag) return;
    widget.controller.endDrag(velocity: 0);
  }

  void _onPointerDown(PointerDownEvent event) {
    _tapPointer = event.pointer;
    _tapDown = event.localPosition;
  }

  /// Turns the page when a pointer is released where it went down, inside an
  /// edge strip, having travelled less than the touch slop — i.e. a tap.
  ///
  /// Deliberately driven from raw pointer events rather than a
  /// [TapGestureRecognizer]: page content is usually selectable text, whose own
  /// tap recognizer sits deeper in the tree and so joins the gesture arena
  /// first. It therefore wins the sweep on pointer-up and a recognizer here
  /// would never fire. A [Listener] sees the events regardless of who wins the
  /// arena, which keeps edge taps working over selectable text while leaving
  /// selection itself untouched.
  void _onPointerUp(PointerUpEvent event, Size size) {
    final pointer = _tapPointer;
    _tapPointer = null;
    if (!widget.tapToTurn || pointer != event.pointer) return;
    // Anything that travelled further was a drag, which the recognizer above
    // has already handled.
    if ((event.localPosition - _tapDown).distance > kTouchSlop) return;
    final edge = _edgeFor(_tapDown, size);
    if (edge == null) return;
    widget.controller.turn(edge);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onPointerDown,
          onPointerUp: (e) => _onPointerUp(e, size),
          onPointerCancel: (_) => _tapPointer = null,
          child: RawGestureDetector(
            behavior: HitTestBehavior.translucent,
            gestures: <Type, GestureRecognizerFactory>{
              _EdgeHorizontalDragRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    _EdgeHorizontalDragRecognizer
                  >(
                    () => _EdgeHorizontalDragRecognizer(
                      isEdgeTouch: (p) => _edgeFor(p, size) != null,
                    ),
                    (recognizer) {
                      recognizer.onDown = (d) => _onDragDown(d, size);
                      recognizer.onStart = _onDragStart;
                      recognizer.onUpdate = _onDragUpdate;
                      recognizer.onEnd = _onDragEnd;
                      recognizer.onCancel = _onDragCancel;
                    },
                  ),
            },
            child: widget.child,
          ),
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
    // SelectableText installs a horizontal-drag recognizer deeper in the tree,
    // which joins the arena first and would win on pointer-up. Claiming
    // immediately reserves edge-strip touches for the curl — text selection
    // there is unwanted by design, and a vertical drag will self-reject anyway
    // once the recognizer sees the direction.
    resolve(GestureDisposition.accepted);
  }
}

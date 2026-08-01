import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

import 'page_curl_config.dart';
import 'page_curl_physics.dart';

/// Live state of a turn, read by the renderer each frame.
@immutable
class PageCurlState {
  /// 0 = flat, 1 = fully turned.
  final double progress;

  /// Which edge the turn started from.
  final CurlEdge edge;

  /// Finger offset from the drag start, in logical pixels.
  final Offset dragVector;

  /// Vertical position the drag started at — sets the cone apex.
  final double origin;

  /// True while a turn is in progress (dragging or settling).
  final bool active;

  const PageCurlState({
    required this.progress,
    required this.edge,
    required this.dragVector,
    required this.origin,
    required this.active,
  });

  static const idle = PageCurlState(
    progress: 0,
    edge: CurlEdge.right,
    dragVector: Offset.zero,
    origin: 0,
    active: false,
  );

  PageCurlState copyWith({
    double? progress,
    CurlEdge? edge,
    Offset? dragVector,
    double? origin,
    bool? active,
  }) {
    return PageCurlState(
      progress: progress ?? this.progress,
      edge: edge ?? this.edge,
      dragVector: dragVector ?? this.dragVector,
      origin: origin ?? this.origin,
      active: active ?? this.active,
    );
  }
}

/// Drives a page turn and owns its animation clock.
///
/// Extends [ValueNotifier] so the renderer can subscribe to per-frame state
/// without the host widget rebuilding: the repaint path is a
/// `CustomPainter` listening to this, not `setState`.
class PageCurlController extends ValueNotifier<PageCurlState> {
  PageCurlController({
    required TickerProvider vsync,
    PageCurlConfig config = const PageCurlConfig(),
    this.onTurnCompleted,
    this.onTurnCancelled,
  }) : _config = config,
       _physics = PageCurlPhysics(config),
       super(PageCurlState.idle) {
    _ticker = vsync.createTicker(_onTick);
  }

  /// Fired once a turn settles past the threshold. The host advances its page
  /// index here. Mutable so a host can attach to a controller it was handed.
  void Function(CurlEdge edge)? onTurnCompleted;

  /// Fired when a turn springs back without completing.
  void Function(CurlEdge edge)? onTurnCancelled;

  PageCurlConfig _config;
  final PageCurlPhysics _physics;
  late final Ticker _ticker;

  Simulation? _simulation;
  double _simStart = 0;
  double _pageWidth = 0;
  bool _settlingToComplete = false;

  PageCurlConfig get config => _config;

  set config(PageCurlConfig value) {
    _config = value;
    _physics.config = value;
  }

  /// The renderer reports its size here so physics can work in page units.
  void updatePageWidth(double width) => _pageWidth = width;

  bool get isAnimating => _ticker.isActive;

  /// Begins an interactive turn from [edge], started at vertical position
  /// [origin].
  void beginDrag({required CurlEdge edge, required double origin}) {
    _stopSimulation();
    value = PageCurlState(
      progress: value.active ? value.progress : 0.0,
      edge: edge,
      dragVector: Offset.zero,
      origin: origin,
      active: true,
    );
  }

  /// Updates the turn from a live drag. [dragVector] is cumulative offset
  /// from the drag start.
  void updateDrag(Offset dragVector) {
    if (!value.active) return;
    // Advancing distance depends on which edge we pulled from.
    final advance = value.edge == CurlEdge.right
        ? -dragVector.dx
        : dragVector.dx;
    final progress = _physics.progressForDrag(
      dragDistance: advance,
      pageWidth: _pageWidth,
    );
    value = value.copyWith(progress: progress, dragVector: dragVector);
  }

  /// Ends an interactive turn. [velocity] is horizontal exit velocity in px/s
  /// as reported by the gesture recognizer.
  void endDrag({required double velocity}) {
    if (!value.active) return;
    // Normalize velocity so positive always means "advancing the turn".
    final advancing = value.edge == CurlEdge.right ? -velocity : velocity;
    final outcome = _physics.resolve(
      progress: value.progress,
      velocity: advancing,
    );
    final target = outcome == CurlRelease.complete ? 1.0 : 0.0;
    _settlingToComplete = outcome == CurlRelease.complete;
    _startSimulation(
      _physics.buildSpring(
        from: value.progress,
        to: target,
        velocity: advancing,
        pageWidth: _pageWidth,
      ),
    );
  }

  /// Programmatically turns a page, as if tapped rather than dragged.
  void turn(CurlEdge edge) {
    if (isAnimating) return;
    _stopSimulation();
    value = PageCurlState(
      progress: 0,
      edge: edge,
      // A synthetic drag straight across the page: no vertical component, so
      // the fold stays a clean cylinder.
      dragVector: Offset(edge == CurlEdge.right ? -_pageWidth : _pageWidth, 0),
      origin: 0,
      active: true,
    );
    _settlingToComplete = true;
    _startSimulation(
      _physics.buildSpring(
        from: 0,
        to: 1,
        velocity: _config.flingVelocityThreshold * 0.5,
        pageWidth: _pageWidth,
      ),
    );
  }

  void _startSimulation(Simulation sim) {
    _simulation = sim;
    _simStart = 0;
    if (!_ticker.isActive) _ticker.start();
  }

  void _stopSimulation() {
    _simulation = null;
    if (_ticker.isActive) _ticker.stop();
  }

  void _onTick(Duration elapsed) {
    final sim = _simulation;
    if (sim == null) {
      _ticker.stop();
      return;
    }
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (_simStart == 0) _simStart = seconds;
    final t = seconds - _simStart;

    final progress = sim.x(t).clamp(0.0, 1.0);
    value = value.copyWith(progress: progress);

    if (sim.isDone(t)) {
      _finish();
    }
  }

  void _finish() {
    _stopSimulation();
    final edge = value.edge;
    final completed = _settlingToComplete;
    // Reset to idle before notifying: the host swaps page content in the
    // callback, and it must not see a mid-turn state.
    value = PageCurlState.idle;
    if (completed) {
      onTurnCompleted?.call(edge);
    } else {
      onTurnCancelled?.call(edge);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

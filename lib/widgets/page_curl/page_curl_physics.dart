import 'dart:math' as math;

import 'package:flutter/physics.dart';

import 'page_curl_config.dart';

/// Outcome of a release gesture.
enum CurlRelease { complete, cancel }

/// Spring-based settling for the curl.
///
/// Release uses a real [SpringSimulation] seeded with the gesture's exit
/// velocity, so a fast flick completes faster than a slow drag past the
/// threshold — the thing that makes a canned curve feel synthetic.
class PageCurlPhysics {
  PageCurlConfig config;

  PageCurlPhysics(this.config);

  /// Decides whether a release should finish the turn or snap back.
  ///
  /// [progress] is the current curl progress (0..1). [velocity] is the
  /// gesture's horizontal exit velocity in px/s, positive in the direction
  /// that advances the turn.
  CurlRelease resolve({
    required double progress,
    required double velocity,
    double pageWidth = 400.0,
  }) {
    if (velocity > config.flingVelocityThreshold) return CurlRelease.complete;
    if (velocity < -config.flingVelocityThreshold) return CurlRelease.cancel;
    // Project a short distance along the release velocity. This lets a modest
    // forward/reverse gesture influence the decision on either side of the
    // threshold without the binary feel of a second velocity cutoff.
    final projected = pageWidth <= 0
        ? progress
        : progress + velocity / pageWidth * 0.16;
    return projected >= config.completionThreshold
        ? CurlRelease.complete
        : CurlRelease.cancel;
  }

  /// Builds the settling simulation from [from] progress to [to] progress.
  ///
  /// [velocity] is in px/s and is normalized against [pageWidth] so the
  /// simulation runs in progress units.
  SpringSimulation buildSpring({
    required double from,
    required double to,
    required double velocity,
    required double pageWidth,
  }) {
    final spec = SpringDescription.withDampingRatio(
      mass: 1.0,
      stiffness: config.springStiffness,
      ratio: config.springDamping,
    );
    final normalized = pageWidth <= 0 ? 0.0 : velocity / pageWidth;
    return SpringSimulation(spec, from, to, normalized);
  }

  /// Progress implied by a drag, as a fraction of page width.
  ///
  /// The response is eased near the extremes so the sheet resists slightly at
  /// the very start and end of the turn instead of tracking the finger
  /// linearly all the way — paper has to be lifted before it moves.
  double progressForDrag({
    required double dragDistance,
    required double pageWidth,
  }) {
    if (pageWidth <= 0) return 0.0;
    final raw = (dragDistance / pageWidth).clamp(0.0, 1.0);
    // Smootherstep-lite: keeps the midrange 1:1 with the finger while taking
    // the edge off both ends.
    const ease = 0.12;
    return raw * (1 - ease) + ease * raw * raw * (3 - 2 * raw);
  }

  /// Applies a cumulative drag to an already-partially-curled sheet.
  ///
  /// This is used when a finger catches a settling turn. Zero movement returns
  /// [from] exactly, avoiding the discontinuity caused by remapping from zero.
  double progressForDragFrom({
    required double from,
    required double dragDistance,
    required double pageWidth,
  }) {
    if (pageWidth <= 0) return from.clamp(0.0, 1.0);
    final sign = dragDistance < 0 ? -1.0 : 1.0;
    final delta = progressForDrag(
      dragDistance: dragDistance.abs(),
      pageWidth: pageWidth,
    );
    return (from + sign * delta).clamp(0.0, 1.0);
  }

  /// Duration for a programmatic turn, scaled by how far it has to travel.
  Duration durationFor(double delta) {
    final frac = delta.abs().clamp(0.0, 1.0);
    final ms = (config.animationDuration.inMilliseconds * math.max(frac, 0.35))
        .round();
    return Duration(milliseconds: ms);
  }
}

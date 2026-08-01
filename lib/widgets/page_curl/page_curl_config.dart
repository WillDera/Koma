import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Which edge a turn was started from.
enum CurlEdge { left, right }

/// Tunable parameters for the page curl. Every knob the renderer, mesh and
/// physics read lives here so a host can tweak feel without touching internals.
///
/// Defaults are calibrated against Apple Books on a 6.1" phone.
@immutable
class PageCurlConfig {
  /// Mesh subdivisions across the curl axis. Higher = smoother silhouette,
  /// more triangles. The curl runs along this axis so it carries most of the
  /// curvature; 40 is visually indistinguishable from 80 at typical radii.
  final int meshResolutionX;

  /// Mesh subdivisions along the fold line. Only needs to be high enough to
  /// keep the perspective foreshortening smooth.
  final int meshResolutionY;

  /// Base curl radius as a fraction of page width. The effective radius is
  /// modulated by drag distance (see [minCurlRadiusFactor]).
  final double curlRadiusFactor;

  /// Lower bound on the curl radius, as a fraction of [curlRadiusFactor].
  /// The curl tightens as the page approaches fully-turned; this stops it
  /// collapsing to a crease.
  final double minCurlRadiusFactor;

  /// How strongly the curl resists tightening. 0 = radius tracks drag
  /// distance linearly, 1 = radius stays near its base value throughout.
  final double curlStiffness;

  /// Spring stiffness for the release animation.
  final double springStiffness;

  /// Spring damping ratio. 1.0 is critically damped (no overshoot); slightly
  /// under 1 gives paper a touch of settle.
  final double springDamping;

  /// Fraction of page width the drag must pass for release to complete the
  /// turn rather than spring back.
  final double completionThreshold;

  /// Release velocity (px/s) above which the turn completes regardless of
  /// whether [completionThreshold] was reached.
  final double flingVelocityThreshold;

  /// Duration for programmatic (non-gesture) turns.
  final Duration animationDuration;

  /// Opacity of the shadow the lifted page casts on the page beneath it.
  final double shadowIntensity;

  /// Blur sigma for that cast shadow, in logical pixels.
  final double shadowBlurSigma;

  /// Strength of the diffuse shading across the curl. 0 disables shading.
  final double lightingIntensity;

  /// Strength of the moving specular highlight along the fold.
  final double specularIntensity;

  /// Direction the light arrives from, in page space. Positive y is down.
  final Offset lightDirection;

  /// Simulated sheet thickness in logical pixels. Drawn as an extruded edge
  /// along the fold so the page never reads as infinitely thin.
  final double paperThickness;

  /// How much darker the reverse of the sheet is. 0 = identical to front.
  final double backsideDarkening;

  /// How much saturation the reverse loses. 0 = identical to front.
  final double backsideDesaturation;

  /// Perspective focal length as a multiple of page width. Larger = flatter.
  final double perspective;

  /// Resolution multiplier applied on top of the device pixel ratio when
  /// snapshotting pages to textures. >1 keeps glyph edges clean while the
  /// mesh resamples them.
  final double textureOversample;

  const PageCurlConfig({
    this.meshResolutionX = 40,
    this.meshResolutionY = 12,
    this.curlRadiusFactor = 0.18,
    this.minCurlRadiusFactor = 0.35,
    this.curlStiffness = 0.55,
    this.springStiffness = 220.0,
    this.springDamping = 0.92,
    this.completionThreshold = 0.32,
    this.flingVelocityThreshold = 700.0,
    this.animationDuration = const Duration(milliseconds: 420),
    this.shadowIntensity = 0.38,
    this.shadowBlurSigma = 14.0,
    this.lightingIntensity = 0.55,
    this.specularIntensity = 0.28,
    this.lightDirection = const Offset(-0.45, -0.55),
    this.paperThickness = 1.6,
    this.backsideDarkening = 0.16,
    this.backsideDesaturation = 0.35,
    this.perspective = 2.4,
    this.textureOversample = 1.0,
  }) : assert(meshResolutionX >= 2),
       assert(meshResolutionY >= 1),
       assert(curlRadiusFactor > 0),
       assert(completionThreshold > 0 && completionThreshold < 1);

  PageCurlConfig copyWith({
    int? meshResolutionX,
    int? meshResolutionY,
    double? curlRadiusFactor,
    double? minCurlRadiusFactor,
    double? curlStiffness,
    double? springStiffness,
    double? springDamping,
    double? completionThreshold,
    double? flingVelocityThreshold,
    Duration? animationDuration,
    double? shadowIntensity,
    double? shadowBlurSigma,
    double? lightingIntensity,
    double? specularIntensity,
    Offset? lightDirection,
    double? paperThickness,
    double? backsideDarkening,
    double? backsideDesaturation,
    double? perspective,
    double? textureOversample,
  }) {
    return PageCurlConfig(
      meshResolutionX: meshResolutionX ?? this.meshResolutionX,
      meshResolutionY: meshResolutionY ?? this.meshResolutionY,
      curlRadiusFactor: curlRadiusFactor ?? this.curlRadiusFactor,
      minCurlRadiusFactor: minCurlRadiusFactor ?? this.minCurlRadiusFactor,
      curlStiffness: curlStiffness ?? this.curlStiffness,
      springStiffness: springStiffness ?? this.springStiffness,
      springDamping: springDamping ?? this.springDamping,
      completionThreshold: completionThreshold ?? this.completionThreshold,
      flingVelocityThreshold:
          flingVelocityThreshold ?? this.flingVelocityThreshold,
      animationDuration: animationDuration ?? this.animationDuration,
      shadowIntensity: shadowIntensity ?? this.shadowIntensity,
      shadowBlurSigma: shadowBlurSigma ?? this.shadowBlurSigma,
      lightingIntensity: lightingIntensity ?? this.lightingIntensity,
      specularIntensity: specularIntensity ?? this.specularIntensity,
      lightDirection: lightDirection ?? this.lightDirection,
      paperThickness: paperThickness ?? this.paperThickness,
      backsideDarkening: backsideDarkening ?? this.backsideDarkening,
      backsideDesaturation: backsideDesaturation ?? this.backsideDesaturation,
      perspective: perspective ?? this.perspective,
      textureOversample: textureOversample ?? this.textureOversample,
    );
  }
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'page_curl_config.dart';
import 'page_curl_controller.dart';
import 'page_curl_mesh.dart';

/// GPU resources whose inputs stay constant throughout one turn.
///
/// The view owns and disposes this cache with the page snapshots. Keeping it
/// outside [paint] avoids rebuilding image shaders and fitted-image paints on
/// every pointer/ticker frame.
class PageCurlRenderCache {
  ui.ImageShader? _shader;
  ui.Image? _shaderImage;
  Size _shaderSize = Size.zero;
  ui.ColorFilter? _backsideFilter;
  double _backsideDesaturation = -1;

  final Paint incomingPaint = Paint()..filterQuality = FilterQuality.high;
  final Paint frontPaint = Paint()..isAntiAlias = true;
  final Paint backPaint = Paint()..isAntiAlias = true;
  final Paint shadowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint contactPaint = Paint()..style = PaintingStyle.stroke;
  final Paint edgePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint edgeHighlightPaint = Paint()..style = PaintingStyle.stroke;

  ui.ImageShader shaderFor(ui.Image image, Size size) {
    if (_shader != null &&
        identical(image, _shaderImage) &&
        size == _shaderSize) {
      return _shader!;
    }
    _shader?.dispose();
    _shaderImage = image;
    _shaderSize = size;
    final sx = size.width / image.width;
    final sy = size.height / image.height;
    _shader = ui.ImageShader(
      image,
      ui.TileMode.clamp,
      ui.TileMode.clamp,
      Float64List.fromList(<double>[
        sx,
        0,
        0,
        0,
        0,
        sy,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        1,
      ]),
      filterQuality: FilterQuality.high,
    );
    return _shader!;
  }

  ui.ColorFilter backsideFilter(double desaturation) {
    final d = desaturation.clamp(0.0, 1.0);
    if (_backsideFilter != null && d == _backsideDesaturation) {
      return _backsideFilter!;
    }
    _backsideDesaturation = d;
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final s = 1.0 - d;
    return _backsideFilter = ui.ColorFilter.matrix(<double>[
      lr + s * (1 - lr),
      lg * (1 - s),
      lb * (1 - s),
      0,
      0,
      lr * (1 - s),
      lg + s * (1 - lg),
      lb * (1 - s),
      0,
      0,
      lr * (1 - s),
      lg * (1 - s),
      lb + s * (1 - lb),
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);
  }

  void dispose() {
    _shader?.dispose();
    _shader = null;
    _shaderImage = null;
  }
}

/// Paints one frame of a page turn from two pre-rasterized page textures.
///
/// Draw order, back to front:
///   1. the incoming page, clipped to the region the curling sheet has vacated
///   2. the shadow the lifted sheet casts onto it
///   3. the flat (not yet curled) part of the outgoing page
///   4. the curled sheet's backside, shaded and desaturated
///   5. the extruded fold edge that gives the sheet thickness
///
/// The painter owns no state beyond its inputs; the mesh buffers are supplied
/// by the caller and reused across frames.
class PageCurlRenderer extends CustomPainter {
  PageCurlRenderer({
    required this.stateListenable,
    required this.mesh,
    required this.config,
    required this.currentPage,
    required this.nextPage,
    required this.cache,
  }) : super(repaint: stateListenable);

  /// Live turn state, read fresh on every paint.
  ///
  /// This must be the notifier itself rather than a captured [PageCurlState]:
  /// the painter repaints off the controller without the widget tree
  /// rebuilding, so a snapshot taken at construction would stay frozen at the
  /// progress the turn started from — 0 — and every frame would fail the
  /// progress guard in [paint] and draw nothing.
  final ValueListenable<PageCurlState> stateListenable;

  PageCurlState get state => stateListenable.value;

  final PageCurlMesh mesh;
  final PageCurlConfig config;

  /// The page being turned away. Null until its snapshot is ready.
  final ui.Image? currentPage;

  /// The page being revealed. Null until its snapshot is ready.
  final ui.Image? nextPage;
  final PageCurlRenderCache cache;

  @override
  void paint(Canvas canvas, Size size) {
    final current = currentPage;
    if (!state.active || current == null) {
      // Idle: the host draws live widgets, not textures. Nothing to composite.
      return;
    }

    // Note there is deliberately no lower bound on progress here. The outgoing
    // page goes offstage the moment a turn becomes active, which happens on
    // pointer-down — before any movement. Skipping the paint at progress 0
    // would leave the page underneath exposed for as long as a finger rested on
    // an edge. At progress 0 the mesh is flat and the sheet covers the page
    // exactly, so this draws a pixel-identical stand-in for the live widget.

    mesh.config = config;
    final data = mesh.deform(
      size: size,
      edge: state.edge,
      progress: state.progress,
      dragVector: state.dragVector,
      origin: state.origin,
    );

    final fold = mesh.foldEdge(data, state.edge);

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    _paintIncoming(canvas, size);
    _paintCastShadow(canvas, data, fold);
    _paintSheet(canvas, size, data);
    _paintThickness(canvas, fold);

    canvas.restore();
  }

  /// The revealed page, masked so it only shows where the sheet has moved off.
  void _paintIncoming(Canvas canvas, Size size) {
    final next = nextPage;
    if (next == null) return;
    _drawImageFitted(canvas, next, size);
  }

  /// Soft shadow cast by the lifted sheet onto the page beneath.
  void _paintCastShadow(Canvas canvas, PageCurlMeshData data, Path fold) {
    if (config.shadowIntensity <= 0) return;
    if (fold.getBounds().isEmpty) return;
    final pageWidth = math.max(mesh.size.width, 1.0);
    final lift = (data.maxDepth / (pageWidth * 0.34)).clamp(0.0, 1.0);
    final alpha = (config.shadowIntensity * lift * 0.58).clamp(0.0, 0.34);
    if (alpha <= 0.001) return;

    final dir = config.lightDirection;
    final offset = Offset(-dir.dx, -dir.dy) * (2.0 + 7.0 * lift);

    final paint = cache.shadowPaint
      ..strokeWidth = 5.0 + 9.0 * lift
      ..color = const Color(0xFF000000).withValues(alpha: alpha)
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        math.min(config.shadowBlurSigma * (0.22 + lift * 0.34), 8.0),
      );
    canvas.drawPath(fold.shift(offset), paint);

    // Tight contact line anchors the sheet without a second large blur layer.
    canvas.drawPath(
      fold.shift(Offset(-dir.dx, -dir.dy) * 1.2),
      cache.contactPaint
        ..strokeWidth = 1.2
        ..color = const Color(0xFF000000).withValues(alpha: alpha * 0.72),
    );
  }

  /// The curling sheet itself — front face where it is still face-up, back
  /// face where it has folded past vertical.
  void _paintSheet(Canvas canvas, Size size, PageCurlMeshData data) {
    final current = currentPage;
    if (current == null) return;

    final vertices = mesh.buildVertices(data);
    final backVertices = mesh.buildVertices(data, backside: true);
    final shader = cache.shaderFor(current, size);
    cache.frontPaint.shader = shader;
    cache.backPaint
      ..shader = shader
      ..colorFilter = cache.backsideFilter(config.backsideDesaturation);

    // Vertex colors modulate the texture, which is how the diffuse shading
    // and specular band reach the pixels.
    canvas.drawVertices(vertices, ui.BlendMode.modulate, cache.frontPaint);

    // Backside pass: the part of the mesh that has folded over shows the
    // reverse of the sheet. It is drawn from the same texture but darkened
    // and desaturated, matching how real paper reads from behind.
    canvas.drawVertices(backVertices, ui.BlendMode.modulate, cache.backPaint);

    vertices.dispose();
    backVertices.dispose();
  }

  /// Extrudes the fold line slightly so the sheet has visible thickness.
  void _paintThickness(Canvas canvas, Path fold) {
    if (config.paperThickness <= 0) return;
    if (fold.getBounds().isEmpty) return;

    // A soft dark line along the ridge reads as the sheet's cut edge.
    final edgePaint = cache.edgePaint
      ..strokeWidth = config.paperThickness
      ..color = const Color(0xFF000000).withValues(alpha: 0.18);
    canvas.drawPath(fold, edgePaint);

    // A hairline highlight just inboard of it catches the light and sells the
    // idea that the edge has depth rather than being a drawn line.
    final highlight = cache.edgeHighlightPaint
      ..strokeWidth = math.max(config.paperThickness * 0.5, 0.5)
      ..color = const Color(
        0xFFFFFFFF,
      ).withValues(alpha: 0.30 * config.lightingIntensity.clamp(0.0, 1.0));
    canvas.drawPath(fold.shift(const Offset(0, -0.7)), highlight);
  }

  void _drawImageFitted(Canvas canvas, ui.Image image, Size size) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Offset.zero & size;
    canvas.drawImageRect(image, src, dst, cache.incomingPaint);
  }

  @override
  bool shouldRepaint(covariant PageCurlRenderer old) {
    // The controller drives repaints via the `repaint` Listenable, so this
    // only needs to catch input swaps.
    return old.currentPage != currentPage ||
        old.nextPage != nextPage ||
        old.config != config;
  }
}

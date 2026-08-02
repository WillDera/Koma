import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'page_curl_config.dart';
import 'page_curl_controller.dart';
import 'page_curl_mesh.dart';

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

  @override
  void paint(Canvas canvas, Size size) {
    final current = currentPage;
    if (!state.active || current == null || state.progress <= 0.0005) {
      // Idle: the host draws live widgets, not textures. Nothing to composite.
      return;
    }

    mesh.config = config;
    final data = mesh.deform(
      size: size,
      edge: state.edge,
      progress: state.progress,
      dragVector: state.dragVector,
      origin: state.origin,
      backside: false,
    );

    final silhouette = mesh.silhouette(data);

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    _paintIncoming(canvas, size, silhouette);
    _paintCastShadow(canvas, size, silhouette);
    _paintSheet(canvas, size, data);
    _paintThickness(canvas, data);

    canvas.restore();
  }

  /// The revealed page, masked so it only shows where the sheet has moved off.
  void _paintIncoming(Canvas canvas, Size size, Path silhouette) {
    final next = nextPage;
    if (next == null) return;
    canvas.save();
    // Everything outside the curled sheet's outline is newly exposed.
    canvas.clipPath(silhouette, doAntiAlias: true);
    _drawImageFitted(canvas, next, size);
    canvas.restore();
  }

  /// Soft shadow cast by the lifted sheet onto the page beneath.
  void _paintCastShadow(Canvas canvas, Size size, Path silhouette) {
    if (config.shadowIntensity <= 0) return;
    // Shadow strength peaks mid-turn: at the very start the sheet is flat on
    // the page, at the end it has left the surface entirely.
    final lift = math.sin(state.progress.clamp(0.0, 1.0) * math.pi);
    final alpha = (config.shadowIntensity * lift).clamp(0.0, 1.0);
    if (alpha <= 0.001) return;

    final dir = config.lightDirection;
    final offset = Offset(-dir.dx, -dir.dy) * (6.0 + 10.0 * lift);

    final paint = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: alpha)
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        config.shadowBlurSigma * (0.5 + lift),
      );

    canvas.save();
    // Confine the shadow to the exposed region so it doesn't bleed over the
    // sheet that is casting it.
    canvas.clipPath(silhouette, doAntiAlias: true);
    canvas.drawPath(silhouette.shift(offset), paint);
    canvas.restore();
  }

  /// The curling sheet itself — front face where it is still face-up, back
  /// face where it has folded past vertical.
  void _paintSheet(Canvas canvas, Size size, PageCurlMeshData data) {
    final current = currentPage;
    if (current == null) return;

    final vertices = mesh.buildVertices(data);
    final shader = ui.ImageShader(
      current,
      ui.TileMode.clamp,
      ui.TileMode.clamp,
      _imageMatrix(current, size),
      filterQuality: FilterQuality.high,
    );

    final paint = Paint()
      ..shader = shader
      ..isAntiAlias = true;

    // Vertex colors modulate the texture, which is how the diffuse shading
    // and specular band reach the pixels.
    canvas.drawVertices(vertices, ui.BlendMode.modulate, paint);

    // Backside pass: the part of the mesh that has folded over shows the
    // reverse of the sheet. It is drawn from the same texture but darkened
    // and desaturated, matching how real paper reads from behind.
    final backData = mesh.deform(
      size: size,
      edge: state.edge,
      progress: state.progress,
      dragVector: state.dragVector,
      origin: state.origin,
      backside: true,
    );
    final backVertices = mesh.buildVertices(backData);
    final backPaint = Paint()
      ..shader = shader
      ..isAntiAlias = true
      ..colorFilter = _backsideFilter();
    canvas.drawVertices(backVertices, ui.BlendMode.modulate, backPaint);

    shader.dispose();
    vertices.dispose();
    backVertices.dispose();
  }

  /// Desaturating filter for the reverse of the sheet.
  ui.ColorFilter _backsideFilter() {
    final d = config.backsideDesaturation.clamp(0.0, 1.0);
    // Standard luminance-preserving saturation matrix, interpolated by d.
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final s = 1.0 - d;
    return ui.ColorFilter.matrix(<double>[
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

  /// Extrudes the fold line slightly so the sheet has visible thickness.
  void _paintThickness(Canvas canvas, PageCurlMeshData data) {
    if (config.paperThickness <= 0) return;
    final fold = mesh.foldEdge(data, state.edge);
    if (fold.getBounds().isEmpty) return;

    // A soft dark line along the ridge reads as the sheet's cut edge.
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = config.paperThickness
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF000000).withValues(alpha: 0.22)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 0.6);
    canvas.drawPath(fold, edgePaint);

    // A hairline highlight just inboard of it catches the light and sells the
    // idea that the edge has depth rather than being a drawn line.
    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(config.paperThickness * 0.5, 0.5)
      ..color = const Color(
        0xFFFFFFFF,
      ).withValues(alpha: 0.30 * config.lightingIntensity.clamp(0.0, 1.0));
    canvas.drawPath(fold.shift(const Offset(0, -0.7)), highlight);
  }

  /// Maps a page texture onto the widget's logical size. Textures are captured
  /// at device pixel ratio (times an oversample), so they need scaling down.
  ///
  /// [ui.ImageShader] wants a raw column-major 4x4, not a `Matrix4`.
  Float64List _imageMatrix(ui.Image image, Size size) {
    final sx = size.width / image.width;
    final sy = size.height / image.height;
    return Float64List.fromList(<double>[
      sx, 0, 0, 0, //
      0, sy, 0, 0, //
      0, 0, 1, 0, //
      0, 0, 0, 1, //
    ]);
  }

  void _drawImageFitted(Canvas canvas, ui.Image image, Size size) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Offset.zero & size;
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.high,
    );
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

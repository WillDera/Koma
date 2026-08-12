import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'page_curl_config.dart';

/// One deformed vertex grid, ready to hand to `Canvas.drawVertices`.
///
/// Buffers are allocated once per [PageCurlMesh] and rewritten in place each
/// frame, so a drag produces no per-frame allocation.
class PageCurlMeshData {
  /// Deformed positions, xy interleaved.
  final Float32List positions;

  /// Source texture coordinates, xy interleaved. Constant across frames.
  final Float32List texCoords;

  /// Per-vertex shading, applied as a modulation color.
  final Int32List colors;

  /// Restrained paper tint used for triangles facing away from the viewer.
  final Int32List backsideColors;

  /// Triangle indices. Constant across frames.
  final Uint16List indices;

  /// Front/back triangle lists share geometry. Hidden triangles are degenerate,
  /// which keeps these buffers fixed-size and allocation-free across frames.
  final Uint16List frontIndices;
  final Uint16List backIndices;

  /// Vertices whose texture coords fall on the still-flat part of the sheet.
  /// The renderer clips to this to avoid double-drawing the curled region.
  int flatVertexCount;

  /// Greatest lift above the under-page in logical pixels this frame.
  double maxDepth;

  PageCurlMeshData({
    required this.positions,
    required this.texCoords,
    required this.colors,
    required this.backsideColors,
    required this.indices,
    required this.frontIndices,
    required this.backIndices,
    required this.flatVertexCount,
    required this.maxDepth,
  });
}

/// Physics-based mesh deformation for a single sheet.
///
/// The sheet is a subdivided grid. Each vertex is projected onto an invisible
/// cylinder whose axis is perpendicular to the drag direction and positioned
/// under the finger. Points before the tangent line stay flat; points past it
/// wrap around the cylinder, and once they pass the far side they lift off and
/// travel back over the sheet as the visible curl.
///
/// The cylinder tapers toward a cone when the drag has a vertical component,
/// which is what makes a corner drag peel diagonally instead of rolling as a
/// rigid tube.
class PageCurlMesh {
  PageCurlConfig _config;
  Size _size = Size.zero;

  late Float32List _positions;
  late Float32List _texCoords;
  late Int32List _colors;
  late Int32List _backsideColors;
  late Uint16List _indices;
  late Uint16List _frontIndices;
  late Uint16List _backIndices;
  late PageCurlMeshData _data;

  int _cols = 0;
  int _rows = 0;
  bool _staticDirty = true;

  /// Scratch buffers reused per frame so deformation allocates nothing.
  late Float32List _vertexDepth;

  PageCurlMesh(this._config);

  Size get size => _size;

  set config(PageCurlConfig value) {
    if (value.meshResolutionX != _config.meshResolutionX ||
        value.meshResolutionY != _config.meshResolutionY) {
      _staticDirty = true;
    }
    _config = value;
  }

  void _ensureBuffers(Size size) {
    final cols = _config.meshResolutionX;
    final rows = _config.meshResolutionY;
    if (!_staticDirty && cols == _cols && rows == _rows && size == _size) {
      return;
    }
    _cols = cols;
    _rows = rows;
    _size = size;

    final vCount = (cols + 1) * (rows + 1);
    _positions = Float32List(vCount * 2);
    _texCoords = Float32List(vCount * 2);
    _colors = Int32List(vCount);
    _backsideColors = Int32List(vCount);
    _vertexDepth = Float32List(vCount);

    // Texture coordinates are fixed to the undeformed grid.
    var t = 0;
    for (var row = 0; row <= rows; row++) {
      final v = row / rows * size.height;
      for (var col = 0; col <= cols; col++) {
        final u = col / cols * size.width;
        _texCoords[t] = u;
        _texCoords[t + 1] = v;
        t += 2;
      }
    }

    // Two triangles per quad, wound consistently.
    final quadCount = cols * rows;
    _indices = Uint16List(quadCount * 6);
    _frontIndices = Uint16List(quadCount * 6);
    _backIndices = Uint16List(quadCount * 6);
    var i = 0;
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final tl = row * (cols + 1) + col;
        final tr = tl + 1;
        final bl = tl + (cols + 1);
        final br = bl + 1;
        _indices[i++] = tl;
        _indices[i++] = bl;
        _indices[i++] = tr;
        _indices[i++] = tr;
        _indices[i++] = bl;
        _indices[i++] = br;
      }
    }
    _data = PageCurlMeshData(
      positions: _positions,
      texCoords: _texCoords,
      colors: _colors,
      backsideColors: _backsideColors,
      indices: _indices,
      frontIndices: _frontIndices,
      backIndices: _backIndices,
      flatVertexCount: 0,
      maxDepth: 0,
    );
    _staticDirty = false;
  }

  /// Deforms the sheet for a curl originating at [edge] with the fold driven
  /// to [progress] (0 = flat, 1 = fully turned).
  ///
  /// [dragVector] is the finger's offset from its start point and supplies the
  /// curl's direction; [origin] is where on the vertical axis the drag began,
  /// which sets the cone apex for diagonal peels.
  ///
  PageCurlMeshData deform({
    required Size size,
    required CurlEdge edge,
    required double progress,
    required Offset dragVector,
    required double origin,
    bool backside = false,
  }) {
    _ensureBuffers(size);

    final w = size.width;
    final h = size.height;
    final p = progress.clamp(0.0, 1.0);

    // The fold sweeps from the originating edge across to the far side.
    // travel is how far the fold line has advanced, in page units.
    // Curl radius tightens as the turn completes, floored so it never creases.
    final baseRadius = _config.curlRadiusFactor * w;
    final tighten = 1.0 - (1.0 - _config.minCurlRadiusFactor) * p;
    final stiffened =
        tighten + (1.0 - tighten) * _config.curlStiffness.clamp(0.0, 1.0);
    final radius = math.max(baseRadius * stiffened, 1.0);

    // Extra late travel carries the whole sheet beyond the spine at p=1. The
    // smooth p² term has zero slope at rest, so grabbing/reversing never pops.
    final travel = p * w + p * p * math.pi * radius * 0.72;

    // Vertical component of the drag tilts the fold line. Clamped so a wild
    // diagonal can't invert the geometry.
    final currentY = (origin + dragVector.dy).clamp(0.0, h);
    final originBias = h == 0 ? 0.0 : (origin / h - 0.5) * 2.0;
    final fingerBias = h == 0 ? 0.0 : (currentY / h - 0.5) * 2.0;
    final dragTilt = dragVector.dy / (h == 0 ? 1 : h);
    final tilt = (dragTilt * 0.72 + (fingerBias - originBias) * 0.28).clamp(
      -0.72,
      0.72,
    );

    // Cone apex: with no vertical drag the fold is a straight cylinder; with
    // one, the fold pivots about the drag origin so the far corner lags.
    final apex = origin.clamp(0.0, h);

    final fromLeft = edge == CurlEdge.left;
    final light = _config.lightDirection;
    final lightLen = math.max(
      math.sqrt(light.dx * light.dx + light.dy * light.dy),
      1e-6,
    );
    final lx = light.dx / lightLen;
    final ly = light.dy / lightLen;

    var flatCount = 0;
    var maxDepth = 0.0;
    var vi = 0;
    var ci = 0;

    for (var row = 0; row <= _rows; row++) {
      final y = row / _rows * h;
      // Distance from the cone apex scales how far this row's fold has moved.
      final apexDelta = h == 0 ? 0.0 : (y - apex) / h;
      // A gently curved fold axis is more paper-like than a rigid diagonal.
      // Rows near the grabbed corner lead; the opposite edge lags.
      final bow =
          (1.0 - apexDelta.abs().clamp(0.0, 1.0)) * tilt.abs() * radius * 0.16;
      final rowTravel = travel * (1.0 + tilt * apexDelta * 0.34) + bow;
      final rowRadius = math.max(
        radius * (1.0 + tilt * apexDelta * 0.24),
        baseRadius * _config.minCurlRadiusFactor * 0.72,
      );

      for (var col = 0; col <= _cols; col++) {
        final x = col / _cols * w;

        // Distance from this vertex to the fold line, measured along the
        // curl axis and oriented so positive is "not yet reached".
        final double alongAxis = fromLeft ? x : (w - x);
        final d = alongAxis - rowTravel;

        double outX;
        double outY;
        double depth;
        double shade;

        if (d >= 0) {
          // Flat region: the sheet has not curled here yet.
          outX = x;
          outY = y;
          depth = 0.0;
          shade = 1.0;
          flatCount++;
        } else {
          // Wrapped region: arc length -d around a cylinder of the given
          // radius. theta is how far around the tube this point has gone.
          final theta = (-d) / rowRadius;

          if (theta <= math.pi) {
            // Still on the tube. Project to the cylinder cross-section.
            final localX = rowRadius * math.sin(theta);
            final lift = rowRadius * (1.0 - math.cos(theta));
            final axisPos = rowTravel - localX;
            outX = fromLeft ? axisPos : (w - axisPos);
            outY = y;
            depth = lift;
            // Diffuse term from the surface normal's axis component.
            final nx = math.cos(theta) * (fromLeft ? 1.0 : -1.0);
            final ny = math.sin(theta);
            shade = _diffuse(nx, ny, lx, ly);
          } else {
            // Past the tube's far side: the sheet has lifted off and now lies
            // back over itself, flattening as it goes.
            final overshoot = theta - math.pi;
            final flatBack = overshoot * rowRadius;
            final axisPos = rowTravel + flatBack;
            outX = fromLeft ? axisPos : (w - axisPos);
            outY = y;
            // The free part relaxes gradually instead of becoming a perfectly
            // flat elevated flap immediately after half a revolution.
            final relaxation =
                overshoot * 0.45 / (1.0 + (overshoot * 0.45).abs());
            depth = 2.0 * rowRadius * (1.0 - 0.08 * relaxation);
            shade = _diffuse(-1.0 * (fromLeft ? 1.0 : -1.0), 0.0, lx, ly);
          }

          // Perspective foreshortening: lifted points pull toward the page
          // centre proportionally to height, which reads as depth.
          final focal = _config.perspective * w;
          final scale = focal / (focal + depth);
          outX = w * 0.5 + (outX - w * 0.5) * scale;
          outY = h * 0.5 + (outY - h * 0.5) * scale;
        }

        _positions[vi] = outX;
        _positions[vi + 1] = outY;
        _vertexDepth[ci] = depth;
        maxDepth = math.max(maxDepth, depth);

        // Specular: a narrow band that rides the steepest part of the fold.
        if (d < 0 && _config.specularIntensity > 0) {
          final theta = (-d) / rowRadius;
          final band = math.exp(-math.pow(theta - math.pi * 0.42, 2) * 8.5);
          shade += band * _config.specularIntensity * 0.42;
        }

        _colors[ci] = _shadeToColor(shade, false);
        _backsideColors[ci] = _shadeToColor(
          shade * (1.0 - _config.backsideDarkening),
          true,
        );

        vi += 2;
        ci++;
      }
    }

    // Classify each quad once from its average lift and local x tangent. Both
    // render passes then reuse this geometry instead of deforming twice.
    for (var row = 0; row < _rows; row++) {
      for (var col = 0; col < _cols; col++) {
        final tl = row * (_cols + 1) + col;
        final tr = tl + 1;
        final bl = tl + (_cols + 1);
        final br = bl + 1;
        final base = (row * _cols + col) * 6;
        final dxTop = _positions[tr * 2] - _positions[tl * 2];
        final dxBottom = _positions[br * 2] - _positions[bl * 2];
        final facesFront = dxTop + dxBottom >= 0;
        final target = facesFront ? _frontIndices : _backIndices;
        final hidden = facesFront ? _backIndices : _frontIndices;
        target[base] = tl;
        target[base + 1] = bl;
        target[base + 2] = tr;
        target[base + 3] = tr;
        target[base + 4] = bl;
        target[base + 5] = br;
        for (var n = 0; n < 6; n++) {
          hidden[base + n] = 0;
        }
      }
    }

    _data
      ..flatVertexCount = flatCount
      ..maxDepth = maxDepth;
    return _data;
  }

  double _diffuse(double nx, double ny, double lx, double ly) {
    final intensity = _config.lightingIntensity.clamp(0.0, 1.0);
    if (intensity == 0) return 1.0;
    // Half-Lambert keeps the unlit side readable rather than crushing to black.
    final ndotl = (nx * lx + ny * ly);
    final wrapped = 0.5 + 0.5 * ndotl;
    // Paper is broadly diffuse; keep the tonal swing restrained so printed
    // content remains legible and the fold does not look metallic.
    return 1.0 - intensity * 0.48 * (1.0 - wrapped);
  }

  /// Packs a scalar shade into a vertex color. Desaturation on the backside is
  /// approximated by lifting the channels toward luminance.
  int _shadeToColor(double shade, bool backside) {
    final s = shade.clamp(0.0, 2.0);
    var v = (255.0 * math.min(s, 1.0)).round();
    // Values above 1 are specular overshoot; fold them into a lighter tint.
    if (s > 1.0) {
      v = (255.0 * (1.0 + (s - 1.0) * 0.35)).clamp(0.0, 255.0).round();
    }
    if (!backside || _config.backsideDesaturation <= 0) {
      return 0xFF000000 | (v << 16) | (v << 8) | v;
    }
    // Cool the reverse slightly — real paper backs read marginally blue-grey.
    final warm = (v * (1.0 - _config.backsideDesaturation * 0.06))
        .clamp(0.0, 255.0)
        .round();
    return 0xFF000000 | (warm << 16) | (warm << 8) | v;
  }

  /// Builds the `ui.Vertices` object for a deformed mesh.
  ///
  /// [ui.Vertices.raw] copies into engine-side buffers, so the scratch
  /// buffers stay reusable after this returns.
  ui.Vertices buildVertices(PageCurlMeshData data, {bool backside = false}) {
    return ui.Vertices.raw(
      ui.VertexMode.triangles,
      data.positions,
      textureCoordinates: data.texCoords,
      colors: backside ? data.backsideColors : data.colors,
      indices: backside ? data.backIndices : data.frontIndices,
    );
  }

  /// Outline of the curled sheet, used to clip the shadow it casts and to
  /// mask the page underneath.
  Path silhouette(PageCurlMeshData data) {
    final path = Path();
    final cols = _cols;
    final rows = _rows;
    if (cols == 0 || rows == 0) return path;

    Offset at(int row, int col) {
      final idx = (row * (cols + 1) + col) * 2;
      return Offset(data.positions[idx], data.positions[idx + 1]);
    }

    path.moveTo(at(0, 0).dx, at(0, 0).dy);
    for (var col = 1; col <= cols; col++) {
      final o = at(0, col);
      path.lineTo(o.dx, o.dy);
    }
    for (var row = 1; row <= rows; row++) {
      final o = at(row, cols);
      path.lineTo(o.dx, o.dy);
    }
    for (var col = cols - 1; col >= 0; col--) {
      final o = at(rows, col);
      path.lineTo(o.dx, o.dy);
    }
    for (var row = rows - 1; row >= 0; row--) {
      final o = at(row, 0);
      path.lineTo(o.dx, o.dy);
    }
    path.close();
    return path;
  }

  /// The fold line — the ridge where the sheet leaves the flat plane. Used to
  /// draw simulated paper thickness.
  Path foldEdge(PageCurlMeshData data, CurlEdge edge) {
    final path = Path();
    final cols = _cols;
    final rows = _rows;
    if (cols == 0 || rows == 0) return path;

    // Walk each row and find where it crosses from flat into curled.
    var started = false;
    for (var row = 0; row <= rows; row++) {
      var crossing = -1;
      for (var scan = 0; scan <= cols; scan++) {
        final col = edge == CurlEdge.left ? cols - scan : scan;
        final idx = row * (cols + 1) + col;
        if (_vertexDepth[idx] > 0.01) {
          crossing = col;
          break;
        }
      }
      if (crossing < 0) continue;
      final idx = (row * (cols + 1) + crossing) * 2;
      final o = Offset(data.positions[idx], data.positions[idx + 1]);
      if (!started) {
        path.moveTo(o.dx, o.dy);
        started = true;
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    return path;
  }
}

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

  /// Triangle indices. Constant across frames.
  final Uint16List indices;

  /// Vertices whose texture coords fall on the still-flat part of the sheet.
  /// The renderer clips to this to avoid double-drawing the curled region.
  final int flatVertexCount;

  PageCurlMeshData({
    required this.positions,
    required this.texCoords,
    required this.colors,
    required this.indices,
    required this.flatVertexCount,
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
  late Uint16List _indices;

  int _cols = 0;
  int _rows = 0;
  bool _staticDirty = true;

  /// Scratch buffers reused per frame so deformation allocates nothing.
  late Float32List _vertexDepth;

  PageCurlMesh(this._config);

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
    _staticDirty = false;
  }

  /// Deforms the sheet for a curl originating at [edge] with the fold driven
  /// to [progress] (0 = flat, 1 = fully turned).
  ///
  /// [dragVector] is the finger's offset from its start point and supplies the
  /// curl's direction; [origin] is where on the vertical axis the drag began,
  /// which sets the cone apex for diagonal peels.
  ///
  /// Set [backside] to shade for the reverse of the sheet.
  PageCurlMeshData deform({
    required Size size,
    required CurlEdge edge,
    required double progress,
    required Offset dragVector,
    required double origin,
    required bool backside,
  }) {
    _ensureBuffers(size);

    final w = size.width;
    final h = size.height;
    final p = progress.clamp(0.0, 1.0);

    // The fold sweeps from the originating edge across to the far side.
    // travel is how far the fold line has advanced, in page units.
    final travel = p * w;

    // Curl radius tightens as the turn completes, floored so it never creases.
    final baseRadius = _config.curlRadiusFactor * w;
    final tighten = 1.0 - (1.0 - _config.minCurlRadiusFactor) * p;
    final stiffened =
        tighten + (1.0 - tighten) * _config.curlStiffness.clamp(0.0, 1.0);
    final radius = math.max(baseRadius * stiffened, 1.0);

    // Vertical component of the drag tilts the fold line. Clamped so a wild
    // diagonal can't invert the geometry.
    final tilt = (dragVector.dy / (h == 0 ? 1 : h)).clamp(-0.85, 0.85);

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
    var vi = 0;
    var ci = 0;

    for (var row = 0; row <= _rows; row++) {
      final y = row / _rows * h;
      // Distance from the cone apex scales how far this row's fold has moved.
      final apexDelta = h == 0 ? 0.0 : (y - apex) / h;
      final rowTravel = travel * (1.0 + tilt * apexDelta);

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
          final theta = (-d) / radius;

          if (theta <= math.pi) {
            // Still on the tube. Project to the cylinder cross-section.
            final localX = radius * math.sin(theta);
            final lift = radius * (1.0 - math.cos(theta));
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
            final flatBack = overshoot * radius;
            final axisPos = rowTravel + flatBack;
            outX = fromLeft ? axisPos : (w - axisPos);
            outY = y;
            depth = 2.0 * radius;
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

        // Specular: a narrow band that rides the steepest part of the fold.
        if (d < 0 && _config.specularIntensity > 0) {
          final theta = (-d) / radius;
          final band = math.exp(-math.pow(theta - math.pi * 0.5, 2) * 6.0);
          shade += band * _config.specularIntensity;
        }

        if (backside) {
          shade *= (1.0 - _config.backsideDarkening);
        }
        _colors[ci] = _shadeToColor(shade, backside);

        vi += 2;
        ci++;
      }
    }

    return PageCurlMeshData(
      positions: _positions,
      texCoords: _texCoords,
      colors: _colors,
      indices: _indices,
      flatVertexCount: flatCount,
    );
  }

  double _diffuse(double nx, double ny, double lx, double ly) {
    final intensity = _config.lightingIntensity.clamp(0.0, 1.0);
    if (intensity == 0) return 1.0;
    // Half-Lambert keeps the unlit side readable rather than crushing to black.
    final ndotl = (nx * lx + ny * ly);
    final wrapped = 0.5 + 0.5 * ndotl;
    return 1.0 - intensity * (1.0 - wrapped);
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
  ui.Vertices buildVertices(PageCurlMeshData data) {
    return ui.Vertices.raw(
      ui.VertexMode.triangles,
      data.positions,
      textureCoordinates: data.texCoords,
      colors: data.colors,
      indices: data.indices,
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
      for (var col = 0; col <= cols; col++) {
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

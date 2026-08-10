import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koma/widgets/page_curl/page_curl.dart';

void main() {
  const size = Size(400, 700);

  PageCurlMeshData deform(
    PageCurlMesh mesh, {
    double progress = 0.5,
    CurlEdge edge = CurlEdge.right,
    Offset drag = const Offset(-120, 0),
    double origin = 350,
    Size pageSize = size,
    bool backside = false,
  }) {
    return mesh.deform(
      size: pageSize,
      edge: edge,
      progress: progress,
      dragVector: drag,
      origin: origin,
      backside: backside,
    );
  }

  group('PageCurlMesh', () {
    test('emits a well-formed grid for the configured resolution', () {
      const config = PageCurlConfig(meshResolutionX: 12, meshResolutionY: 6);
      final mesh = PageCurlMesh(config);
      final data = deform(mesh);

      const vertexCount = (12 + 1) * (6 + 1);
      expect(data.positions.length, vertexCount * 2);
      expect(data.texCoords.length, vertexCount * 2);
      expect(data.colors.length, vertexCount);
      // Two triangles per quad, three indices each.
      expect(data.indices.length, 12 * 6 * 6);
    });

    test('every index is inside the vertex buffer', () {
      final mesh = PageCurlMesh(
        const PageCurlConfig(meshResolutionX: 9, meshResolutionY: 5),
      );
      final data = deform(mesh);
      final vertexCount = data.positions.length ~/ 2;
      for (final i in data.indices) {
        expect(i, lessThan(vertexCount));
      }
    });

    test('at rest the mesh is undeformed', () {
      final mesh = PageCurlMesh(const PageCurlConfig());
      final data = deform(mesh, progress: 0.0);
      // Flat everywhere: positions must equal texture coordinates.
      for (var i = 0; i < data.positions.length; i++) {
        expect(data.positions[i], closeTo(data.texCoords[i], 0.001));
      }
    });

    test('progress advances the fold across the page', () {
      final mesh = PageCurlMesh(const PageCurlConfig());
      final early = deform(mesh, progress: 0.2).flatVertexCount;
      final mid = deform(mesh, progress: 0.5).flatVertexCount;
      final late_ = deform(mesh, progress: 0.85).flatVertexCount;
      // More of the sheet has curled, so fewer vertices remain flat.
      expect(mid, lessThan(early));
      expect(late_, lessThan(mid));
    });

    test('produces no NaN or infinite coordinates across the full sweep', () {
      final mesh = PageCurlMesh(const PageCurlConfig());
      for (var step = 0; step <= 40; step++) {
        final p = step / 40;
        for (final edge in CurlEdge.values) {
          final data = deform(mesh, progress: p, edge: edge);
          for (final v in data.positions) {
            expect(
              v.isFinite,
              isTrue,
              reason: 'non-finite position at progress=$p edge=$edge',
            );
          }
        }
      }
    });

    test('handles a degenerate zero size without emitting NaN', () {
      final mesh = PageCurlMesh(const PageCurlConfig());
      final data = deform(mesh, pageSize: Size.zero, progress: 0.5);
      for (final v in data.positions) {
        expect(v.isFinite, isTrue);
      }
    });

    test('curl stays within sane bounds for extreme diagonal drags', () {
      final mesh = PageCurlMesh(const PageCurlConfig());
      // A drag far past the page corner must not invert the geometry.
      final data = deform(
        mesh,
        progress: 0.9,
        drag: const Offset(-900, 1400),
        origin: 0,
      );
      for (final v in data.positions) {
        expect(v.isFinite, isTrue);
      }
    });

    test('both edges curl toward the page interior', () {
      final mesh = PageCurlMesh(const PageCurlConfig());

      double meanX(PageCurlMeshData d) {
        var sum = 0.0;
        for (var i = 0; i < d.positions.length; i += 2) {
          sum += d.positions[i];
        }
        return sum / (d.positions.length / 2);
      }

      final flat = meanX(deform(mesh, progress: 0.0));
      final fromRight = meanX(
        deform(mesh, progress: 0.6, edge: CurlEdge.right),
      );
      final fromLeft = meanX(
        deform(
          mesh,
          progress: 0.6,
          edge: CurlEdge.left,
          drag: const Offset(120, 0),
        ),
      );

      // Curling from the right drags mass leftward, and vice versa.
      expect(fromRight, lessThan(flat));
      expect(fromLeft, greaterThan(flat));
    });

    test('reuses its buffers so a drag allocates nothing', () {
      final mesh = PageCurlMesh(const PageCurlConfig());
      final a = deform(mesh, progress: 0.3);
      final b = deform(mesh, progress: 0.6);
      // Identity, not equality — the same backing store is rewritten in place.
      expect(identical(a.positions, b.positions), isTrue);
      expect(identical(a.indices, b.indices), isTrue);
      expect(identical(a.colors, b.colors), isTrue);
    });

    test('rebuilds buffers when mesh resolution changes', () {
      final mesh = PageCurlMesh(const PageCurlConfig(meshResolutionX: 8));
      final before = deform(mesh);
      mesh.config = const PageCurlConfig(meshResolutionX: 16);
      final after = deform(mesh);
      expect(after.positions.length, greaterThan(before.positions.length));
    });

    test('backside shading differs without a second deformation', () {
      final mesh = PageCurlMesh(const PageCurlConfig(backsideDarkening: 0.3));
      final data = deform(mesh, progress: 0.6);
      expect(data.colors, isNot(equals(data.backsideColors)));
      expect(data.frontIndices.length, data.backIndices.length);
      expect(
        data.backIndices.any((index) => index != 0),
        isTrue,
        reason: 'part of a mid-turn sheet should expose its reverse',
      );
    });

    test('vertical drag position changes the fold continuously', () {
      final mesh = PageCurlMesh(const PageCurlConfig());
      final straight = List<double>.from(
        deform(
          mesh,
          progress: 0.5,
          drag: const Offset(-180, 0),
          origin: 350,
        ).positions,
      );
      final diagonal = List<double>.from(
        deform(
          mesh,
          progress: 0.5,
          drag: const Offset(-180, 160),
          origin: 100,
        ).positions,
      );
      expect(diagonal, isNot(equals(straight)));
      for (final value in diagonal) {
        expect(value.isFinite, isTrue);
      }
    });

    test('silhouette is a closed non-empty outline once curling', () {
      final mesh = PageCurlMesh(const PageCurlConfig());
      final data = deform(mesh, progress: 0.5);
      final path = mesh.silhouette(data);
      expect(path.getBounds().isEmpty, isFalse);
    });
  });

  group('PageCurlPhysics', () {
    const config = PageCurlConfig(
      completionThreshold: 0.32,
      flingVelocityThreshold: 700,
    );
    final physics = PageCurlPhysics(config);

    test('completes past the threshold, cancels below it', () {
      expect(physics.resolve(progress: 0.4, velocity: 0), CurlRelease.complete);
      expect(physics.resolve(progress: 0.1, velocity: 0), CurlRelease.cancel);
    });

    test('a fast flick completes even below the threshold', () {
      expect(
        physics.resolve(progress: 0.05, velocity: 1200),
        CurlRelease.complete,
      );
    });

    test('a reverse flick cancels even past the threshold', () {
      expect(
        physics.resolve(progress: 0.9, velocity: -1200),
        CurlRelease.cancel,
      );
    });

    test('moderate release velocity projects the settle both ways', () {
      expect(
        physics.resolve(progress: 0.25, velocity: 300, pageWidth: 400),
        CurlRelease.complete,
      );
      expect(
        physics.resolve(progress: 0.38, velocity: -300, pageWidth: 400),
        CurlRelease.cancel,
      );
    });

    test('catching and reversing a curl is continuous', () {
      final caught = physics.progressForDragFrom(
        from: 0.58,
        dragDistance: 0,
        pageWidth: 400,
      );
      final reversed = physics.progressForDragFrom(
        from: 0.58,
        dragDistance: -20,
        pageWidth: 400,
      );
      expect(caught, 0.58);
      expect(reversed, lessThan(caught));
      expect((caught - reversed).abs(), lessThan(0.06));
    });

    test('drag progress is clamped to 0..1', () {
      expect(physics.progressForDrag(dragDistance: -50, pageWidth: 400), 0.0);
      expect(physics.progressForDrag(dragDistance: 9999, pageWidth: 400), 1.0);
    });

    test('drag progress tracks the finger monotonically', () {
      double p(double d) =>
          physics.progressForDrag(dragDistance: d, pageWidth: 400);
      expect(p(100), greaterThan(p(50)));
      expect(p(200), greaterThan(p(100)));
    });

    test('zero page width does not divide by zero', () {
      final v = physics.progressForDrag(dragDistance: 100, pageWidth: 0);
      expect(v.isFinite, isTrue);
      expect(v, 0.0);
    });

    test('spring settles toward its target', () {
      final sim = physics.buildSpring(
        from: 0.5,
        to: 1.0,
        velocity: 0,
        pageWidth: 400,
      );
      // Far enough out that any sane spring has arrived.
      expect(sim.x(4.0), closeTo(1.0, 0.02));
      expect(sim.isDone(4.0), isTrue);
    });
  });
}

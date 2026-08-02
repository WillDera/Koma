import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koma/widgets/page_curl/page_curl.dart';

/// Interaction-level tests for [PageCurlView]: the arena behaviour that unit
/// tests over the mesh and physics cannot reach.
void main() {
  /// Hosts a curl whose pages are built by [page], and records page changes.
  /// Pages exist for indices 0..9 so both ends of the range are reachable.
  Future<({List<int> changes, Rect rect})> host(
    WidgetTester tester, {
    required Widget Function(int index) page,
    int initialIndex = 0,
  }) async {
    final changes = <int>[];
    var index = initialIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PageCurlView(
              pageIndex: index,
              onPageChanged: (i) {
                changes.add(i);
                setState(() => index = i);
              },
              pageBuilder: (context, i) => (i < 0 || i > 9) ? null : page(i),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (changes: changes, rect: tester.getRect(find.byType(PageCurlView)));
  }

  Widget plainPage(int i) =>
      Container(color: Colors.white, child: Text('page $i'));

  /// A page whose content is selectable, like real EPUB text. Selectable text
  /// installs its own tap recognizer deeper in the tree than the curl's, so it
  /// wins the gesture arena — the case that regressed tap-to-turn.
  Widget selectablePage(int i) => Container(
    color: Colors.white,
    child: SelectableText('page $i ${"word " * 400}'),
  );

  Future<void> tapEdge(
    WidgetTester tester,
    Rect rect, {
    required bool forward,
  }) async {
    await tester.tapAt(
      Offset(forward ? rect.right - 20 : rect.left + 20, rect.center.dy),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tapping the right edge turns forward', (tester) async {
    final h = await host(tester, page: plainPage);
    await tapEdge(tester, h.rect, forward: true);
    expect(h.changes, [1]);
  });

  testWidgets('tapping the left edge turns backward', (tester) async {
    final h = await host(tester, page: plainPage, initialIndex: 5);
    await tapEdge(tester, h.rect, forward: false);
    expect(h.changes, [4]);
  });

  testWidgets('edge taps turn over selectable page content', (tester) async {
    // Regression: selectable text won the arena, so the curl's tap recognizer
    // never fired and pages could not be turned by tapping at all.
    final h = await host(tester, page: selectablePage);
    await tapEdge(tester, h.rect, forward: true);
    expect(h.changes, [1], reason: 'selectable text must not swallow the tap');
  });

  testWidgets('a tap in the middle of the page does not turn', (tester) async {
    final h = await host(tester, page: plainPage);
    await tester.tapAt(h.rect.center);
    await tester.pumpAndSettle();
    expect(h.changes, isEmpty);
  });

  testWidgets('no turn past either end of the range', (tester) async {
    final back = await host(tester, page: plainPage);
    await tapEdge(tester, back.rect, forward: false);
    expect(back.changes, isEmpty, reason: 'nothing before page 0');

    final fwd = await host(tester, page: plainPage, initialIndex: 9);
    await tapEdge(tester, fwd.rect, forward: true);
    expect(fwd.changes, isEmpty, reason: 'nothing after the last page');
  });

  testWidgets('dragging from the right edge turns forward', (tester) async {
    final h = await host(tester, page: selectablePage);
    // A decisive leftward drag: past the completion threshold, so it settles
    // forward rather than springing back.
    await tester.dragFrom(
      Offset(h.rect.right - 20, h.rect.center.dy),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(h.changes, [1]);
  });

  testWidgets('a short drag springs back without turning', (tester) async {
    final h = await host(tester, page: plainPage);
    await tester.dragFrom(
      Offset(h.rect.right - 20, h.rect.center.dy),
      const Offset(-12, 0),
    );
    await tester.pumpAndSettle();
    expect(h.changes, isEmpty);
  });

  testWidgets('text remains selectable away from the edges', (tester) async {
    // The tap path must not cost selection: the curl only claims edge strips.
    final h = await host(tester, page: selectablePage);
    expect(find.byType(SelectableText), findsWidgets);
    await tester.tapAt(h.rect.center);
    await tester.pumpAndSettle();
    expect(h.changes, isEmpty);
  });

  testWidgets('the curl actually paints while a turn is in flight', (
    tester,
  ) async {
    // Regression: the painter took a *snapshot* of the controller's state at
    // construction, but it repaints off the controller without the widget tree
    // rebuilding. The snapshot stayed frozen at the progress the turn began
    // with — 0 — so every frame failed the progress guard and drew nothing.
    // The curl was invisible and the offstage swap exposed the raw neighbour.
    final changes = <int>[];
    var index = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PageCurlView(
              pageIndex: index,
              onPageChanged: (i) {
                changes.add(i);
                setState(() => index = i);
              },
              pageBuilder: (context, i) =>
                  (i < 0 || i > 9) ? null : plainPage(i),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(PageCurlView));

    // Start a drag and hold it, so the turn is mid-flight when we inspect.
    final gesture = await tester.startGesture(
      Offset(rect.right - 20, rect.center.dy),
    );
    await gesture.moveBy(const Offset(-150, 0));
    await tester.pump();

    final painter = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(PageCurlView),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter;
    expect(
      painter,
      isA<PageCurlRenderer>(),
      reason: 'the curl should install its renderer during a turn',
    );

    final renderer = painter! as PageCurlRenderer;
    // The renderer must observe live, advancing state — not the zero-progress
    // snapshot it was constructed with.
    expect(renderer.state.active, isTrue);
    expect(
      renderer.state.progress,
      greaterThan(0.0),
      reason: 'a held drag must report advancing progress to the painter',
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('holding an edge without moving never reveals the neighbour', (
    tester,
  ) async {
    // Regression: a turn becomes active on pointer-down, at progress 0. The
    // painter used to skip progress <= 0.0005, so while the finger rested on an
    // edge the outgoing page was offstage and *nothing* painted over it — the
    // incoming page underneath showed through as a text glitch before the swipe
    // even started.
    final changes = <int>[];
    var index = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PageCurlView(
              pageIndex: index,
              onPageChanged: (i) {
                changes.add(i);
                setState(() => index = i);
              },
              pageBuilder: (context, i) =>
                  (i < 0 || i > 9) ? null : plainPage(i),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(PageCurlView));

    // Press and hold on the right edge strip. No movement at all.
    final gesture = await tester.startGesture(
      Offset(rect.right - 20, rect.center.dy),
    );
    await tester.pump();

    // The renderer is installed and active even at progress 0.
    final painter = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(PageCurlView),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter;
    expect(
      painter,
      isA<PageCurlRenderer>(),
      reason: 'a press must engage the turn immediately',
    );
    final renderer = painter! as PageCurlRenderer;
    expect(renderer.state.active, isTrue);
    expect(
      renderer.state.progress,
      0.0,
      reason: 'the hold is at the very start of the turn',
    );

    // The point of the fix: at progress 0 the painter must still cover the
    // page. An empty picture still reports nonzero bytes, so assert on actual
    // pixels instead — the page is white, so the centre must be opaque white,
    // not the transparency an early return would leave.
    final recorder = ui.PictureRecorder();
    renderer.paint(ui.Canvas(recorder), rect.size);
    final picture = recorder.endRecording();
    addTearDown(picture.dispose);
    final w = rect.width.round();
    final h = rect.height.round();
    final data = await tester.runAsync(() async {
      final img = picture.toImageSync(w, h);
      final d = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      return d;
    });
    expect(data, isNotNull, reason: 'the painted picture should rasterize');
    final bytes = data!.buffer.asUint8List();
    final centreAlpha = bytes[(h ~/ 2) * w * 4 + (w ~/ 2) * 4 + 3];
    expect(
      centreAlpha,
      255,
      reason: 'a held edge must paint the outgoing page, not nothing',
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });
}

import 'package:flutter/material.dart';
import 'package:real_page_flip/real_page_flip.dart';

/// Full-viewport page curl powered by [PageFlipWidget] (single-page mode).
///
/// Replaces the old clip-path strip with a physics-based paper fold: the sheet
/// peels with crease shadows and a moving flap, matching a real page turn.
class CurlPageTurner extends StatefulWidget {
  const CurlPageTurner({
    super.key,
    required this.pageCount,
    required this.pageIndex,
    required this.pageSize,
    required this.pageBuilder,
    required this.captureKey,
    required this.sheetColor,
    this.onPageChanged,
    this.onChapterEdge,
  });

  final int pageCount;
  final int pageIndex;
  final Size pageSize;
  final Widget Function(BuildContext context, int pageIndex) pageBuilder;
  final Object captureKey;
  final Color sheetColor;
  final ValueChanged<int>? onPageChanged;

  /// Fired when a committed swipe would leave the chapter.
  final void Function({required bool forward})? onChapterEdge;

  @override
  State<CurlPageTurner> createState() => _CurlPageTurnerState();
}

class _CurlPageTurnerState extends State<CurlPageTurner> {
  static const _edgeCommitDx = 96.0;
  static const _edgeFlingVx = 900.0;

  late final PageFlipController _flip = PageFlipController();
  int _reportedIndex = 0;
  Offset? _down;
  Duration? _downAt;

  @override
  void initState() {
    super.initState();
    _reportedIndex = widget.pageIndex.clamp(0, _maxIndex);
  }

  @override
  void didUpdateWidget(covariant CurlPageTurner old) {
    super.didUpdateWidget(old);
    if (old.captureKey != widget.captureKey) {
      _reportedIndex = widget.pageIndex.clamp(0, _maxIndex);
    } else if (widget.pageIndex != _reportedIndex) {
      _reportedIndex = widget.pageIndex.clamp(0, _maxIndex);
    }
  }

  int get _maxIndex =>
      widget.pageCount <= 0 ? 0 : widget.pageCount - 1;

  void _onPageChanged(int index) {
    if (index == _reportedIndex) return;
    _reportedIndex = index;
    widget.onPageChanged?.call(index);
  }

  void _pointerDown(PointerDownEvent e) {
    _down = e.localPosition;
    _downAt = e.timeStamp;
  }

  void _pointerUp(PointerUpEvent e) {
    final start = _down;
    final startedAt = _downAt;
    _down = null;
    _downAt = null;
    if (start == null || startedAt == null) return;
    if (widget.pageCount <= 0) return;

    final dx = e.localPosition.dx - start.dx;
    final dy = e.localPosition.dy - start.dy;
    if (dx.abs() < 64 || dx.abs() < dy.abs()) return;

    final dtMs = (e.timeStamp - startedAt).inMilliseconds;
    final vx = dtMs > 0 ? dx / dtMs * 1000 : 0.0;
    final forward = dx < 0;
    final committed =
        dx.abs() >= _edgeCommitDx || vx.abs() >= _edgeFlingVx;
    if (!committed) return;

    // [PageFlipWidget] ignores turns past the first/last page — promote those
    // edge swipes to chapter navigation instead.
    if (forward && _reportedIndex >= _maxIndex) {
      widget.onChapterEdge?.call(forward: true);
    } else if (!forward && _reportedIndex <= 0) {
      widget.onChapterEdge?.call(forward: false);
    }
  }

  void _pointerCancel(PointerCancelEvent e) {
    _down = null;
    _downAt = null;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.pageSize;
    final count = widget.pageCount.clamp(0, 100000);
    final initial = widget.pageIndex.clamp(0, count == 0 ? 0 : count - 1);

    return ColoredBox(
      color: widget.sheetColor,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _pointerDown,
          onPointerUp: _pointerUp,
          onPointerCancel: _pointerCancel,
          child: count == 0
              ? const SizedBox.expand()
              : PageFlipWidget(
                  key: ValueKey(widget.captureKey),
                  controller: _flip,
                  itemCount: count,
                  initialIndex: initial,
                  contentRevision: widget.captureKey,
                  spreadMode: PageFlipSpreadMode.single,
                  config: PageFlipConfig(
                    // Must match scaffold / page fill exactly — any opacity or
                    // dimmed verso wash reads as a different paper shade.
                    backgroundColor: widget.sheetColor,
                    paperOpacity: 1.0,
                    thinPaperStrength: 0.0,
                    endRevealStrength: 0.0,
                    singlePageBackContentOpacity: 0.0,
                    flapBackStrength: 0.0,
                    enableSound: false,
                    enableHaptics: true,
                    skipTapAnimation: false,
                    cutoffForward: 0.32,
                    cutoffPrevious: 0.32,
                    sensitivity: 0.55,
                    performanceProfile: DevicePerformanceProfile.high,
                    snapshotPerformanceProfile: DevicePerformanceProfile.high,
                    snapshotRefreshPolicy:
                        PageFlipSnapshotRefreshPolicy.whenDirty,
                    maxSnapshotPixelRatio: 2.5,
                    enableSinglePageSettleReveal: true,
                  ),
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) =>
                      widget.pageBuilder(context, index),
                ),
        ),
      ),
    );
  }
}

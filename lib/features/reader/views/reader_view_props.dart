import 'package:flutter/material.dart';

import '../models/page_data.dart';
import '../reader_settings_sheet.dart';

/// Immutable bundle of everything the extracted reader view widgets need
/// from the parent [MangaReaderScreen] state: the page list, the active
/// [ReaderSettings], the shared controllers, and the callback surface.
///
/// This is the seam that let the 1200-LOC reader split into per-mode view
/// widgets (mangayomi's image_view_paged / image_view_webtoon shape)
/// without the views reaching back into private State fields.
class ReaderViewProps {
  final List<PageData> pages;
  final ReaderSettings settings;

  /// Notifier holding the current flat page index (drives page indicator).
  final ValueNotifier<int> currentPage;

  /// Per-page pinch-zoom controllers (paged mode only).
  final List<TransformationController> zoomControllers;

  // ── Callbacks into the parent state ──────────────────────────────
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onGoToPage;
  final VoidCallback onToggleToolbar;
  final VoidCallback onLongPress;
  final ValueChanged<int> onRetryPage;

  const ReaderViewProps({
    required this.pages,
    required this.settings,
    required this.currentPage,
    required this.zoomControllers,
    required this.onPageChanged,
    required this.onGoToPage,
    required this.onToggleToolbar,
    required this.onLongPress,
    required this.onRetryPage,
  });
}

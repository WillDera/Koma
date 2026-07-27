import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../reader_settings_sheet.dart';
import '../widgets/transition_view_vertical.dart';
import 'reader_page_image.dart';
import 'reader_view_props.dart';

/// Continuous vertical reader (webtoon / long-strip / long-strip-with-gaps).
///
/// Mirrors mangayomi's `image_view_webtoon.dart`: a
/// [ScrollablePositionedList] with a large `minCacheExtent` for seamless
/// prefetch, rendering [TransitionViewVertical] for chapter separators and
/// [ReaderPageImage] for real pages. Scroll position + chapter-boundary
/// detection stay in the parent state via the shared [ItemPositionsListener].
class MangaImageViewWebtoon extends StatelessWidget {
  final ReaderViewProps props;
  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;

  const MangaImageViewWebtoon({
    super.key,
    required this.props,
    required this.itemScrollController,
    required this.itemPositionsListener,
  });

  @override
  Widget build(BuildContext context) {
    final pages = props.pages;
    final isWebtoon = props.settings.readingMode == ReadingMode.webtoon;

    return ScrollablePositionedList.builder(
      itemScrollController: itemScrollController,
      itemPositionsListener: itemPositionsListener,
      scrollDirection: Axis.vertical,
      itemCount: pages.length + 1, // +1 for bottom spacer
      minCacheExtent: 2000,
      itemBuilder: (context, index) {
        if (index >= pages.length) {
          return const SizedBox(height: 200); // bottom spacer
        }
        final page = pages[index];
        if (page.isTransitionPage) {
          return TransitionViewVertical(
            data: page,
            readerMode: props.settings.readingMode,
          );
        }
        return ReaderPageImage(page: page, webtoon: isWebtoon);
      },
    );
  }
}

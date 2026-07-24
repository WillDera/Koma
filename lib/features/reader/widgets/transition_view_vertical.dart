import 'package:flutter/material.dart';
import '../models/page_data.dart';
import 'chapter_transition_page.dart';
import '../reader_settings_sheet.dart';

/// Wraps a [ChapterTransitionPage] for continuous scroll modes (webtoon, long strip).
/// Takes up the full viewport height so the user scrolls through it naturally,
/// directly ported from mangayomi's TransitionViewVertical.
class TransitionViewVertical extends StatelessWidget {
  final PageData data;
  final ReadingMode readerMode;

  const TransitionViewVertical({
    super.key,
    required this.data,
    required this.readerMode,
  });

  @override
  Widget build(BuildContext context) {
    if (!data.isTransitionPage) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: ChapterTransitionPage(
        currentChapter: data.chapter!,
        nextChapter: data.nextChapter,
        mangaName: data.mangaName ?? '',
        readerMode: readerMode,
      ),
    );
  }
}

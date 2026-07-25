import 'package:flutter/material.dart';
import '../models/page_data.dart';
import 'chapter_transition_page.dart';
import '../reader_settings_sheet.dart';

/// Wraps a [ChapterTransitionPage] for paged modes (defaultL2R, rightToLeft).
/// Unlike the vertical wrapper, this does not constrain height — it fills the
/// page view naturally, directly ported from mangayomi's TransitionViewPaged.
class TransitionViewPaged extends StatelessWidget {
  final PageData data;
  final ReadingMode readerMode;

  const TransitionViewPaged({
    super.key,
    required this.data,
    required this.readerMode,
  });

  @override
  Widget build(BuildContext context) {
    if (!data.isTransitionPage) {
      return const SizedBox.shrink();
    }

    return ChapterTransitionPage(
      currentChapter: data.chapter!,
      nextChapter: data.nextChapter,
      mangaName: data.mangaName ?? '',
      readerMode: readerMode,
    );
  }
}

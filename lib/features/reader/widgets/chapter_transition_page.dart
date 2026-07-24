import 'package:flutter/material.dart';
import '../../../core/models/manga_chapter.dart';
import '../reader_settings_sheet.dart';

/// "End of Chapter" separator widget — shown between chapters in the
/// scrollable page list, directly ported from mangayomi's ChapterTransitionPage.
///
/// Displays the completed chapter, an arrow, and the next chapter info,
/// enabling the user to seamlessly scroll past the chapter boundary.
class ChapterTransitionPage extends StatelessWidget {
  final MangaChapter currentChapter;
  final MangaChapter? nextChapter;
  final String mangaName;
  final ReadingMode readerMode;

  const ChapterTransitionPage({
    super.key,
    required this.currentChapter,
    required this.nextChapter,
    required this.mangaName,
    required this.readerMode,
  });

  bool get _isVertical =>
      readerMode == ReadingMode.webtoon ||
      readerMode == ReadingMode.longStrip ||
      readerMode == ReadingMode.longStripWithGaps;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _isVertical
          ? _buildVerticalScaffold(context)
          : _buildHorizontalScaffold(context),
    );
  }

  Widget _buildVerticalScaffold(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth.clamp(100.0, 480.0),
                maxHeight:
                    constraints.maxHeight.clamp(100.0, double.infinity),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: _buildVerticalLayout(context),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalScaffold(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Center(
      child: SizedBox(
        width: screenWidth,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _buildHorizontalLayout(context),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalLayout(BuildContext context) {
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            'End of Chapter',
            style:
                Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildChapterCard(
            context,
            label: 'Chapter completed',
            name: currentChapter.name,
            isPrimary: false,
          ),
          const SizedBox(height: 16),
          Icon(
            nextChapter != null
                ? Icons.keyboard_arrow_down
                : Icons.check_circle_outline,
            size: 32,
            color: nextChapter != null
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withAlpha(153),
          ),
          const SizedBox(height: 16),
          if (nextChapter != null) ...[
            _buildChapterCard(
              context,
              label: 'Next chapter',
              name: nextChapter!.name,
              isPrimary: true,
            ),
            const SizedBox(height: 20),
            Text(
              'Continue to next chapter',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha(153),
                  ),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            _buildEndOfMangaCard(context),
            const SizedBox(height: 20),
            Text(
              'Return to the list of chapters',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha(153),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHorizontalLayout(BuildContext context) {
    final theme = Theme.of(context);

    final Widget currentCard = _buildChapterCard(
      context,
      label: 'Chapter completed',
      name: currentChapter.name,
      isPrimary: false,
    );

    final Widget arrowIcon = Icon(
      nextChapter != null
          ? (readerMode == ReadingMode.rightToLeft
              ? Icons.keyboard_arrow_left
              : Icons.keyboard_arrow_right)
          : Icons.check_circle_outline,
      size: 36,
      color: nextChapter != null
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurface.withAlpha(153),
    );

    final Widget nextCard = nextChapter != null
        ? _buildChapterCard(
            context,
            label: 'Next chapter',
            name: nextChapter!.name,
            isPrimary: true,
          )
        : _buildEndOfMangaCard(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.auto_stories_outlined,
          size: 40,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'End of Chapter',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: readerMode == ReadingMode.rightToLeft
                    ? [
                        Expanded(child: nextCard),
                        const SizedBox(width: 12),
                        Center(child: arrowIcon),
                        const SizedBox(width: 12),
                        Expanded(child: currentCard),
                      ]
                    : [
                        Expanded(child: currentCard),
                        const SizedBox(width: 12),
                        Center(child: arrowIcon),
                        const SizedBox(width: 12),
                        Expanded(child: nextCard),
                      ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          nextChapter != null
              ? 'Continue to next chapter'
              : 'Return to the list of chapters',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(153),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildChapterCard(
    BuildContext context, {
    required String label,
    required String name,
    required bool isPrimary,
  }) {
    final theme = Theme.of(context);
    final bgColor = isPrimary
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surface;
    final borderColor = isPrimary
        ? theme.colorScheme.primary.withAlpha(77)
        : theme.colorScheme.outline.withAlpha(51);
    final labelColor = isPrimary
        ? theme.colorScheme.onPrimaryContainer.withAlpha(204)
        : theme.colorScheme.onSurface.withAlpha(179);
    final nameColor =
        isPrimary ? theme.colorScheme.onPrimaryContainer : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(color: labelColor),
            maxLines: 2,
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: nameColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEndOfMangaCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(77),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotatedBox(
            quarterTurns: _isVertical ? 1 : 0,
            child: Icon(
              Icons.last_page,
              size: 24,
              color: theme.colorScheme.onSurface.withAlpha(179),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No next chapter',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withAlpha(204),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'You have finished reading',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(153),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

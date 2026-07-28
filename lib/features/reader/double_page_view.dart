import 'package:flutter/material.dart';
import 'models/page_data.dart';
import 'reader_settings_sheet.dart';


class DoublePageView extends StatefulWidget {
  final List<PageData> pages;
  final int initialPage;
  final ReaderSettings settings;
  final ValueChanged<int> onPageChanged;
  final VoidCallback? onSettingsTap;

  const DoublePageView({
    super.key,
    required this.pages,
    required this.initialPage,
    required this.settings,
    required this.onPageChanged,
    this.onSettingsTap,
  });

  @override
  State<DoublePageView> createState() => _DoublePageViewState();
}

class _DoublePageViewState extends State<DoublePageView> {
  late final PageController _pageController;
  int _currentSpread = 0;

  @override
  void initState() {
    super.initState();
    _currentSpread = widget.initialPage ~/ 2;
    _pageController = PageController(initialPage: _currentSpread);
  }

  @override
  void didUpdateWidget(covariant DoublePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pages != widget.pages) {
      _currentSpread = 0;
      _pageController.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int get _spreadCount {
    if (widget.pages.isEmpty) return 0;
    return (widget.pages.length / 2).ceil();
  }

  Widget _buildSpread(BuildContext context, int spreadIndex) {
    final pages = widget.pages;
    final leftIndex = spreadIndex * 2;
    final rightIndex = leftIndex + 1;

    Widget? left;
    Widget? right;

    if (leftIndex < pages.length) {
      left = _buildPage(context, pages[leftIndex], leftIndex);
    }
    if (rightIndex < pages.length) {
      right = _buildPage(context, pages[rightIndex], rightIndex);
    }

    if (left == null && right != null) {
      return Row(
        children: [
          const Spacer(flex: 2),
          Expanded(flex: 5, child: right),
          const Spacer(flex: 2),
        ],
      );
    }
    if (left != null && right == null) {
      return Row(
        children: [
          const Spacer(flex: 2),
          Expanded(flex: 5, child: left),
          const Spacer(flex: 2),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: left ?? const SizedBox()),
        Container(width: 1, color: Theme.of(context).dividerColor),
        Expanded(child: right ?? const SizedBox()),
      ],
    );
  }

  Widget _buildPage(BuildContext context, PageData page, int flatIndex) {
    if (page.isTransitionPage) {
      return _TransitionPage(
        pageData: page,
        onOpenSettings: widget.onSettingsTap,
      );
    }
    return _MangaImagePage(
      pageData: page,
      settings: widget.settings,
      index: flatIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return PageView.builder(
      controller: _pageController,
      onPageChanged: (i) {
        _currentSpread = i;
        widget.onPageChanged(i * 2);
      },
      itemCount: _spreadCount,
      itemBuilder: (_, i) => _buildSpread(context, i),
    );
  }
}

class _MangaImagePage extends StatelessWidget {
  final PageData pageData;
  final ReaderSettings settings;
  final int index;

  const _MangaImagePage({
    required this.pageData,
    required this.settings,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Image.network(
          pageData.imageUrl,
          headers: pageData.headers,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          },
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
        ),
      ),
    );
  }
}

class _TransitionPage extends StatelessWidget {
  final PageData pageData;
  final VoidCallback? onOpenSettings;

  const _TransitionPage({
    required this.pageData,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = pageData.isLastChapter;
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isLast ? 'End of Manga' : 'Chapter Complete',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            if (isLast)
              TextButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_rounded),
                label: const Text('Reader Settings'),
              )
            else
              Text(
                'Next: ${pageData.nextChapter?.name ?? ""}',
                style: const TextStyle(color: Colors.white70),
              ),
          ],
        ),
      ),
    );
  }
}

import '../models/page_data.dart';

class PageNavigationService {
  final List<PageData> pages;
  final int totalPages;
  int currentIndex = 0;

  PageNavigationService(this.pages) : totalPages = pages.length;

  PageData? pageAt(int index) {
    if (index < 0 || index >= totalPages) return null;
    return pages[index];
  }

  PageData? get currentPage => pageAt(currentIndex);

  int advance({bool bookMode = false}) {
    final step = bookMode ? 2 : 1;
    return _clamp(currentIndex + step);
  }

  int retreat({bool bookMode = false}) {
    final step = bookMode ? 2 : 1;
    return _clamp(currentIndex - step);
  }

  void jumpTo(int index) {
    currentIndex = _clamp(index);
  }

  double chapterProgress() {
    if (totalPages == 0) return 0.0;
    return currentIndex / (totalPages - 1);
  }

  bool isOnTransitionPage() {
    final p = currentPage;
    return p != null && p.isTransitionPage;
  }

  bool shouldAdvanceChapter(double velocity) {
    final page = currentPage;
    if (page == null) return false;
    if (page.isTransitionPage) return velocity > 600;
    if (currentIndex < totalPages - 1) return false;
    return velocity > 1500;
  }

  bool shouldRetreatChapter(double velocity) {
    return currentIndex == 0 && velocity < -1500;
  }

  int dragTarget(double delta, {bool bookMode = false}) {
    final step = bookMode ? 2 : 1;
    final direction = delta > 0 ? -1 : 1;
    return _clamp(currentIndex + (direction * step));
  }

  int _clamp(int value) => value.clamp(0, totalPages - 1);
}

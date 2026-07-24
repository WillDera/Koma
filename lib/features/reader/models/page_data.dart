import '../../../core/models/manga_page.dart';
import '../../../core/models/manga_chapter.dart';

/// Unified page data representing any item in the reader's flat page list.
///
/// Every page — whether it's a real chapter image or an "End of Chapter"
/// separator — is stored as a [PageData]. This is the same pattern as
/// mangayomi's UChapDataPreload where every item carries a chapter reference
/// and an isTransitionPage flag, enabling seamless multi-chapter scrolling.
class PageData {
  /// The original [MangaPage] data, or null for transition pages.
  final MangaPage? mangaPage;

  /// Which chapter this page belongs to. null for transition pages
  /// (they bridge two chapters).
  final MangaChapter? chapter;

  /// Absolute index in the combined flat list.
  int pageIndex;

  /// When true, this is an "End of Chapter" separator.
  final bool isTransitionPage;

  /// For transition pages: the next chapter to navigate into.
  final MangaChapter? nextChapter;

  /// For transition pages: display the manga name.
  final String? mangaName;

  /// When true, this is the last chapter separator (end of manga).
  final bool isLastChapter;

  /// Cached image file path for downloaded pages.
  String? localPath;

  PageData({
    this.mangaPage,
    this.chapter,
    this.pageIndex = 0,
    this.isTransitionPage = false,
    this.nextChapter,
    this.mangaName,
    this.isLastChapter = false,
    this.localPath,
  });

  /// Constructs a transition page (the "End of Chapter" view).
  factory PageData.transition({
    required MangaChapter currentChapter,
    required MangaChapter? nextChapter,
    required String mangaName,
    required int pageIndex,
    bool isLastChapter = false,
  }) {
    return PageData(
      chapter: currentChapter,
      pageIndex: pageIndex,
      isTransitionPage: true,
      nextChapter: nextChapter,
      mangaName: mangaName,
      isLastChapter: isLastChapter,
    );
  }

  /// Constructs a regular page from a [MangaPage] and its owning chapter.
  factory PageData.page({
    required MangaPage mangaPage,
    required MangaChapter chapter,
    int pageIndex = 0,
  }) {
    return PageData(
      mangaPage: mangaPage,
      chapter: chapter,
      pageIndex: pageIndex,
    );
  }

  int get index => mangaPage?.index ?? 0;
  String get imageUrl => mangaPage?.imageUrl ?? '';
  Map<String, String>? get headers => mangaPage?.headers;
}

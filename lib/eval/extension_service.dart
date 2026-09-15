import 'models/m_source.dart';
import 'models/m_manga.dart';
import 'models/m_chapter.dart';
import 'models/m_pages.dart';
import 'models/manga_browse_page.dart';
import 'models/filter_list.dart';
import 'models/source_preference.dart';

abstract class ExtensionService {
  String get type;

  Future<MangaBrowsePage> getPopular(int page, {required MSource source});

  Future<MangaBrowsePage> getLatestUpdates(int page, {required MSource source});

  Future<FilterList> getFilterList(MSource source);

  Future<MangaBrowsePage> search(
    MSource source,
    int page,
    String query, {
    FilterList? filters,
  });

  Future<MManga?> getDetail(
    MSource source,
    String url, {
    String? memo,
    String? title,
  });

  Future<List<MChapter>> getChapterList(
    MSource source,
    String url, {
    String? memo,
    String? title,
  });

  /// Combined detail + chapter fetch. Default runs sequentially so sources
  /// that share one network path (or forbid concurrent refresh) do not race.
  /// Implementations may override for a single round-trip (e.g. Keiyoushi).
  Future<({MManga? manga, List<MChapter> chapters})> getMangaDetail(
    MSource source,
    String url, {
    String? memo,
    String? title,
  }) async {
    final manga = await getDetail(source, url, memo: memo, title: title);
    final chapters =
        await getChapterList(source, url, memo: memo, title: title);
    return (manga: manga, chapters: chapters);
  }

  Future<List<MPages>> getPageList(MSource source, MChapter chapter);

  /// Fetch cleaned HTML for a novel chapter (mangayomi/LNReader ABI).
  Future<String> getHtmlContent(
    MSource source, {
    required String name,
    required String url,
  });

  /// Sanitize novel chapter HTML for the reader.
  Future<String> cleanHtmlContent(MSource source, String html);

  Future<List<SourcePreference>> getSourcePreferences(MSource source);

  Future<void> saveSourcePreference(MSource source, SourcePreference pref);
}

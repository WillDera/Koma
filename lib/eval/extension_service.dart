import 'models/m_source.dart';
import 'models/m_manga.dart';
import 'models/m_chapter.dart';
import 'models/m_pages.dart';
import 'models/filter_list.dart';
import 'models/source_preference.dart';

abstract class ExtensionService {
  String get type;

  Future<List<MManga>> getPopular(int page, {required MSource source});

  Future<List<MManga>> getLatestUpdates(int page, {required MSource source});

  Future<List<MManga>> search(
    MSource source,
    int page,
    String query, {
    FilterList? filters,
  });

  Future<MManga?> getDetail(MSource source, String url);

  Future<List<MChapter>> getChapterList(MSource source, String url);

  /// Combined detail + chapter fetch. Default calls [getDetail] then
  /// [getChapterList]; implementations may override for efficiency
  /// (e.g. Keiyoushi's combined method-channel call).
  Future<({MManga? manga, List<MChapter> chapters})> getMangaDetail(
    MSource source,
    String url,
  ) async {
    final results = await Future.wait([
      getDetail(source, url),
      getChapterList(source, url),
    ]);
    return (manga: results[0] as MManga?, chapters: results[1] as List<MChapter>);
  }

  Future<List<MPages>> getPageList(MSource source, MChapter chapter);

  Future<List<SourcePreference>> getSourcePreferences(MSource source);

  Future<void> saveSourcePreference(MSource source, SourcePreference pref);
}

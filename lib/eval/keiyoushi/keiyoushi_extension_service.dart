import '../extension_service.dart';
import '../models/m_source.dart';
import '../models/m_manga.dart';
import '../models/m_chapter.dart';
import '../models/m_pages.dart';
import '../models/filter_list.dart';
import '../models/source_preference.dart';
import '../../core/services/keiyoushi_service.dart';

class KeiyoushiExtensionService implements ExtensionService {
  final KeiyoushiService _keiyoushi;

  KeiyoushiExtensionService(this._keiyoushi);

  @override
  String get type => 'mihon';

  @override
  Future<List<MManga>> getPopular(int page, {required MSource source}) async {
    final result = await _keiyoushi.getPopularManga(
      sourceId: source.sourceId,
      page: page,
    );
    return result.mangas.map((m) => MManga.fromMap(m)).toList();
  }

  @override
  Future<List<MManga>> getLatestUpdates(
    int page, {
    required MSource source,
  }) async {
    final result = await _keiyoushi.getLatestUpdates(
      sourceId: source.sourceId,
      page: page,
    );
    return result.mangas.map((m) => MManga.fromMap(m)).toList();
  }

  @override
  Future<FilterList> getFilterList(MSource source) async {
    final raw = await _keiyoushi.getFilters(sourceId: source.sourceId);
    return FilterList.fromJson(raw);
  }

  @override
  Future<List<MManga>> search(
    MSource source,
    int page,
    String query, {
    FilterList? filters,
  }) async {
    final result = await _keiyoushi.searchManga(
      sourceId: source.sourceId,
      query: query,
      page: page,
      filters: filters?.toJson(),
    );
    return result.mangas.map((m) => MManga.fromMap(m)).toList();
  }

  @override
  Future<MManga?> getDetail(MSource source, String url) async {
    final result = await _keiyoushi.getMangaDetails(
      sourceId: source.sourceId,
      url: url,
    );
    if (result.isEmpty) return null;
    return MManga.fromMap(result);
  }

  @override
  Future<List<MChapter>> getChapterList(MSource source, String url) async {
    final result = await _keiyoushi.getChapterList(
      sourceId: source.sourceId,
      url: url,
    );
    return result.map((c) => MChapter.fromMap(c)).toList();
  }

  @override
  Future<({MManga? manga, List<MChapter> chapters})> getMangaDetail(
    MSource source,
    String url,
  ) async {
    final result = await _keiyoushi.getMangaUpdate(
      sourceId: source.sourceId,
      url: url,
    );
    final details = result.details;
    final manga = details.isNotEmpty ? MManga.fromMap(details) : null;
    final chapters = result.chapters.map((c) => MChapter.fromMap(c)).toList();
    return (manga: manga, chapters: chapters);
  }

  @override
  Future<List<MPages>> getPageList(MSource source, MChapter chapter) async {
    final result = await _keiyoushi.getPageList(
      sourceId: source.sourceId,
      url: chapter.url,
    );
    return [MPages.fromList(result)];
  }

  @override
  Future<List<SourcePreference>> getSourcePreferences(MSource source) async {
    return [];
  }

  @override
  Future<void> saveSourcePreference(
    MSource source,
    SourcePreference pref,
  ) async {}
}

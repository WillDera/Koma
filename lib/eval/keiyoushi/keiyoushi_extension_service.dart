import '../extension_service.dart';
import '../models/m_source.dart';
import '../models/m_manga.dart';
import '../models/m_chapter.dart';
import '../models/m_pages.dart';
import '../models/manga_browse_page.dart';
import '../models/filter_list.dart';
import '../models/source_preference.dart';
import '../../core/services/keiyoushi_service.dart';

class KeiyoushiExtensionService implements ExtensionService {
  final KeiyoushiService _keiyoushi;

  KeiyoushiExtensionService(this._keiyoushi);

  @override
  String get type => 'mihon';

  MangaBrowsePage _toBrowsePage(
    ({List<Map<String, dynamic>> mangas, bool hasNextPage}) result,
  ) {
    return MangaBrowsePage(
      list: result.mangas.map((m) => MManga.fromMap(m)).toList(),
      hasNextPage: result.hasNextPage,
    );
  }

  @override
  Future<MangaBrowsePage> getPopular(
    int page, {
    required MSource source,
  }) async {
    final result = await _keiyoushi.getPopularManga(
      sourceId: source.sourceId,
      page: page,
    );
    return _toBrowsePage(result);
  }

  @override
  Future<MangaBrowsePage> getLatestUpdates(
    int page, {
    required MSource source,
  }) async {
    final result = await _keiyoushi.getLatestUpdates(
      sourceId: source.sourceId,
      page: page,
    );
    return _toBrowsePage(result);
  }

  @override
  Future<FilterList> getFilterList(MSource source) async {
    final raw = await _keiyoushi.getFilters(sourceId: source.sourceId);
    return FilterList.fromJson(raw);
  }

  @override
  Future<MangaBrowsePage> search(
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
    return _toBrowsePage(result);
  }

  @override
  Future<MManga?> getDetail(
    MSource source,
    String url, {
    String? memo,
    String? title,
  }) async {
    final result = await _keiyoushi.getMangaDetails(
      sourceId: source.sourceId,
      url: url,
      memo: memo,
      title: title,
    );
    if (result.isEmpty) return null;
    return MManga.fromMap(result);
  }

  @override
  Future<List<MChapter>> getChapterList(
    MSource source,
    String url, {
    String? memo,
    String? title,
  }) async {
    final result = await _keiyoushi.getChapterList(
      sourceId: source.sourceId,
      url: url,
      memo: memo,
      title: title,
    );
    return result.map((c) => MChapter.fromMap(c)).toList();
  }

  @override
  Future<({MManga? manga, List<MChapter> chapters})> getMangaDetail(
    MSource source,
    String url, {
    String? memo,
    String? title,
  }) async {
    final result = await _keiyoushi.getMangaUpdate(
      sourceId: source.sourceId,
      url: url,
      memo: memo,
      title: title,
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
      memo: chapter.memo,
    );
    // Dalvik returns `imageUrl`; normalize to MPage.`url`.
    final normalized = <Map<String, dynamic>>[
      for (var i = 0; i < result.length; i++)
        {
          'index': result[i]['index'] ?? i,
          'url': (result[i]['url'] as String?) ??
              (result[i]['imageUrl'] as String?) ??
              '',
          if (result[i]['headers'] != null) 'headers': result[i]['headers'],
        },
    ];
    return [MPages.fromList(normalized)];
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

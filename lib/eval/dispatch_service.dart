import 'extension_service.dart';
import 'models/m_source.dart';
import 'models/m_manga.dart';
import 'models/m_chapter.dart';
import 'models/m_pages.dart';
import 'models/filter_list.dart';
import 'models/source_preference.dart';
import 'keiyoushi/keiyoushi_extension_service.dart';
import 'javascript/js_extension_service.dart';
import '../core/services/keiyoushi_service.dart';

class ExtensionDispatchService implements ExtensionService {
  final KeiyoushiExtensionService _keiyoushi;
  final JsExtensionService _js;

  ExtensionDispatchService({
    required KeiyoushiService keiyoushiService,
    JsExtensionService? jsExtensionService,
  }) : _keiyoushi = KeiyoushiExtensionService(keiyoushiService),
       _js = jsExtensionService ?? JsExtensionService();

  @override
  String get type => 'dispatch';

  ExtensionService _resolve(MSource source) {
    return source.isJs ? _js : _keiyoushi;
  }

  @override
  Future<FilterList> getFilterList(MSource source) =>
      _resolve(source).getFilterList(source);

  @override
  Future<List<MManga>> getPopular(int page, {required MSource source}) =>
      _resolve(source).getPopular(page, source: source);

  @override
  Future<List<MManga>> getLatestUpdates(int page, {required MSource source}) =>
      _resolve(source).getLatestUpdates(page, source: source);

  @override
  Future<List<MManga>> search(
    MSource source,
    int page,
    String query, {
    FilterList? filters,
  }) => _resolve(source).search(source, page, query, filters: filters);

  @override
  Future<MManga?> getDetail(MSource source, String url) =>
      _resolve(source).getDetail(source, url);

  @override
  Future<List<MChapter>> getChapterList(MSource source, String url) =>
      _resolve(source).getChapterList(source, url);

  @override
  Future<({MManga? manga, List<MChapter> chapters})> getMangaDetail(
    MSource source,
    String url,
  ) => _resolve(source).getMangaDetail(source, url);

  @override
  Future<List<MPages>> getPageList(MSource source, MChapter chapter) =>
      _resolve(source).getPageList(source, chapter);

  @override
  Future<List<SourcePreference>> getSourcePreferences(MSource source) =>
      _resolve(source).getSourcePreferences(source);

  @override
  Future<void> saveSourcePreference(MSource source, SourcePreference pref) =>
      _resolve(source).saveSourcePreference(source, pref);
}

import 'extension_service.dart';
import 'models/m_source.dart';
import 'models/m_manga.dart';
import 'models/m_chapter.dart';
import 'models/m_pages.dart';
import 'models/manga_browse_page.dart';
import 'models/filter_list.dart';
import 'models/source_preference.dart';
import 'keiyoushi/keiyoushi_extension_service.dart';
import 'javascript/js_extension_service.dart';
import 'dart/service.dart';
import '../core/services/keiyoushi_service.dart';

class ExtensionDispatchService implements ExtensionService {
  final KeiyoushiExtensionService _keiyoushi;
  final JsExtensionService _js;
  final DartExtensionService _dart;

  ExtensionDispatchService({
    required KeiyoushiService keiyoushiService,
    JsExtensionService? jsExtensionService,
    DartExtensionService? dartExtensionService,
  }) : _keiyoushi = KeiyoushiExtensionService(keiyoushiService),
       _js = jsExtensionService ?? JsExtensionService(),
       _dart = dartExtensionService ?? DartExtensionService();

  @override
  String get type => 'dispatch';

  ExtensionService _resolve(MSource source) {
    if (source.isDart) return _dart;
    if (source.isJs) return _js;
    return _keiyoushi;
  }

  @override
  Future<FilterList> getFilterList(MSource source) =>
      _resolve(source).getFilterList(source);

  @override
  Future<MangaBrowsePage> getPopular(int page, {required MSource source}) =>
      _resolve(source).getPopular(page, source: source);

  @override
  Future<MangaBrowsePage> getLatestUpdates(
    int page, {
    required MSource source,
  }) => _resolve(source).getLatestUpdates(page, source: source);

  @override
  Future<MangaBrowsePage> search(
    MSource source,
    int page,
    String query, {
    FilterList? filters,
  }) => _resolve(source).search(source, page, query, filters: filters);

  @override
  Future<MManga?> getDetail(
    MSource source,
    String url, {
    String? memo,
    String? title,
  }) =>
      _resolve(source).getDetail(source, url, memo: memo, title: title);

  @override
  Future<List<MChapter>> getChapterList(
    MSource source,
    String url, {
    String? memo,
    String? title,
  }) =>
      _resolve(source).getChapterList(source, url, memo: memo, title: title);

  @override
  Future<({MManga? manga, List<MChapter> chapters})> getMangaDetail(
    MSource source,
    String url, {
    String? memo,
    String? title,
  }) =>
      _resolve(source).getMangaDetail(source, url, memo: memo, title: title);

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

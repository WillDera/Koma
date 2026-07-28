import '../extension_service.dart';
import '../models/m_source.dart';
import '../models/m_manga.dart';
import '../models/m_chapter.dart';
import '../models/m_pages.dart';
import '../models/filter_list.dart';
import '../models/source_preference.dart';
import 'js_runtime.dart';

class JsExtensionService implements ExtensionService {
  final JsRuntime _runtime;

  JsExtensionService({JsRuntime? runtime}) : _runtime = runtime ?? JsRuntime();

  @override
  String get type => 'js';

  JsRuntime _ensureRuntime() {
    _runtime.init();
    return _runtime;
  }

  @override
  Future<List<MManga>> getPopular(int page, {required MSource source}) async {
    final rt = _ensureRuntime();
    final results = rt.evaluateMangaList(
      source.sourceCode ?? '',
      'source.getPopular($page)',
    );
    return results
        .map((r) => MManga(
              url: r['url'] as String? ?? '',
              title: r['title'] as String? ?? '',
              thumbnailUrl: r['thumbnail_url'] as String?,
              author: r['author'] as String?,
              artist: r['artist'] as String?,
              description: r['description'] as String?,
              status: r['status'] as int? ?? 0,
              genres: r['genre'] != null
                  ? (r['genre'] as String)
                      .split(',')
                      .map((g) => g.trim())
                      .toList()
                  : null,
            ))
        .toList();
  }

  @override
  Future<List<MManga>> getLatestUpdates(int page,
      {required MSource source}) async {
    final rt = _ensureRuntime();
    final results = rt.evaluateMangaList(
      source.sourceCode ?? '',
      'source.getLatestUpdates($page)',
    );
    return results
        .map((r) => MManga(
              url: r['url'] as String? ?? '',
              title: r['title'] as String? ?? '',
              thumbnailUrl: r['thumbnail_url'] as String?,
              author: r['author'] as String?,
              artist: r['artist'] as String?,
              description: r['description'] as String?,
              status: r['status'] as int? ?? 0,
              genres: r['genre'] != null
                  ? (r['genre'] as String)
                      .split(',')
                      .map((g) => g.trim())
                      .toList()
                  : null,
            ))
        .toList();
  }

  @override
  Future<List<MManga>> search(
    MSource source,
    int page,
    String query, {
    FilterList? filters,
  }) async {
    final rt = _ensureRuntime();
    final filtersJson = filters != null
        ? '[${filters.filters.map((f) => _jsStringify(f.toJson())).join(",")}]'
        : '[]';
    final results = rt.evaluateMangaList(
      source.sourceCode ?? '',
      'source.search("$query", $page, $filtersJson)',
    );
    return results
        .map((r) => MManga(
              url: r['url'] as String? ?? '',
              title: r['title'] as String? ?? '',
              thumbnailUrl: r['thumbnail_url'] as String?,
              author: r['author'] as String?,
              artist: r['artist'] as String?,
              description: r['description'] as String?,
              status: r['status'] as int? ?? 0,
              genres: r['genre'] != null
                  ? (r['genre'] as String)
                      .split(',')
                      .map((g) => g.trim())
                      .toList()
                  : null,
            ))
        .toList();
  }

  @override
  Future<MManga?> getDetail(MSource source, String url) async {
    final rt = _ensureRuntime();
    final result = rt.evaluateDetail(
      source.sourceCode ?? '',
      'source.getDetail("$url")',
    );
    if (result == null) return null;
    return MManga.fromJson(result);
  }

  @override
  Future<List<MChapter>> getChapterList(MSource source, String url) async {
    final rt = _ensureRuntime();
    final results = rt.evaluateList(
      source.sourceCode ?? '',
      'source.getChapterList("$url")',
    );
    return results
        .map((e) => MChapter.fromDynamic(e))
        .toList();
  }

  @override
  Future<({MManga? manga, List<MChapter> chapters})> getMangaDetail(
    MSource source,
    String url,
  ) async {
    final manga = await getDetail(source, url);
    final chapters = await getChapterList(source, url);
    return (manga: manga, chapters: chapters);
  }

  @override
  Future<List<MPages>> getPageList(MSource source, MChapter chapter) async {
    final rt = _ensureRuntime();
    final results = rt.evaluateList(
      source.sourceCode ?? '',
      'source.getPageList("${chapter.url}")',
    );
    return [MPages.fromJson(results)];
  }

  @override
  Future<List<SourcePreference>> getSourcePreferences(MSource source) async {
    final rt = _ensureRuntime();
    final results = rt.evaluateList(
      source.sourceCode ?? '',
      'source.getSourcePreferences()',
    );
    return results.map((e) => SourcePreference.fromDynamic(e)).toList();
  }

  @override
  Future<void> saveSourcePreference(MSource source, SourcePreference pref) async {
    final rt = _ensureRuntime();
    rt.evaluate(
      'source.saveSourcePreference("${pref.key}", ${_jsStringify(pref.defaultValue)})',
    );
  }

  String _jsStringify(dynamic value) {
    if (value == null) return 'null';
    if (value is String) {
      final escaped = value
          .replaceAll('\\', '\\\\')
          .replaceAll('"', '\\"')
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r')
          .replaceAll('\t', '\\t');
      return '"$escaped"';
    }
    if (value is num || value is bool) return value.toString();
    if (value is List) {
      return '[${value.map(_jsStringify).join(',')}]';
    }
    if (value is Map) {
      final entries = value.entries
          .map((e) => '"${e.key}": ${_jsStringify(e.value)}')
          .join(',');
      return '{$entries}';
    }
    return value.toString();
  }
}

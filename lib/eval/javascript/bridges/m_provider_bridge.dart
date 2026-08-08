import 'package:flutter_qjs/flutter_qjs.dart';

/// Builds mangayomi's MProvider stub with `get source()` returning [sourceJson]
/// plus `jsonStringify` for async extension calls.
String buildMProviderStub(String sourceJson) =>
    '''
class MProvider {
    get source() {
        return $sourceJson;
    }
    get supportsLatest() {
        throw new Error("supportsLatest not implemented");
    }
    getHeaders(url) {
        throw new Error("getHeaders not implemented");
    }
    async getPopular(page) {
        throw new Error("getPopular not implemented");
    }
    async getLatestUpdates(page) {
        throw new Error("getLatestUpdates not implemented");
    }
    async search(query, page, filters) {
        throw new Error("search not implemented");
    }
    async getDetail(url) {
        throw new Error("getDetail not implemented");
    }
    async getPageList() {
        throw new Error("getPageList not implemented");
    }
    async getChapterList(url) {
        throw new Error("getChapterList not implemented");
    }
    async getVideoList(url) {
        throw new Error("getVideoList not implemented");
    }
    async getHtmlContent(name, url) {
        throw new Error("getHtmlContent not implemented");
    }
    async cleanHtmlContent(html) {
        throw new Error("cleanHtmlContent not implemented");
    }
    getFilterList() {
        throw new Error("getFilterList not implemented");
    }
    getSourcePreferences() {
        throw new Error("getSourcePreferences not implemented");
    }
}
async function jsonStringify(fn) {
    return JSON.stringify(await fn());
}
''';

/// Injected at runtime bootstrap without a bound source; per-source init
/// in [JsExtensionService] redefines MProvider with real source JSON.
Future<void> injectMProvider(QuickJsRuntime2 engine) async {
  engine.evaluate(buildMProviderStub('{}'));
}

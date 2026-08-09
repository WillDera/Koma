import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/extension_repo.dart';
import '../models/extension_source.dart';
import '../repositories/repositories.dart';
import '../utils/language.dart';
import '../../eval/javascript/js_source_meta.dart';
import 'apk_signature_service.dart';
import 'extension_icon_cache.dart';
import 'keiyoushi_service.dart';
import 'trust_extension.dart';

export '../models/extension_source.dart' show SourceCodeLanguage;
export 'trust_extension.dart' show UntrustedExtensionException;
export 'apk_signature_service.dart' show ApkSigningInfo;

/// Thrown when catalog entry language is Dart-eval or otherwise unsupported.
/// Item 5 scope is Mihon APK + mangayomi JS only.
class UnsupportedExtensionLanguageException implements Exception {
  final String language;
  final String? name;

  const UnsupportedExtensionLanguageException(this.language, {this.name});

  @override
  String toString() {
    final label = name == null || name!.isEmpty ? '' : ' ($name)';
    return 'Unsupported extension language "$language"$label — '
        'Koma installs Mihon APKs and JavaScript sources only '
        '(Dart-eval / LNReader are out of scope).';
  }
}

class ExtensionIndexEntry {
  final String pkg;
  final String name;

  /// Mihon APK relative/absolute URL only. Never holds JS [sourceCodeUrl].
  final String apkUrl;

  /// Mangayomi native index `sourceCodeUrl` (JS/Dart script). Null for Mihon.
  final String? sourceCodeUrl;

  /// Catalog language: [SourceCodeLanguage.mihon], [SourceCodeLanguage.js],
  /// [SourceCodeLanguage.dart], or [SourceCodeLanguage.unsupported].
  final String sourceCodeLanguage;

  final String version;
  final String lang;
  final String contentWarning;
  final bool isNsfw;
  final String? baseUrl;
  final String? iconUrl;
  final String? apiUrl;
  final bool hasCloudflare;

  /// `manga` / `anime` / `novel`, or null when the index omitted itemType/isManga.
  final String? itemType;
  final List<Map<String, dynamic>> sources;

  const ExtensionIndexEntry({
    required this.pkg,
    required this.name,
    required this.apkUrl,
    this.sourceCodeUrl,
    this.sourceCodeLanguage = SourceCodeLanguage.mihon,
    required this.version,
    required this.lang,
    this.contentWarning = 'CONTENT_WARNING_SAFE',
    this.isNsfw = false,
    this.baseUrl,
    this.iconUrl,
    this.apiUrl,
    this.hasCloudflare = false,
    this.itemType,
    required this.sources,
  });

  bool get isJs => SourceCodeLanguage.isJs(sourceCodeLanguage);
  bool get isMihon => SourceCodeLanguage.isMihon(sourceCodeLanguage);
  bool get isDart => sourceCodeLanguage == SourceCodeLanguage.dart;

  String? get className {
    if (sources.isEmpty) return null;
    final c = sources.first['className'];
    if (c is String && c.isNotEmpty) return c;
    return null;
  }

  /// Map mangayomi `sourceCodeLanguage` (int index or string) → catalog token.
  /// Enum order: dart=0, javascript=1, mihon=2, lnreader=3.
  static String parseSourceCodeLanguage(dynamic raw) {
    if (raw is int) {
      switch (raw) {
        case 0:
          return SourceCodeLanguage.dart;
        case 1:
          return SourceCodeLanguage.js;
        case 2:
          return SourceCodeLanguage.mihon;
        default:
          return SourceCodeLanguage.unsupported;
      }
    }
    if (raw is String) {
      switch (raw.toLowerCase().trim()) {
        case 'js':
        case 'javascript':
          return SourceCodeLanguage.js;
        case 'dart':
          return SourceCodeLanguage.dart;
        case 'mihon':
          return SourceCodeLanguage.mihon;
        default:
          return SourceCodeLanguage.unsupported;
      }
    }
    // Mangayomi Source.fromJson defaults missing language to dart (index 0).
    return SourceCodeLanguage.dart;
  }

  /// Map mangayomi `itemType` / legacy `isManga` → `manga`/`anime`/`novel`.
  /// Returns null when neither field is present in the index JSON.
  static String? parseItemType(Map<String, dynamic> j) {
    if (!j.containsKey('itemType') && !j.containsKey('isManga')) return null;
    final raw = j['itemType'];
    if (raw is int && raw >= 0 && raw <= 2) {
      return const ['manga', 'anime', 'novel'][raw];
    }
    if (raw is String) {
      final s = raw.toLowerCase().trim();
      if (s == 'manga' || s == 'anime' || s == 'novel') return s;
      final n = int.tryParse(s);
      if (n != null && n >= 0 && n <= 2) {
        return const ['manga', 'anime', 'novel'][n];
      }
    }
    final isManga = j['isManga'];
    if (isManga == true) return 'manga';
    if (isManga == false) return 'anime';
    // itemType present but unusable — same default as Source.fromJson (0).
    return 'manga';
  }

  static bool _looksLikeMihon(Map<String, dynamic> j) {
    return j.containsKey('apk') ||
        j.containsKey('pkg') ||
        j.containsKey('packageName') ||
        j.containsKey('sources');
  }

  factory ExtensionIndexEntry.fromJson(Map<String, dynamic> j) {
    final sources = (j['sources'] as List? ?? const [])
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);

    final hasPackageName = j['packageName'] != null || j['pkg'] != null;
    final hasSourceCodeUrl = j['sourceCodeUrl'] != null;
    final hasId = j['id'] != null;
    final apiUrl = j['apiUrl'] as String?;
    final hasCloudflare = j['hasCloudflare'] == true;
    final itemType = parseItemType(j);

    // Mihon/Keiyoushi shape first — never put JS URLs into apkUrl.
    if (_looksLikeMihon(j)) {
      final pkg = j['packageName'] as String? ?? j['pkg'] as String? ?? '';
      final name = j['name'] as String? ?? (pkg.isEmpty ? 'Unknown' : pkg);

      String apk;
      if (j['resources'] is Map) {
        final r = j['resources'] as Map;
        apk = (r['apkUrl'] as String?) ?? '';
      } else {
        apk = j['apk'] as String? ?? '';
      }

      final version =
          j['versionName'] as String? ?? j['version'] as String? ?? '0';

      final String lang;
      if (sources.isNotEmpty) {
        lang =
            sources.first['language'] as String? ??
            sources.first['lang'] as String? ??
            'en';
      } else {
        lang = j['lang'] as String? ?? 'en';
      }

      final contentWarning =
          j['contentWarning'] as String? ?? 'CONTENT_WARNING_SAFE';
      final nsfw = j['nsfw'] == 1 ||
          j['isNsfw'] == true ||
          contentWarning == 'CONTENT_WARNING_NSFW' ||
          contentWarning == 'CONTENT_WARNING_MIXED';

      final baseUrl =
          j['baseUrl'] as String? ??
          (sources.isNotEmpty
              ? (sources.first['baseUrl'] as String?) ??
                    (sources.first['homeUrl'] as String?)
              : null);
      final iconUrl = j['resources'] is Map
          ? (j['resources'] as Map)['iconUrl'] as String?
          : (j['iconUrl'] as String?);

      return ExtensionIndexEntry(
        pkg: pkg,
        name: name,
        apkUrl: apk,
        sourceCodeUrl: null,
        sourceCodeLanguage: SourceCodeLanguage.mihon,
        version: version,
        lang: lang,
        contentWarning: contentWarning,
        isNsfw: nsfw,
        baseUrl: baseUrl,
        iconUrl: iconUrl,
        apiUrl: apiUrl,
        hasCloudflare: hasCloudflare,
        itemType: itemType,
        sources: sources,
      );
    }

    // Mangayomi native (JS / Dart-eval) — id + sourceCodeUrl, no package/apk.
    if (hasSourceCodeUrl || (hasId && !hasPackageName)) {
      final pkg = j['id']?.toString() ?? '';
      final name = (j['name'] as String?) ?? (pkg.isEmpty ? 'Unknown' : pkg);
      final isNsfw = j['isNsfw'] == true || j['nsfw'] == 1;
      return ExtensionIndexEntry(
        pkg: pkg,
        name: name,
        apkUrl: '',
        sourceCodeUrl: j['sourceCodeUrl'] as String?,
        sourceCodeLanguage: parseSourceCodeLanguage(j['sourceCodeLanguage']),
        version: j['version'] as String? ?? '0',
        lang: j['lang'] as String? ?? 'en',
        contentWarning:
            isNsfw ? 'CONTENT_WARNING_NSFW' : 'CONTENT_WARNING_SAFE',
        isNsfw: isNsfw,
        baseUrl: j['baseUrl'] as String?,
        iconUrl: j['iconUrl'] as String?,
        apiUrl: apiUrl,
        hasCloudflare: hasCloudflare,
        itemType: itemType,
        sources: sources,
      );
    }

    // Fallback: treat as Mihon-like with whatever fields exist.
    final pkg = j['packageName'] as String? ?? j['pkg'] as String? ?? '';
    return ExtensionIndexEntry(
      pkg: pkg,
      name: j['name'] as String? ?? (pkg.isEmpty ? 'Unknown' : pkg),
      apkUrl: j['apk'] as String? ?? '',
      sourceCodeUrl: null,
      sourceCodeLanguage: SourceCodeLanguage.mihon,
      version: j['versionName'] as String? ?? j['version'] as String? ?? '0',
      lang: j['lang'] as String? ?? 'en',
      contentWarning: j['contentWarning'] as String? ?? 'CONTENT_WARNING_SAFE',
      isNsfw: false,
      baseUrl: j['baseUrl'] as String?,
      iconUrl: j['iconUrl'] as String?,
      apiUrl: apiUrl,
      hasCloudflare: hasCloudflare,
      itemType: itemType,
      sources: sources,
    );
  }
}

class ExtensionManager {
  final Repositories _repos;
  final KeiyoushiService _keiyoushi;
  final http.Client _http;
  final TrustExtension _trust = TrustExtension();
  final ApkSignatureService _apkSignatures = ApkSignatureService();

  ExtensionManager(this._repos, this._keiyoushi, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  TrustExtension get trust => _trust;

  Future<List<ExtensionRepo>> listRepos() =>
      _repos.extensions.getExtensionRepos();

  Future<void> addRepo({
    required String name,
    required String url,
    String? kind,
  }) async {
    var resolvedKind = kind;
    if (resolvedKind == null || !ExtensionRepoKind.isKnown(resolvedKind)) {
      resolvedKind = await _detectRepoKind(url);
    }

    String? signingKey;
    if (resolvedKind == ExtensionRepoKind.javascript) {
      // Mangayomi JS indexes have no Mihon repo.json signing key — try/ignore.
      try {
        signingKey = await _fetchSigningKeyForIndex(url);
      } catch (_) {
        signingKey = null;
      }
    } else {
      signingKey = await _fetchSigningKeyForIndex(url);
    }

    final repo = ExtensionRepo(
      name: name,
      url: url,
      signingKey: signingKey,
      kind: resolvedKind,
    );
    await _repos.extensions.insertExtensionRepo(repo);
    await _refreshTrustFingerprints();
  }

  /// Inspect the first index entries to classify mihon vs javascript.
  Future<String> _detectRepoKind(String indexUrl) async {
    try {
      final res = await _http.get(Uri.parse(indexUrl));
      if (res.statusCode != 200) return ExtensionRepoKind.mihon;
      final entries = await Isolate.run(() => _parseIndexBody(res.body));
      if (entries.isEmpty) return ExtensionRepoKind.mihon;
      // Sample a few rows in case the first is an outlier.
      final sample = entries.take(5);
      var jsish = 0;
      var mihonish = 0;
      for (final e in sample) {
        if (e.isMihon && e.apkUrl.isNotEmpty) {
          mihonish++;
        } else if (e.sourceCodeUrl != null && e.sourceCodeUrl!.isNotEmpty) {
          jsish++;
        } else if (e.isJs || e.isDart) {
          jsish++;
        } else if (e.isMihon) {
          mihonish++;
        }
      }
      if (jsish > mihonish) return ExtensionRepoKind.javascript;
      return ExtensionRepoKind.mihon;
    } catch (_) {
      return ExtensionRepoKind.mihon;
    }
  }

  /// Refresh `signingKey` on all repos from sibling `repo.json` (Mihon store meta).
  Future<void> refreshRepoSigningKeys() async {
    final repos = await listRepos();
    for (final repo in repos) {
      if (repo.isJavascript) continue;
      final key = await _fetchSigningKeyForIndex(repo.url);
      if (key == repo.signingKey) continue;
      await _repos.extensions.insertExtensionRepo(
        repo.copyWith(signingKey: () => key),
      );
    }
    await _refreshTrustFingerprints();
  }

  Future<void> _refreshTrustFingerprints() async {
    _trust.updateRepoFingerprints(await listRepos());
  }

  /// Derive Mihon `repo.json` URL from an `index.json` / `index.min.json` URL.
  static String repoJsonUrlForIndex(String indexUrl) {
    var u = indexUrl.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.endsWith('/repo.json')) return u;
    if (u.endsWith('/index.min.json')) {
      return '${u.substring(0, u.length - '/index.min.json'.length)}/repo.json';
    }
    if (u.endsWith('/index.json')) {
      return '${u.substring(0, u.length - '/index.json'.length)}/repo.json';
    }
    return '$u/repo.json';
  }

  Future<String?> _fetchSigningKeyForIndex(String indexUrl) async {
    final repoJson = repoJsonUrlForIndex(indexUrl);
    try {
      final res = await _http.get(Uri.parse(repoJson));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      final meta = decoded['meta'];
      if (meta is Map && meta['signingKeyFingerprint'] is String) {
        return (meta['signingKeyFingerprint'] as String).trim().toLowerCase();
      }
      if (decoded['signingKey'] is String) {
        return (decoded['signingKey'] as String).trim().toLowerCase();
      }
    } catch (_) {}
    return null;
  }

  Future<void> removeRepo(int id) => _repos.extensions.deleteExtensionRepo(id);

  /// One-time fetch of the full Keiyoushi `index.json` (~1.3 MB) to populate
  /// the persistent `pkg → iconUrl` cache ([ExtensionIconCache]). Subsequent
  /// calls are no-ops once the cache is populated. Safe to call on app start
  /// or on the extensions screen — failures are swallowed and reported via
  /// [onError] so icon resolution degrades to the CDN derivation fallback.
  ///
  /// See Q5: the legacy `.../repo/icon/${pkg}.png` URLs always 404'd against
  /// Keiyoushi; the authoritative icon URLs live in the full index's
  /// `resources.iconUrl` field.
  Future<void> refreshIconCache({void Function(Object error)? onError}) {
    return ExtensionIconCache.instance.ensurePopulated(onError: onError);
  }

  Future<List<ExtensionIndexEntry>> fetchIndex(ExtensionRepo repo) async {
    final res = await _http.get(Uri.parse(repo.url));
    if (res.statusCode != 200) {
      throw HttpException('Repo returned ${res.statusCode}: ${repo.url}');
    }
    // Keiyoushi index is ~500KB / 1.3k entries — parse off the UI isolate so
    // mid-range Android devices don't freeze (or black-screen) during fetch.
    return Isolate.run(() => _parseIndexBody(res.body));
  }

  Future<ExtensionSource> install(
    ExtensionIndexEntry entry, {
    required String repoUrl,
  }) async {
    if (entry.isDart ||
        entry.sourceCodeLanguage == SourceCodeLanguage.unsupported) {
      throw UnsupportedExtensionLanguageException(
        entry.sourceCodeLanguage,
        name: entry.name,
      );
    }
    if (entry.isJs) {
      return installJs(entry, repoUrl: repoUrl);
    }

    final dir = await _extensionsDir();
    final apkPath = p.join(dir.path, '${entry.pkg}.apk');
    final baseUrl = repoUrl.replaceFirst(RegExp(r'/[^/]*$'), '');
    final resolved = _resolveApkUrl(baseUrl, entry.apkUrl);

    final apkFile = File(apkPath);
    if (apkFile.existsSync()) {
      try {
        await Process.run('chmod', ['+w', apkPath]);
      } catch (_) {}
      try {
        apkFile.deleteSync();
      } catch (_) {}
    }
    await _downloadApk(resolved, apkPath);

    await _refreshTrustFingerprints();
    final signing = await _apkSignatures.inspect(apkPath);
    if (!await _trust.isTrusted(signing)) {
      throw UntrustedExtensionException(signing);
    }

    return _finishInstall(
      entry: entry,
      repoUrl: repoUrl,
      apkPath: apkPath,
      resolved: resolved,
      signing: signing,
    );
  }

  /// Fetch JS `sourceCodeUrl` text and persist — no Dalvik, no APK trust gate.
  Future<ExtensionSource> installJs(
    ExtensionIndexEntry entry, {
    required String repoUrl,
  }) async {
    final url = entry.sourceCodeUrl;
    if (url == null || url.isEmpty) {
      throw StateError(
        'JavaScript extension missing sourceCodeUrl: ${entry.name}',
      );
    }
    final id = entry.pkg;
    if (id.isEmpty) {
      throw StateError('JavaScript extension missing id: ${entry.name}');
    }

    final res = await _http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw HttpException(
        'JS source download failed: ${res.statusCode} at $url',
      );
    }
    final body = res.body;
    if (body.trim().isEmpty) {
      throw StateError('JS source body empty at $url');
    }

    final header = parseMangayomiSourcesHeader(body);
    final apiUrl = (entry.apiUrl != null && entry.apiUrl!.isNotEmpty)
        ? entry.apiUrl
        : (header['apiUrl']?.isNotEmpty == true ? header['apiUrl'] : null);
    final hasCloudflare =
        entry.hasCloudflare || header['hasCloudflare'] == 'true';
    final headerItem = header['itemType'];
    final itemType = (entry.itemType != null && entry.itemType!.isNotEmpty)
        ? entry.itemType!
        : (headerItem != null && headerItem.isNotEmpty ? headerItem : 'manga');

    final src = ExtensionSource(
      id: id,
      sourceId: id,
      name: entry.name,
      version: entry.version,
      lang: entry.lang,
      apkPath: '',
      className: '',
      iconUrl: entry.iconUrl,
      baseUrl: entry.baseUrl,
      sourceCodeUrl: url,
      repoUrl: repoUrl,
      apiUrl: apiUrl,
      hasCloudflare: hasCloudflare,
      itemType: itemType,
      sourceCode: body,
      sourceCodeLanguage: SourceCodeLanguage.js,
      isInstalled: true,
      isActive: true,
      isNsfw: entry.isNsfw,
    );
    await _repos.extensions.insertExtensionSource(src);
    return src;
  }

  /// After the user confirms Trust on an [UntrustedExtensionException], call
  /// this to persist trust and complete the pending install.
  Future<ExtensionSource> trustAndInstall(
    ApkSigningInfo signing,
    ExtensionIndexEntry entry, {
    required String repoUrl,
  }) async {
    final dir = await _extensionsDir();
    final apkPath = p.join(dir.path, '${entry.pkg}.apk');
    if (!File(apkPath).existsSync()) {
      throw StateError('APK missing for trust install: $apkPath');
    }
    await _trust.trust(signing);
    final baseUrl = repoUrl.replaceFirst(RegExp(r'/[^/]*$'), '');
    final resolved = _resolveApkUrl(baseUrl, entry.apkUrl);
    return _finishInstall(
      entry: entry,
      repoUrl: repoUrl,
      apkPath: apkPath,
      resolved: resolved,
      signing: signing,
    );
  }

  Future<ExtensionSource> _finishInstall({
    required ExtensionIndexEntry entry,
    required String repoUrl,
    required String apkPath,
    required String resolved,
    required ApkSigningInfo signing,
  }) async {
    final iconUrl = ExtensionIconCache.iconUrlForPkg(entry.pkg) ?? '';
    final sourceCodeUrl = resolved;

    final desc = await _keiyoushi.loadExtension(
      apkPath: apkPath,
      className: entry.className,
    );
    final nativeId = (desc['id'] as String?) ?? '';
    final sourceId = (desc['sourceId'] as String?) ?? '';
    if (nativeId.isEmpty) {
      throw Exception('Native bridge returned no ID for ${entry.name}');
    }

    // Prefer the baseUrl the loaded extension reports itself (authoritative
    // `source.baseUrl` from the APK) over the index entry — keiyoushi's v2
    // index format only exposes `sources[].homeUrl`, and not every repo entry
    // carries a `baseUrl`, so the installed source's Referer would otherwise
    // be missing and hotlink-protected image CDNs (fmcdn, etc.) return 403.
    final nativeBaseUrl = (desc['baseUrl'] as String?) ?? '';
    final firstSource = entry.sources.isNotEmpty ? entry.sources.first : null;
    final src = ExtensionSource(
      id: nativeId,
      sourceId: sourceId,
      name: (desc['name'] as String?) ?? entry.name,
      version: entry.version,
      lang: (desc['lang'] as String?) ?? entry.lang,
      apkPath: apkPath,
      className: entry.className ?? '',
      iconUrl: iconUrl,
      baseUrl: nativeBaseUrl.isNotEmpty
          ? nativeBaseUrl
          : entry.baseUrl ?? firstSource?['baseUrl'] as String?,
      sourceCodeUrl: sourceCodeUrl,
      repoUrl: repoUrl,
      sourceCode: '',
      sourceCodeLanguage: SourceCodeLanguage.mihon,
      pkgName: signing.packageName,
      versionCode: signing.versionCode,
      signatureHash: signing.primarySignature ?? '',
      isActive: true,
      isNsfw: entry.isNsfw,
    );
    await _repos.extensions.insertExtensionSource(src);
    return src;
  }

  /// Discard a downloaded APK after the user declines to trust it.
  Future<void> discardUntrustedApk(ExtensionIndexEntry entry) async {
    final dir = await _extensionsDir();
    final apkPath = p.join(dir.path, '${entry.pkg}.apk');
    try {
      final f = File(apkPath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<void> uninstall(ExtensionSource src) async {
    if (src.isJs) {
      await _repos.extensions.deleteExtensionSource(src.sourceId);
      return;
    }

    final installed = await listInstalled();
    for (final s in installed) {
      if (s.apkPath == src.apkPath) {
        await _repos.extensions.deleteExtensionSource(s.id);
      }
    }
    try {
      await _keiyoushi.unloadExtension(src.sourceId);
    } catch (_) {}
    try {
      final f = File(src.apkPath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<void> updateSource(
    ExtensionSource src,
    ExtensionIndexEntry entry,
    String repoUrl,
  ) async {
    if (entry.isDart ||
        entry.sourceCodeLanguage == SourceCodeLanguage.unsupported) {
      throw UnsupportedExtensionLanguageException(
        entry.sourceCodeLanguage,
        name: entry.name,
      );
    }
    if (entry.isJs || src.isJs) {
      await _updateJsSource(src, entry, repoUrl);
      return;
    }

    await _keiyoushi.unloadExtension(src.sourceId);

    final dir = await _extensionsDir();
    final newApkPath = p.join(dir.path, '${entry.pkg}.apk');
    final baseUrl = repoUrl.replaceFirst(RegExp(r'/[^/]*$'), '');
    final resolved = _resolveApkUrl(baseUrl, entry.apkUrl);

    final apkFile = File(newApkPath);
    if (apkFile.existsSync()) {
      try {
        await Process.run('chmod', ['+w', newApkPath]);
      } catch (_) {}
      try {
        apkFile.deleteSync();
      } catch (_) {}
    }

    await _downloadApk(resolved, newApkPath);

    await _refreshTrustFingerprints();
    final signing = await _apkSignatures.inspect(newApkPath);
    if (!await _trust.isTrusted(signing)) {
      throw UntrustedExtensionException(signing);
    }

    await _finishUpdate(
      src: src,
      entry: entry,
      newApkPath: newApkPath,
      signing: signing,
    );
  }

  Future<void> _updateJsSource(
    ExtensionSource src,
    ExtensionIndexEntry entry,
    String repoUrl,
  ) async {
    final url = entry.sourceCodeUrl;
    if (url == null || url.isEmpty) {
      throw StateError(
        'JavaScript extension missing sourceCodeUrl: ${entry.name}',
      );
    }
    final res = await _http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw HttpException(
        'JS source download failed: ${res.statusCode} at $url',
      );
    }
    final body = res.body;
    if (body.trim().isEmpty) {
      throw StateError('JS source body empty at $url');
    }

    final id = entry.pkg.isNotEmpty ? entry.pkg : src.sourceId;
    if (src.sourceId.isNotEmpty && src.sourceId != id) {
      await _repos.extensions.deleteExtensionSource(src.sourceId);
    }

    await _repos.extensions.insertExtensionSource(
      src.copyWith(
        id: id,
        sourceId: id,
        name: entry.name,
        version: entry.version,
        versionLast: entry.version,
        lang: entry.lang,
        apkPath: '',
        className: '',
        iconUrl: entry.iconUrl ?? src.iconUrl,
        baseUrl: entry.baseUrl ?? src.baseUrl,
        sourceCodeUrl: url,
        repoUrl: repoUrl,
        sourceCode: body,
        sourceCodeLanguage: SourceCodeLanguage.js,
        isInstalled: true,
        isObsolete: false,
        isActive: true,
        isNsfw: entry.isNsfw,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// After Trust on an update [UntrustedExtensionException], persist trust and
  /// finish loading the already-downloaded APK.
  Future<void> trustAndUpdate(
    ApkSigningInfo signing,
    ExtensionSource src,
    ExtensionIndexEntry entry,
  ) async {
    final dir = await _extensionsDir();
    final newApkPath = p.join(dir.path, '${entry.pkg}.apk');
    if (!File(newApkPath).existsSync()) {
      throw StateError('APK missing for trust update: $newApkPath');
    }
    await _trust.trust(signing);
    await _finishUpdate(
      src: src,
      entry: entry,
      newApkPath: newApkPath,
      signing: signing,
    );
  }

  Future<void> _finishUpdate({
    required ExtensionSource src,
    required ExtensionIndexEntry entry,
    required String newApkPath,
    required ApkSigningInfo signing,
  }) async {
    final desc = await _keiyoushi.loadExtension(
      apkPath: newApkPath,
      className: entry.className,
    );
    final newSourceId = (desc['sourceId'] as String?) ?? '';
    final nativeId = (desc['id'] as String?) ?? '';
    final nativeBaseUrl = (desc['baseUrl'] as String?) ?? '';

    // The new APK can report a different sourceId (keiyoushi rotates IDs on
    // release). delete-then-insert rather than relying on Isar's
    // `@Index(unique, replace)` — that only collapses rows sharing the SAME
    // sourceId, so a rotated ID would otherwise leave a stale duplicate row.
    if (src.sourceId.isNotEmpty) {
      await _repos.extensions.deleteExtensionSource(src.sourceId);
    }
    await _repos.extensions.insertExtensionSource(
      src.copyWith(
        id: nativeId.isNotEmpty ? nativeId : newSourceId,
        sourceId: newSourceId,
        apkPath: newApkPath,
        version: entry.version,
        versionLast: entry.version,
        isObsolete: false,
        pkgName: signing.packageName,
        versionCode: signing.versionCode,
        signatureHash: signing.primarySignature ?? '',
        isActive: true,
        // Backfill the extension's authoritative baseUrl when the index entry
        // didn't carry one (see install() for the v2-format rationale).
        baseUrl: nativeBaseUrl.isNotEmpty ? nativeBaseUrl : src.baseUrl,
      ),
    );
  }

  Future<void> checkForUpdates(
    List<ExtensionIndexEntry> freshEntries,
    String repoUrl,
  ) async {
    if (freshEntries.isEmpty) return;

    final installed = await listInstalled();
    // Only compare against sources installed from this repo — JS catalogs often
    // share pkg ids across forks (e.g. MangaFire 0.2.20 on entityJY vs 0.1.25
    // on kodjodevf). Cross-repo matches must not downgrade versionLast.
    final scoped = installed
        .where((s) => s.repoUrl == null || s.repoUrl!.isEmpty || s.repoUrl == repoUrl)
        .toList();
    if (scoped.isEmpty) return;

    // Per installed source: highest version in this index that matches it.
    final bestBySourceId = <String, String>{};

    void consider(ExtensionSource match, String entryVersion) {
      if (match.sourceId.isEmpty) return;
      final current = bestBySourceId[match.sourceId];
      if (current == null || compareVersions(current, entryVersion) < 0) {
        bestBySourceId[match.sourceId] = entryVersion;
      }
    }

    for (final entry in freshEntries) {
      if (entry.isJs) {
        for (final isrc in scoped) {
          if (!isrc.isJs) continue;
          final hit = isrc.sourceId == entry.pkg ||
              isrc.id == entry.pkg ||
              (isrc.sourceCodeUrl != null &&
                  isrc.sourceCodeUrl!.isNotEmpty &&
                  isrc.sourceCodeUrl == entry.sourceCodeUrl);
          if (hit) consider(isrc, entry.version);
        }
        continue;
      }

      for (final s in entry.sources) {
        final className = s['className'] as String? ?? '';
        if (className.isEmpty) continue;
        for (final isrc in scoped) {
          if (isrc.className == className) consider(isrc, entry.version);
        }
      }
    }

    for (final src in scoped) {
      final best = bestBySourceId[src.sourceId];
      if (best == null) continue;

      if (compareVersions(src.version, best) < 0) {
        // Index has a strictly newer version.
        if (src.versionLast == best) continue;
        await _repos.extensions.insertExtensionSource(
          src.copyWith(versionLast: best),
        );
      } else if (src.versionLast != null &&
          src.versionLast!.isNotEmpty &&
          src.versionLast != src.version &&
          compareVersions(src.version, src.versionLast!) >= 0) {
        // Clear stale badges (e.g. older fork version previously written).
        await _repos.extensions.insertExtensionSource(
          src.copyWith(versionLast: src.version),
        );
      }
    }
  }

  /// When [autoInstall] is enabled (Mangayomi `autoUpdateExtensions` parity),
  /// download and reload every installed source whose `versionLast` differs
  /// from `version`. Skipped sources (missing index entry) are left as-is.
  Future<int> autoInstallAvailableUpdates() async {
    final installed = await listInstalled();
    final outdated = installed.where((s) => s.isUpdateAvailable).toList();
    if (outdated.isEmpty) return 0;

    final repos = await listRepos();
    final enabledRepos = repos.where((r) => r.enabled).toList();
    final indexByRepoUrl = <String, List<ExtensionIndexEntry>>{};
    var updated = 0;

    for (final src in outdated) {
      try {
        ExtensionRepo? repo;
        if (src.repoUrl != null && src.repoUrl!.isNotEmpty) {
          for (final r in enabledRepos) {
            if (r.url == src.repoUrl) {
              repo = r;
              break;
            }
          }
        }
        repo ??= enabledRepos.isEmpty ? null : enabledRepos.first;
        if (repo == null) continue;

        final entries = indexByRepoUrl[repo.url] ??= await fetchIndex(repo);
        final matches = <ExtensionIndexEntry>[];
        for (final e in entries) {
          if (src.isJs) {
            if (e.isJs &&
                (e.pkg == src.sourceId ||
                    e.pkg == src.id ||
                    (src.sourceCodeUrl != null &&
                        e.sourceCodeUrl == src.sourceCodeUrl))) {
              matches.add(e);
            }
            continue;
          }
          if (src.className.isNotEmpty && e.className == src.className) {
            matches.add(e);
          }
        }
        if (matches.isEmpty) continue;
        // [entries] are already from [repo]; skip if this isn't the install repo
        // when the source has one (avoid installing an older fork).
        if (src.repoUrl != null &&
            src.repoUrl!.isNotEmpty &&
            repo.url != src.repoUrl) {
          continue;
        }
        final target = src.versionLast;
        ExtensionIndexEntry? match;
        if (target != null &&
            target.isNotEmpty &&
            compareVersions(src.version, target) < 0) {
          match = matches.where((e) => e.version == target).firstOrNull;
        }
        match ??= () {
          matches.sort((a, b) => compareVersions(b.version, a.version));
          for (final e in matches) {
            if (compareVersions(src.version, e.version) < 0) return e;
          }
          return null;
        }();
        if (match == null) continue;
        await updateSource(src, match, repo.url);
        updated++;
      } catch (_) {
        // One bad APK must not block the rest (same pattern as library poll).
      }
    }
    return updated;
  }

  Future<void> checkForObsoleteSources(
    List<ExtensionIndexEntry> freshEntries,
    String repoUrl,
  ) async {
    if (freshEntries.isEmpty) return;

    final knownClassNames = <String>{};
    final knownJsIds = <String>{};
    for (final entry in freshEntries) {
      if (entry.isJs && entry.pkg.isNotEmpty) {
        knownJsIds.add(entry.pkg);
      }
      for (final s in entry.sources) {
        final className = s['className'] as String? ?? '';
        if (className.isNotEmpty) knownClassNames.add(className);
      }
    }
    if (knownClassNames.isEmpty && knownJsIds.isEmpty) return;

    final installed = await listInstalled();
    final toUpdate = <ExtensionSource>[];
    for (final src in installed) {
      if (src.repoUrl != repoUrl) continue;
      final bool isNowObsolete;
      if (src.isJs) {
        if (knownJsIds.isEmpty) continue;
        isNowObsolete = !knownJsIds.contains(src.sourceId) &&
            !knownJsIds.contains(src.id);
      } else {
        if (knownClassNames.isEmpty) continue;
        isNowObsolete = !knownClassNames.contains(src.className);
      }
      if (src.isObsolete != isNowObsolete) {
        toUpdate.add(
          src.copyWith(isObsolete: isNowObsolete),
        );
      }
    }
    for (final s in toUpdate) {
      await _repos.extensions.insertExtensionSource(s);
    }
  }

  Future<List<ExtensionSource>> listInstalled() =>
      _repos.extensions.getInstalledExtensions();

  /// Probe every installed APK: auto-trust if fingerprint ∈ repo keys or
  /// user trust set; otherwise unload + mark inactive (Untrusted).
  Future<int> reconcileTrust() async {
    await refreshRepoSigningKeys();
    await _refreshTrustFingerprints();
    final installed = await listInstalled();
    final byApk = <String, List<ExtensionSource>>{};
    for (final s in installed) {
      if (s.apkPath.isEmpty) continue;
      byApk.putIfAbsent(s.apkPath, () => []).add(s);
    }

    var changed = 0;
    for (final MapEntry(:key, :value) in byApk.entries) {
      final apkPath = key;
      final sources = value;
      if (!File(apkPath).existsSync()) continue;
      try {
        final info = await _apkSignatures.inspect(apkPath);
        final trusted = await _trust.isTrusted(info);
        for (final src in sources) {
          var next = src.copyWith(
            pkgName: info.packageName,
            versionCode: info.versionCode,
            signatureHash: info.primarySignature ?? '',
          );
          if (trusted) {
            if (!src.isActive) {
              try {
                await _keiyoushi.loadExtension(
                  apkPath: apkPath,
                  className: src.className.isEmpty ? null : src.className,
                );
              } catch (_) {}
              next = next.copyWith(isActive: true);
              changed++;
            } else if (src.pkgName != next.pkgName ||
                src.signatureHash != next.signatureHash ||
                src.versionCode != next.versionCode) {
              changed++;
            } else {
              continue;
            }
          } else {
            if (src.isActive) {
              try {
                await _keiyoushi.unloadExtension(src.sourceId);
              } catch (_) {}
              next = next.copyWith(isActive: false);
              changed++;
            } else if (src.pkgName != next.pkgName ||
                src.signatureHash != next.signatureHash) {
              changed++;
            } else {
              continue;
            }
          }
          await _repos.extensions.insertExtensionSource(next);
        }
      } catch (_) {
        // Keep existing rows if APK can't be parsed.
      }
    }
    return changed;
  }

  /// Trust an already-sideloaded Untrusted package and reactivate its sources.
  Future<void> trustExistingPackage(ExtensionSource sample) async {
    if (sample.apkPath.isEmpty) return;
    final info = await _apkSignatures.inspect(sample.apkPath);
    await _trust.trust(info);
    final installed = await listInstalled();
    for (final src in installed.where((s) => s.apkPath == sample.apkPath)) {
      try {
        await _keiyoushi.loadExtension(
          apkPath: src.apkPath,
          className: src.className.isEmpty ? null : src.className,
        );
      } catch (_) {}
      await _repos.extensions.insertExtensionSource(
        src.copyWith(
          isActive: true,
          pkgName: info.packageName,
          versionCode: info.versionCode,
          signatureHash: info.primarySignature ?? '',
        ),
      );
    }
  }

  /// Settings → revoke all user-trusted fingerprints, then re-evaluate APKs.
  Future<int> revokeAllTrusted() async {
    await _trust.revokeAll();
    return reconcileTrust();
  }

  /// Translate any source identifier (old Mihon numeric ID or hex sourceId)
  /// to the hex sourceId used by the DalvikServer cache. Falls back to
  /// [sourceId] if no match is found in installed extensions.
  Future<String> resolveSourceId(String sourceId) async {
    final installed = await listInstalled();
    // Direct hex match — already correct
    if (installed.any((e) => e.sourceId == sourceId)) return sourceId;
    // Look up by old Mihon numeric ID (stored in ext.id)
    for (final ext in installed) {
      if (ext.id == sourceId) return ext.sourceId;
    }
    return sourceId;
  }

  Future<void> reloadAll() async {
    // Refresh repo signing keys + demote Untrusted before touching Dalvik.
    await reconcileTrust();
    final installed = await listInstalled();
    for (final src in installed) {
      if (!src.isActive) continue;
      // JS sources have no APK — skip Dalvik loadExtension.
      if (src.isJs || src.apkPath.isEmpty) continue;
      if (!File(src.apkPath).existsSync()) {
        await _repos.extensions.deleteExtensionSource(src.sourceId);
        continue;
      }
      try {
        final desc = await _keiyoushi.loadExtension(
          apkPath: src.apkPath,
          className: src.className.isEmpty ? null : src.className,
        );
        final nativeId = (desc['id'] as String?) ?? '';
        final newSourceId = (desc['sourceId'] as String?) ?? '';
        if (nativeId.isEmpty) continue;

        if (src.id != nativeId || src.sourceId != newSourceId) {
          await _repos.extensions.deleteExtensionSource(src.sourceId);
          await _repos.extensions.insertExtensionSource(
            src.copyWith(id: nativeId, sourceId: newSourceId),
          );
        }

        // Backfill baseUrl from the loaded extension's own `source.baseUrl`
        // when it's missing — sources installed before keiyoushi's v2 index
        // (which exposes `sources[].homeUrl`, not `baseUrl`) have an empty
        // baseUrl, so their image requests carried no Referer and hotlink-
        // protected CDNs (fmcdn.mfcdn.net for mangafox) returned 403.
        final nativeBaseUrl = (desc['baseUrl'] as String?) ?? '';
        if (src.baseUrl == null || src.baseUrl!.isEmpty) {
          if (nativeBaseUrl.isNotEmpty) {
            await _repos.extensions.insertExtensionSource(
              src.copyWith(baseUrl: nativeBaseUrl),
            );
          }
        }
      } catch (_) {}
    }
  }

  Future<Directory> _extensionsDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'extensions'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    try {
      await Process.run('chmod', ['-R', '+w', dir.path]);
    } catch (_) {}
    return dir;
  }

  String _resolveApkUrl(String baseUrl, String apkUrl) {
    if (apkUrl.isEmpty) return '';
    if (apkUrl.startsWith('http://') || apkUrl.startsWith('https://')) {
      return apkUrl;
    }
    if (apkUrl.contains('/')) {
      return '$baseUrl/$apkUrl';
    }
    return '$baseUrl/apk/$apkUrl';
  }

  Future<void> _downloadApk(String url, String destPath) async {
    final res = await _http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw HttpException('APK download failed: ${res.statusCode} at $url');
    }
    await File(destPath).writeAsBytes(res.bodyBytes);
  }
}

/// Top-level so [Isolate.run] can invoke it without capturing the manager.
List<ExtensionIndexEntry> _parseIndexBody(String body) {
  final decoded = jsonDecode(body);
  if (decoded is List) {
    return decoded
        .cast<Map>()
        .map((e) => ExtensionIndexEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }
  if (decoded is Map) {
    final extList = decoded['extensionList'];
    if (extList is Map) {
      final exts = extList['extensions'];
      if (exts is List) {
        return exts
            .cast<Map>()
            .map(
              (e) => ExtensionIndexEntry.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList(growable: false);
      }
    }
  }
  throw FormatException(
    'Repo JSON is not a recognized format — got ${decoded.runtimeType}',
  );
}

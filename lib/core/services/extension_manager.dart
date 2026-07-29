import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/extension_repo.dart';
import '../models/extension_source.dart';
import '../repositories/repositories.dart';
import 'extension_icon_cache.dart';
import 'keiyoushi_service.dart';

class ExtensionIndexEntry {
  final String pkg;
  final String name;
  final String apkUrl;
  final String version;
  final String lang;
  final String contentWarning;
  final String? baseUrl;
  final String? iconUrl;
  final List<Map<String, dynamic>> sources;

  const ExtensionIndexEntry({
    required this.pkg,
    required this.name,
    required this.apkUrl,
    required this.version,
    required this.lang,
    this.contentWarning = 'CONTENT_WARNING_SAFE',
    this.baseUrl,
    this.iconUrl,
    required this.sources,
  });

  String? get className {
    if (sources.isEmpty) return null;
    final c = sources.first['className'];
    if (c is String && c.isNotEmpty) return c;
    return null;
  }

  factory ExtensionIndexEntry.fromJson(Map<String, dynamic> j) {
    final sources = (j['sources'] as List? ?? const [])
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);

    String pkg;
    String name;
    String apkUrl;
    String version;
    String lang;
    String contentWarning;
    String? baseUrl;
    String? iconUrl;

    final hasPackageName = j['packageName'] != null || j['pkg'] != null;
    final hasSourceCodeUrl = j['sourceCodeUrl'] != null;
    final hasId = j['id'] != null;

    if (hasSourceCodeUrl || (hasId && !hasPackageName)) {
      pkg = j['id']?.toString() ?? '';
      name = (j['name'] as String?) ?? (pkg.isEmpty ? 'Unknown' : pkg);
      apkUrl = j['sourceCodeUrl'] as String? ?? '';
      version = j['version'] as String? ?? '0';
      lang = j['lang'] as String? ?? 'en';
      contentWarning = (j['isNsfw'] as bool? ?? false)
          ? 'CONTENT_WARNING_NSFW'
          : 'CONTENT_WARNING_SAFE';
      baseUrl = j['baseUrl'] as String?;
      iconUrl = j['iconUrl'] as String?;
    } else {
      pkg = j['packageName'] as String? ??
          j['pkg'] as String? ??
          '';
      name = j['name'] as String? ??
          pkg ??
          'Unknown';

      String apk;
      if (j['resources'] is Map) {
        final r = j['resources'] as Map;
        apk = (r['apkUrl'] as String?) ?? '';
      } else {
        apk = j['apk'] as String? ?? '';
      }
      apkUrl = apk;

      version = j['versionName'] as String? ??
          j['version'] as String? ??
          '0';

      if (sources.isNotEmpty) {
        lang = sources.first['language'] as String? ??
            sources.first['lang'] as String? ??
            'en';
      } else {
        lang = j['lang'] as String? ?? 'en';
      }

      contentWarning = j['contentWarning'] as String? ??
          'CONTENT_WARNING_SAFE';

      baseUrl = j['baseUrl'] as String? ??
          (sources.isNotEmpty ? sources.first['baseUrl'] as String? : null);
      iconUrl = j['resources'] is Map
          ? (j['resources'] as Map)['iconUrl'] as String?
          : null;
    }

    return ExtensionIndexEntry(
      pkg: pkg,
      name: name,
      apkUrl: apkUrl,
      version: version,
      lang: lang,
      contentWarning: contentWarning,
      baseUrl: baseUrl,
      iconUrl: iconUrl,
      sources: sources,
    );
  }
}

class ExtensionManager {
  final Repositories _repos;
  final KeiyoushiService _keiyoushi;
  final http.Client _http;

  ExtensionManager(
    this._repos,
    this._keiyoushi, {
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  Future<List<ExtensionRepo>> listRepos() => _repos.extensions.getExtensionRepos();

  Future<void> addRepo({required String name, required String url}) async {
    final repo = ExtensionRepo(name: name, url: url);
    await _repos.extensions.insertExtensionRepo(repo);
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
  Future<void> refreshIconCache({
    void Function(Object error)? onError,
  }) {
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
    final dir = await _extensionsDir();
    final apkPath = p.join(dir.path, '${entry.pkg}.apk');
    final baseUrl = repoUrl.replaceFirst(RegExp(r'/[^/]*$'), '');
    final resolved = _resolveApkUrl(baseUrl, entry.apkUrl);

    final apkFile = File(apkPath);
    if (apkFile.existsSync()) {
      try { await Process.run('chmod', ['+w', apkPath]); } catch (_) {}
      try { apkFile.deleteSync(); } catch (_) {}
    }
    await _downloadApk(resolved, apkPath);

    final iconUrl =
        ExtensionIconCache.iconUrlForPkg(entry.pkg) ?? '';
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
      baseUrl: entry.baseUrl ?? firstSource?['baseUrl'] as String?,
      sourceCodeUrl: sourceCodeUrl,
      repoUrl: repoUrl,
    );
    await _repos.extensions.insertExtensionSource(src);
    return src;
  }

  Future<void> uninstall(ExtensionSource src) async {
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
    await _keiyoushi.unloadExtension(src.sourceId);

    final dir = await _extensionsDir();
    final newApkPath = p.join(dir.path, '${entry.pkg}.apk');
    final baseUrl = repoUrl.replaceFirst(RegExp(r'/[^/]*$'), '');
    final resolved = _resolveApkUrl(baseUrl, entry.apkUrl);

    final apkFile = File(newApkPath);
    if (apkFile.existsSync()) {
      try { await Process.run('chmod', ['+w', newApkPath]); } catch (_) {}
      try { apkFile.deleteSync(); } catch (_) {}
    }

    await _downloadApk(resolved, newApkPath);

    final desc = await _keiyoushi.loadExtension(
      apkPath: newApkPath,
      className: entry.className,
    );
    final newSourceId = (desc['sourceId'] as String?) ?? '';

    await _repos.extensions.insertExtensionSource(src.copyWith(
      sourceId: newSourceId,
      apkPath: newApkPath,
      version: entry.version,
      versionLast: entry.version,
      isObsolete: false,
    ));
  }

  Future<void> checkForUpdates(
    List<ExtensionIndexEntry> freshEntries,
    String repoUrl,
  ) async {
    if (freshEntries.isEmpty) return;

    final installed = await listInstalled();

    for (final entry in freshEntries) {
      for (final s in entry.sources) {
        final className = s['className'] as String? ?? '';
        if (className.isEmpty) continue;

        final match = installed.firstWhere(
          (isrc) => isrc.className == className,
          orElse: () => ExtensionSource(
            id: '',
            sourceId: '',
            name: '',
            version: '',
            lang: '',
            apkPath: '',
            className: '',
          ),
        );
        if (match.id.isEmpty) continue;
        if (match.version == entry.version) continue;

        await _repos.extensions.insertExtensionSource(match.copyWith(
          versionLast: entry.version,
        ));
      }
    }
  }

  Future<void> checkForObsoleteSources(
    List<ExtensionIndexEntry> freshEntries,
    String repoUrl,
  ) async {
    if (freshEntries.isEmpty) return;

    final knownClassNames = <String>{};
    for (final entry in freshEntries) {
      for (final s in entry.sources) {
        final className = s['className'] as String? ?? '';
        if (className.isNotEmpty) knownClassNames.add(className);
      }
    }
    if (knownClassNames.isEmpty) return;

    final installed = await listInstalled();
    final toUpdate = <ExtensionSource>[];
    for (final src in installed) {
      if (src.repoUrl != repoUrl) continue;
      final isNowObsolete = !knownClassNames.contains(src.className);
      if (src.isObsolete != isNowObsolete) {
        toUpdate.add(ExtensionSource(
          id: src.id,
          sourceId: src.sourceId,
          name: src.name,
          version: src.version,
          lang: src.lang,
          apkPath: src.apkPath,
          className: src.className,
          isObsolete: isNowObsolete,
          isActive: src.isActive,
          isInstalled: src.isInstalled,
          isNsfw: src.isNsfw,
          isPinned: src.isPinned,
        ));
      }
    }
    for (final s in toUpdate) {
      await _repos.extensions.insertExtensionSource(s);
    }
  }

  Future<List<ExtensionSource>> listInstalled() => _repos.extensions.getInstalledExtensions();

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
    final installed = await listInstalled();
    for (final src in installed) {
      if (!File(src.apkPath).existsSync()) {
        await _repos.extensions.deleteExtensionSource(src.id);
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
          await _repos.extensions.deleteExtensionSource(src.id);
          await _repos.extensions.insertExtensionSource(src.copyWith(
            id: nativeId,
            sourceId: newSourceId,
          ));
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
            .map((e) => ExtensionIndexEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false);
      }
    }
  }
  throw FormatException(
    'Repo JSON is not a recognized format — got ${decoded.runtimeType}',
  );
}

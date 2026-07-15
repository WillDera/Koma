import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/extension_repo.dart';
import '../models/extension_source.dart';
import 'database_service.dart';
import 'keiyoushi_service.dart';

/// One entry from a Keiyoushi/Mihon `index.min.json`.
class ExtensionIndexEntry {
  final String pkg;
  final String name;
  final String apkUrl;
  final String version;
  final String lang;
  final List<Map<String, dynamic>> sources;

  const ExtensionIndexEntry({
    required this.pkg,
    required this.name,
    required this.apkUrl,
    required this.version,
    required this.lang,
    required this.sources,
  });

  factory ExtensionIndexEntry.fromJson(Map<String, dynamic> j) {
    final sources = (j['sources'] as List? ?? const [])
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
    return ExtensionIndexEntry(
      pkg: j['pkg'] as String? ?? '',
      name: j['name'] as String? ?? j['pkg'] as String? ?? 'Unknown',
      apkUrl: j['apk'] as String? ?? '',
      version: j['version'] as String? ?? '0',
      lang: (sources.isNotEmpty
              ? sources.first['lang']
              : j['lang']) as String? ??
          'en',
      sources: sources,
    );
  }
}

/// High-level orchestrator for extension lifecycle:
///   - Persist extension repos
///   - Fetch + parse Keiyoushi index.min.json
///   - Download APKs
///   - Ask the native bridge to load them
///   - Persist the resulting Source descriptors
class ExtensionManager {
  final DatabaseService _db;
  final KeiyoushiService _keiyoushi;
  final http.Client _http;

  ExtensionManager(
    this._db,
    this._keiyoushi, {
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  // -- Repos ------------------------------------------------------------

  Future<List<ExtensionRepo>> listRepos() => _db.getExtensionRepos();

  Future<void> addRepo({required String name, required String url}) async {
    final repo = ExtensionRepo(name: name, url: url);
    await _db.insertExtensionRepo(repo);
  }

  Future<void> removeRepo(int id) => _db.deleteExtensionRepo(id);

  // -- Index fetching ---------------------------------------------------

  /// Fetch the Keiyoushi index JSON from a repo URL. The URL is expected
  /// to point to an `index.min.json` (or full `index.json`).
  Future<List<ExtensionIndexEntry>> fetchIndex(ExtensionRepo repo) async {
    final res = await _http.get(Uri.parse(repo.url));
    if (res.statusCode != 200) {
      throw HttpException('Repo returned ${res.statusCode}: ${repo.url}');
    }
    final list = jsonDecode(res.body);
    if (list is! List) {
      throw FormatException(
        'Repo JSON is not a list — got ${list.runtimeType}',
      );
    }
    return list
        .cast<Map>()
        .map((e) => ExtensionIndexEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  // -- Install / uninstall ---------------------------------------------

  /// Download an APK, load it via the native bridge, and persist the
  /// resulting Source descriptor. Returns the installed extension.
  ///
  /// If the APK is already on disk (e.g. user re-installing), pass
  /// [skipDownload] to skip the fetch.
  Future<ExtensionSource> install(ExtensionIndexEntry entry) async {
    final dir = await _extensionsDir();
    final apkPath = p.join(dir.path, '${entry.pkg}.apk');

    final apkFile = File(apkPath);
    if (!apkFile.existsSync()) {
      await _downloadApk(entry.apkUrl, apkPath);
    }

    final desc = await _keiyoushi.loadExtension(apkPath: apkPath);
    final id = (desc['id'] as String?) ?? entry.pkg;
    final src = ExtensionSource(
      id: id,
      name: (desc['name'] as String?) ?? entry.name,
      version: entry.version,
      lang: (desc['lang'] as String?) ?? entry.lang,
      apkPath: apkPath,
      className: (desc['className'] as String?) ?? '',
      iconUrl: null,
      isInstalled: true,
    );
    await _db.insertExtensionSource(src);
    return src;
  }

  /// Remove a previously installed extension: drop the row, unload the
  /// native classloader, and delete the APK.
  Future<void> uninstall(ExtensionSource src) async {
    await _db.deleteExtensionSource(src.id);
    try {
      await _keiyoushi.unloadExtension(src.id);
    } catch (_) {
      // Source might not be loaded in this session — fine.
    }
    try {
      final f = File(src.apkPath);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Filesystem hiccup — not worth blocking the uninstall.
    }
  }

  // -- Listing installed ------------------------------------------------

  Future<List<ExtensionSource>> listInstalled() => _db.getInstalledExtensions();

  // -- Boot: re-load everything from DB ---------------------------------

  /// On app start, re-mount every extension the user previously
  /// installed so the native side has them registered.
  Future<void> reloadAll() async {
    final installed = await listInstalled();
    for (final src in installed) {
      if (!File(src.apkPath).existsSync()) {
        // APK was deleted out from under us — drop the row.
        await _db.deleteExtensionSource(src.id);
        continue;
      }
      try {
        await _keiyoushi.loadExtension(
          apkPath: src.apkPath,
          className: src.className.isEmpty ? null : src.className,
        );
      } catch (_) {
        // APK on disk but the loader rejected it (corrupt / signature
        // mismatch). Leave the row; user can uninstall it from the UI.
      }
    }
  }

  // -- Internals --------------------------------------------------------

  Future<Directory> _extensionsDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'extensions'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<void> _downloadApk(String url, String destPath) async {
    final bytes = await http.get(Uri.parse(url)).then((r) => r.bodyBytes);
    await File(destPath).writeAsBytes(bytes);
  }
}

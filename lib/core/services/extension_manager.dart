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

  /// Download an APK, load it via the native bridge, and persist one row per
  /// source in the sources[] array — matching mangayomi's multi-source pattern.
  ///
  /// Each source gets its own DB row with a unique id ("mihon-{sourceId}").
  /// Icon URL is derived from the repo URL and package name as mangayomi does:
  ///   "$repoUrl/icon/${pkg}.png"
  Future<List<ExtensionSource>> install(
    ExtensionIndexEntry entry, {
    required String repoUrl,
  }) async {
    final dir = await _extensionsDir();
    final apkPath = p.join(dir.path, '${entry.pkg}.apk');
    final baseUrl = repoUrl.replaceFirst(RegExp(r'/[^/]*$'), '');
    final resolved = '$baseUrl/apk/${entry.apkUrl}';

    // Download APK
    final apkFile = File(apkPath);
    if (apkFile.existsSync()) {
      try { await Process.run('chmod', ['+w', apkPath]); } catch (_) {}
      try { apkFile.deleteSync(); } catch (_) {}
    }
    await _downloadApk(resolved, apkPath);

    // Load via native bridge to verify the APK works
    await _keiyoushi.loadExtension(
      apkPath: apkPath,
      className: entry.className,
    );

    // Derive icon URL from repo base URL + package name — same as mangayomi
    final iconUrl = '$baseUrl/icon/${entry.pkg}.png';
    final sourceCodeUrl = '$baseUrl/apk/${entry.apkUrl}';

    // Create one DB row per source in the sources[] array
    final sources = <ExtensionSource>[];
    for (final s in entry.sources) {
      final sourceId = s['id']?.toString() ?? entry.pkg;
      final id = 'mihon-$sourceId'; // Same format as mangayomi
      final src = ExtensionSource(
        id: id,
        name: s['name'] as String? ?? entry.name,
        version: entry.version,
        lang: s['lang'] as String? ?? entry.lang,
        apkPath: apkPath,
        className: s['className'] as String? ?? '',
        iconUrl: iconUrl,
        baseUrl: s['baseUrl'] as String?,
        sourceCodeUrl: sourceCodeUrl,
        repoUrl: repoUrl,
      );
      await _db.insertExtensionSource(src);
      sources.add(src);
    }
    return sources;
  }

  /// Remove a previously installed extension and all sources sharing its APK:
  /// drop the rows, unload the native classloader, and delete the APK.
  Future<void> uninstall(ExtensionSource src) async {
    // Remove all DB rows that share this APK path
    final installed = await listInstalled();
    for (final s in installed) {
      if (s.apkPath == src.apkPath) {
        await _db.deleteExtensionSource(s.id);
      }
    }
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

  /// Mark installed sources whose repo no longer lists them as obsolete.
  /// Ported from mangayomi's checkIfSourceIsObsolete().
  Future<void> checkForObsoleteSources(
    List<ExtensionIndexEntry> freshEntries,
    String repoUrl,
  ) async {
    if (freshEntries.isEmpty) return;

    // Build the set of all known source IDs from the fresh index
    final knownIds = <String>{};
    for (final entry in freshEntries) {
      for (final s in entry.sources) {
        final sourceId = s['id']?.toString() ?? entry.pkg;
        knownIds.add('mihon-$sourceId');
      }
    }
    if (knownIds.isEmpty) return;

    // Find all installed sources from this repo
    final installed = await listInstalled();
    final toUpdate = <ExtensionSource>[];
    for (final src in installed) {
      if (src.repoUrl != repoUrl) continue;
      final isNowObsolete = !knownIds.contains(src.id);
      if (src.isObsolete != isNowObsolete) {
        toUpdate.add(ExtensionSource(
          id: src.id,
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
      await _db.insertExtensionSource(s);
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
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    try {
      await Process.run('chmod', ['-R', '+w', dir.path]);
    } catch (_) {}
    return dir;
  }

  Future<void> _downloadApk(String url, String destPath) async {
    final res = await _http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw HttpException('APK download failed: ${res.statusCode} at $url');
    }
    await File(destPath).writeAsBytes(res.bodyBytes);
  }
}

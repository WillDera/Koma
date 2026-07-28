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
import 'keiyoushi_service.dart';

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
    final resolved = '$baseUrl/apk/${entry.apkUrl}';

    final apkFile = File(apkPath);
    if (apkFile.existsSync()) {
      try { await Process.run('chmod', ['+w', apkPath]); } catch (_) {}
      try { apkFile.deleteSync(); } catch (_) {}
    }
    await _downloadApk(resolved, apkPath);

    final iconUrl = '$baseUrl/icon/${entry.pkg}.png';
    final sourceCodeUrl = '$baseUrl/apk/${entry.apkUrl}';

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
      baseUrl: firstSource?['baseUrl'] as String?,
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
    final resolved = '$baseUrl/apk/${entry.apkUrl}';

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
  final list = jsonDecode(body);
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

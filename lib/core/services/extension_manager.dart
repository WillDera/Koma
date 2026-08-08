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
import 'apk_signature_service.dart';
import 'extension_icon_cache.dart';
import 'keiyoushi_service.dart';
import 'trust_extension.dart';

export 'trust_extension.dart' show UntrustedExtensionException;
export 'apk_signature_service.dart' show ApkSigningInfo;

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
      pkg = j['packageName'] as String? ?? j['pkg'] as String? ?? '';
      name = j['name'] as String? ?? pkg ?? 'Unknown';

      String apk;
      if (j['resources'] is Map) {
        final r = j['resources'] as Map;
        apk = (r['apkUrl'] as String?) ?? '';
      } else {
        apk = j['apk'] as String? ?? '';
      }
      apkUrl = apk;

      version = j['versionName'] as String? ?? j['version'] as String? ?? '0';

      if (sources.isNotEmpty) {
        lang =
            sources.first['language'] as String? ??
            sources.first['lang'] as String? ??
            'en';
      } else {
        lang = j['lang'] as String? ?? 'en';
      }

      contentWarning = j['contentWarning'] as String? ?? 'CONTENT_WARNING_SAFE';

      baseUrl =
          j['baseUrl'] as String? ??
          (sources.isNotEmpty
              ? (sources.first['baseUrl'] as String?) ??
                    (sources.first['homeUrl'] as String?)
              : null);
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
  final TrustExtension _trust = TrustExtension();
  final ApkSignatureService _apkSignatures = ApkSignatureService();

  ExtensionManager(this._repos, this._keiyoushi, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  TrustExtension get trust => _trust;

  Future<List<ExtensionRepo>> listRepos() =>
      _repos.extensions.getExtensionRepos();

  Future<void> addRepo({required String name, required String url}) async {
    final signingKey = await _fetchSigningKeyForIndex(url);
    final repo = ExtensionRepo(name: name, url: url, signingKey: signingKey);
    await _repos.extensions.insertExtensionRepo(repo);
    await _refreshTrustFingerprints();
  }

  /// Refresh `signingKey` on all repos from sibling `repo.json` (Mihon store meta).
  Future<void> refreshRepoSigningKeys() async {
    final repos = await listRepos();
    for (final repo in repos) {
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
      pkgName: signing.packageName,
      versionCode: signing.versionCode,
      signatureHash: signing.primarySignature ?? '',
      isActive: true,
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
        id: newSourceId,
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

        await _repos.extensions.insertExtensionSource(
          match.copyWith(versionLast: entry.version),
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
        ExtensionIndexEntry? match;
        for (final e in entries) {
          if (src.className.isNotEmpty && e.className == src.className) {
            match = e;
            break;
          }
        }
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

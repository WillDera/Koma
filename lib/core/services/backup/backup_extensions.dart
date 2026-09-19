import '../../models/extension_index_entry.dart';
import '../../models/extension_repo.dart';
import '../../models/extension_source.dart';
import '../../repositories/repositories.dart';
import '../extension_manager.dart';

class ExtensionRestoreStats {
  const ExtensionRestoreStats({
    this.restored = 0,
    this.installed = 0,
    this.missing = const [],
  });

  /// JS/Dart sources written from backup `source_code`.
  final int restored;

  /// Mihon (and JS-without-body) sources fetched from a repo index.
  final int installed;
  final List<String> missing;
}

/// Drop device-local APK paths; keep catalog identity for reinstall.
Map<String, dynamic> extensionToBackupJson(ExtensionSource src) {
  final json = src.toJson();
  json['apk_path'] = '';
  return json;
}

Future<ExtensionRestoreStats> restoreBackupExtensions({
  required Repositories repos,
  required ExtensionManager? manager,
  required List<dynamic> rawList,
}) async {
  var restored = 0;
  var installed = 0;
  final missing = <String>[];

  for (final raw in rawList) {
    if (raw is! Map) continue;
    final src = ExtensionSource.fromJson(Map<String, dynamic>.from(raw));
    if (src.itemType == 'anime') continue;
    if (src.sourceId.isEmpty && src.name.isEmpty) continue;

    final have = await _existing(repos, src);
    if (have != null) continue;

    if ((src.isJs || src.isDart) && src.sourceCode.isNotEmpty) {
      await repos.extensions.insertExtensionSource(src.copyWith(apkPath: ''));
      restored++;
      continue;
    }

    if (manager == null) {
      missing.add(_label(src));
      continue;
    }
    try {
      await _installFromCatalog(manager, src);
      installed++;
    } catch (_) {
      missing.add(_label(src));
    }
  }

  return ExtensionRestoreStats(
    restored: restored,
    installed: installed,
    missing: missing,
  );
}

Future<ExtensionSource?> _existing(
  Repositories repos,
  ExtensionSource src,
) async {
  if (src.sourceId.isNotEmpty) {
    final byId = await repos.extensions.getBySourceId(src.sourceId);
    if (byId != null) return byId;
  }
  if (src.id.isNotEmpty && src.id != src.sourceId) {
    final byLegacy = await repos.extensions.getBySourceId(src.id);
    if (byLegacy != null) return byLegacy;
  }
  final installed = await repos.extensions.getInstalledExtensions();
  final needle = src.name.trim().toLowerCase();
  if (needle.isEmpty) return null;
  for (final e in installed) {
    if (e.name.trim().toLowerCase() == needle) return e;
  }
  return null;
}

Future<void> _installFromCatalog(
  ExtensionManager mgr,
  ExtensionSource src,
) async {
  final allRepos = await mgr.listRepos();
  if (allRepos.isEmpty) {
    throw StateError('no repos');
  }
  final preferred = src.repoUrl?.trim() ?? '';
  final ordered = <ExtensionRepo>[
    ...allRepos.where((r) => preferred.isNotEmpty && r.url == preferred),
    ...allRepos.where((r) => r.enabled && r.url != preferred),
    ...allRepos.where((r) => !r.enabled && r.url != preferred),
  ];

  for (final repo in ordered) {
    final List<ExtensionIndexEntry> entries;
    try {
      entries = await mgr.fetchIndex(repo);
    } catch (_) {
      continue;
    }
    final match = _matchCatalog(entries, src);
    if (match == null) continue;
    await mgr.install(match, repoUrl: repo.url);
    return;
  }
  throw StateError('catalog miss: ${src.name}');
}

ExtensionIndexEntry? _matchCatalog(
  List<ExtensionIndexEntry> entries,
  ExtensionSource src,
) {
  final pkg = src.pkgName.trim();
  final className = src.className.trim();
  final name = src.name.trim().toLowerCase();
  for (final e in entries) {
    if (pkg.isNotEmpty &&
        (e.pkg == pkg || e.pkg == src.sourceId || e.pkg == src.id)) {
      return e;
    }
    if (className.isNotEmpty && e.className == className) return e;
  }
  if (name.isNotEmpty) {
    for (final e in entries) {
      if (e.name.trim().toLowerCase() == name) return e;
    }
  }
  return null;
}

String _label(ExtensionSource src) {
  if (src.name.trim().isNotEmpty) return src.name.trim();
  if (src.sourceId.isNotEmpty) return src.sourceId;
  return src.id;
}

String resolveBackupSourceId(
  List<ExtensionSource> installed,
  String backupId, {
  String? sourceName,
}) {
  if (backupId.isEmpty && (sourceName == null || sourceName.isEmpty)) {
    return backupId;
  }
  for (final ext in installed) {
    if (ext.sourceId == backupId || ext.id == backupId) {
      return ext.sourceId;
    }
  }
  if (sourceName != null && sourceName.isNotEmpty) {
    final needle = sourceName.trim().toLowerCase();
    for (final ext in installed) {
      if (ext.name.trim().toLowerCase() == needle) return ext.sourceId;
    }
  }
  return backupId;
}

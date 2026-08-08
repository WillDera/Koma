import 'dart:async';

import 'package:isar_community/isar.dart';

import '../isar/collections/extension_repo.dart' as i;
import '../isar/collections/extension_source.dart' as i;
import '../models/extension_repo.dart';
import '../models/extension_source.dart';

/// Extension sources (Keiyoushi APKs / future JS) + repos (index URLs).
///
/// Mirrors [ExtensionManager]'s data layer but as a plain repository —
/// the manager class in `core/services/extension_manager.dart` will be
/// refactored in PHASE 2/10 to consume this directly via Riverpod.
class ExtensionRepository {
  final Isar _isar;
  ExtensionRepository(this._isar);

  // ── Sources: Future API ────────────────────────────────────────────

  Future<List<ExtensionSource>> getInstalledExtensions() async {
    final rows = await _isar.extensionSources
        .where()
        .sortByCreatedAtDesc()
        .findAll();
    return rows.map(_srcToModel).toList(growable: false);
  }

  Future<ExtensionSource?> getBySourceId(String sourceId) async {
    final row = await _isar.extensionSources.getBySourceId(sourceId);
    return row == null ? null : _srcToModel(row);
  }

  Future<void> insertExtensionSource(ExtensionSource src) async {
    await _isar.writeTxn(() => _isar.extensionSources.put(_srcFromModel(src)));
  }

  Future<void> deleteExtensionSource(String sourceId) async {
    await _isar.writeTxn(() async {
      // sourceId is the logical ID (String); the Isar row PK is auto-int.
      final row = await _isar.extensionSources.getBySourceId(sourceId);
      if (row != null) {
        await _isar.extensionSources.delete(row.id ?? 0);
      }
    });
  }

  // ── Sources: Stream API ────────────────────────────────────────────

  Stream<List<ExtensionSource>> watchInstalled({bool fireImmediately = true}) {
    return _isar.extensionSources
        .where()
        .sortByCreatedAtDesc()
        .watch(fireImmediately: fireImmediately)
        .map((rows) => rows.map(_srcToModel).toList());
  }

  // ── Repos ──────────────────────────────────────────────────────────

  Future<List<ExtensionRepo>> getExtensionRepos() async {
    final rows = await _isar.extensionRepos
        .where()
        .sortByCreatedAtDesc()
        .findAll();
    return rows.map(_repoToModel).toList(growable: false);
  }

  Future<int> insertExtensionRepo(ExtensionRepo repo) async {
    return _isar.writeTxn(() => _isar.extensionRepos.put(_repoFromModel(repo)));
  }

  Future<void> deleteExtensionRepo(int id) async {
    await _isar.writeTxn(() => _isar.extensionRepos.delete(id));
  }

  Stream<List<ExtensionRepo>> watchRepos({bool fireImmediately = true}) {
    return _isar.extensionRepos
        .where()
        .sortByCreatedAtDesc()
        .watch(fireImmediately: fireImmediately)
        .map((rows) => rows.map(_repoToModel).toList());
  }

  // ── Conversions ────────────────────────────────────────────────────

  static ExtensionSource _srcToModel(i.ExtensionSource s) => ExtensionSource(
    id: s.sourceId,
    sourceId: s.sourceId, // logical ID is what callers expect
    name: s.name,
    version: s.version,
    versionLast: s.versionLast,
    lang: s.lang,
    apkPath: s.apkPath,
    className: s.className,
    iconUrl: s.iconUrl,
    baseUrl: s.baseUrl,
    sourceCodeUrl: s.sourceCodeUrl,
    repoUrl: s.repoUrl,
    pkgName: s.pkgName,
    versionCode: s.versionCode,
    signatureHash: s.signatureHash,
    isInstalled: s.isInstalled,
    isActive: s.isActive,
    isNsfw: s.isNsfw,
    isPinned: s.isPinned,
    isObsolete: s.isObsolete,
    createdAt: s.createdAt,
    updatedAt: s.updatedAt,
  );

  static i.ExtensionSource _srcFromModel(ExtensionSource s) =>
      i.ExtensionSource(
        // Preserve the Isar row PK when updating (id != 0), else let
        // Isar autoIncrement. sourceId is always set from the model's id.
        sourceId: s.id,
        id: int.tryParse(s.id),
        name: s.name,
        version: s.version,
        versionLast: s.versionLast,
        lang: s.lang,
        apkPath: s.apkPath,
        className: s.className,
        iconUrl: s.iconUrl,
        baseUrl: s.baseUrl,
        sourceCodeUrl: s.sourceCodeUrl,
        repoUrl: s.repoUrl,
        pkgName: s.pkgName,
        versionCode: s.versionCode,
        signatureHash: s.signatureHash,
        isInstalled: s.isInstalled,
        isActive: s.isActive,
        isNsfw: s.isNsfw,
        isPinned: s.isPinned,
        isObsolete: s.isObsolete,
        sourceCodeLanguage: 'mihon',
        createdAt: s.createdAt,
        updatedAt: s.updatedAt,
      );

  static ExtensionRepo _repoToModel(i.ExtensionRepo r) => ExtensionRepo(
    id: r.id ?? 0,
    name: r.name,
    url: r.url,
    enabled: r.enabled,
    createdAt: r.createdAt,
    signingKey: r.signingKey,
  );

  static i.ExtensionRepo _repoFromModel(ExtensionRepo r) => i.ExtensionRepo(
    id: r.id == 0 ? Isar.autoIncrement : r.id,
    name: r.name,
    url: r.url,
    enabled: r.enabled,
    createdAt: r.createdAt,
    signingKey: r.signingKey,
  );
}

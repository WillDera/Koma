import '../models/extension_source.dart';
import '../repositories/repositories.dart';
import '../../eval/models/m_source.dart';

/// Resolve any source identifier (hex `sourceId`, legacy Mihon numeric `id`)
/// to an installed [ExtensionSource], then build language-aware [MSource].
Future<ExtensionSource?> findInstalledExtension(
  Repositories repos,
  String sourceId,
) async {
  final installed = await repos.extensions.getInstalledExtensions();
  for (final ext in installed) {
    if (ext.sourceId == sourceId || ext.id == sourceId) return ext;
  }
  return null;
}

/// Prefer DB-backed [MSource] (includes JS `sourceCode`). Falls back to a
/// Mihon stub when the extension row is missing so legacy callers still run.
Future<MSource> resolveExtensionMSource(
  Repositories repos,
  String sourceId, {
  String? name,
  String? baseUrl,
  String? lang,
}) async {
  final ext = await findInstalledExtension(repos, sourceId);
  if (ext != null) return MSource.fromExtensionSource(ext);
  return MSource(
    id: sourceId,
    sourceId: sourceId,
    name: name ?? '',
    lang: lang ?? 'en',
    baseUrl: baseUrl ?? '',
    sourceType: SourceType.mihon,
  );
}

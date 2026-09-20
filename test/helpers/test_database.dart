import 'dart:ffi';
import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:koma/core/isar/isar.dart';
import 'package:koma/core/repositories/repositories.dart';
import 'package:koma/core/services/source_pref_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Point Isar at the native library shipped in isar_community_flutter_libs.
///
/// Flutter tests run on the host VM without the plugin bundling step, so the
/// dylib is never copied next to the test binary and `Isar.open` fails with a
/// dlopen error. Resolving it out of the pub cache is the standard workaround.
///
/// Safe to call repeatedly — Isar ignores an already-initialized core.
Future<void> initIsarCoreForTests() async {
  if (_initialized) return;
  final cacheRoot = Platform.environment['PUB_CACHE'] ??
      (Platform.environment['HOME'] != null
          ? '${Platform.environment['HOME']}/.pub-cache'
          : null);
  if (cacheRoot == null) return;
  final lib = File(
    '$cacheRoot/hosted/pub.dev/'
    'isar_community_flutter_libs-3.3.2/${_platformDir()}/${_libName()}',
  );
  if (!lib.existsSync()) return;
  await Isar.initializeIsarCore(libraries: {Abi.current(): lib.path});
  _initialized = true;
}

bool _initialized = false;
Directory? _tmpDocs;

String _platformDir() {
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  return 'linux';
}

String _libName() {
  if (Platform.isMacOS) return 'libisar.dylib';
  if (Platform.isWindows) return 'isar.dll';
  return 'libisar.so';
}

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.docs);
  final String docs;

  @override
  Future<String?> getApplicationDocumentsPath() async => docs;
}

Future<Repositories> createTestRepositories() async {
  await initIsarCoreForTests();
  _tmpDocs ??= await Directory.systemTemp.createTemp('koma_test_docs_');
  PathProviderPlatform.instance = _FakePathProvider(_tmpDocs!.path);
  final isar = await openIsarInMemory();
  SourcePrefStore.bind(isar);
  return Repositories(isar);
}

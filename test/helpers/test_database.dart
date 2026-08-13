import 'dart:ffi';
import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:koma/core/isar/isar.dart';
import 'package:koma/core/repositories/repositories.dart';

/// Point Isar at the native library shipped in isar_community_flutter_libs.
///
/// Flutter tests run on the host VM without the plugin bundling step, so the
/// dylib is never copied next to the test binary and `Isar.open` fails with a
/// dlopen error. Resolving it out of the pub cache is the standard workaround.
///
/// Safe to call repeatedly — Isar ignores an already-initialized core.
Future<void> initIsarCoreForTests() async {
  if (_initialized) return;
  final home = Platform.environment['HOME'];
  if (home == null) return;
  final lib = File(
    '$home/.pub-cache/hosted/pub.dev/'
    'isar_community_flutter_libs-3.3.2/${_platformDir()}/${_libName()}',
  );
  if (!lib.existsSync()) return;
  await Isar.initializeIsarCore(libraries: {Abi.current(): lib.path});
  _initialized = true;
}

bool _initialized = false;

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

Future<Repositories> createTestRepositories() async {
  await initIsarCoreForTests();
  final isar = await openIsarInMemory();
  return Repositories(isar);
}

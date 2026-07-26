// PHASE 5 SPIKE — Dart FFI binding for libspike.
//
// Demonstrates the full chain: build hook compiles spike.cpp → Flutter ships
// the resulting shared library as a code asset named "spike.dart" → this
// file's library is what `assetName` references → at runtime we
// `DynamicLibrary.open` it by name (Flutter rewrites the name to a per-
// platform file at build time, so the same Dart call works on Android,
// iOS, macOS, etc.) → resolve `spike_add` and call it.

import 'dart:ffi';
import 'dart:io' show Platform;

typedef _SpikeAddNative = Int32 Function(Int32 a, Int32 b);
typedef SpikeAddDart = int Function(int a, int b);

class SpikeLib {
  SpikeLib._() {
    final String name;
    if (Platform.isAndroid || Platform.isLinux) {
      name = 'libspike.so';
    } else if (Platform.isIOS || Platform.isMacOS) {
      name = 'spike.framework/spike';
    } else if (Platform.isWindows) {
      name = 'spike.dll';
    } else {
      throw UnsupportedError('spike: unsupported platform ${Platform.operatingSystem}');
    }
    _dylib = DynamicLibrary.open(name);
    _spikeAdd = _dylib
        .lookupFunction<_SpikeAddNative, SpikeAddDart>('spike_add');
  }

  static final SpikeLib instance = SpikeLib._();

  late final DynamicLibrary _dylib;
  late final SpikeAddDart _spikeAdd;

  /// Returns a + b (computed in native code).
  /// Used by the build-hook smoke test: `expect(SpikeLib.instance.add(2, 3), 5)`.
  int add(int a, int b) => _spikeAdd(a, b);

  /// Sanity self-check callable from anywhere. Returns true iff the native
  /// lib loaded, the symbol resolved, and 2+3==5 came back from C++.
  bool selfTest() {
    try {
      return add(2, 3) == 5;
    } catch (_) {
      return false;
    }
  }
}

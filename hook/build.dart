// PHASE 5 SPIKE build hook (mirrors mangayomi/hook/build.dart exactly).
//
// Flutter invokes this at `flutter build` time. CBuilder compiles the listed
// source files via the platform-appropriate toolchain (NDK clanging on
// Android, clang on macOS/iOS/Linux, MSVC on Windows) and emits the
// resulting shared library as a "code asset" — packaged into the APK on
// Android, the .app bundle on iOS, and discovered at runtime via
// `DynamicLibrary.open("libspike.dylib")` on macOS, etc.
//
// assetName names *which Dart file* is allowed to load the asset, so Dart's
// tree-shaker can prune unused native assets. The same convention will be
// used by the full port: `assetName: 'subsampling_scale_image_view.dart'`.

import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final builder = CBuilder.library(
      name: 'spike',
      assetName: 'spike.dart',
      sources: ['lib/ffi/spike.cpp'],
      includes: ['lib/ffi/'],
      // No frameworks for the spike — the full port adds ImageIO /
      // CoreGraphics / CoreFoundation for iOS/macOS exactly like mangayomi.
      flags: [],
    );

    await builder.run(input: input, output: output);
  });
}

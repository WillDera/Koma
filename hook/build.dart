// PHASE 5 build hook — compiles the subsampling_scale_image_view native
// image decoder (image_decoder.cpp) via Flutter's `native_toolchain_c`.
//
// Faithful copy of mangayomi/hook/build.dart. The produced
// libsubsampling_scale_image_view.so (Android) / .framework (Apple) is shipped
// as a code asset and opened at runtime via `DynamicLibrary.open` in
// `ffi_image_decoder.dart`.
//
// On iOS/macOS, ImageIO + CoreGraphics + CoreFoundation are linked for native
// region decoding. On Android, the NDK's `libjnigraphics.so`
// (AImageDecoder_*) is loaded dynamically at runtime by the C++ code itself,
// so no extra link flags are needed here.

import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:code_assets/code_assets.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final builder = CBuilder.library(
      name: 'subsampling_scale_image_view',
      assetName: 'subsampling_scale_image_view.dart',
      sources: ['lib/ffi/image_decoder.cpp'],
      includes: ['lib/ffi/'],
      flags: [
        if (input.config.code.targetOS == OS.iOS ||
            input.config.code.targetOS == OS.macOS) ...[
          '-framework',
          'CoreFoundation',
          '-framework',
          'CoreGraphics',
          '-framework',
          'ImageIO',
        ],
      ],
    );

    await builder.run(input: input, output: output);
  });
}

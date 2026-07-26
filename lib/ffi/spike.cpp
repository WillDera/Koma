// PHASE 5 SPIKE
// Implementation of [spike_add]. Compiled by `native_toolchain_c` via the
// Flutter build hook in `hook/build.dart`. The produced libsubstash_spike.so
// (or .dylib / .dll / .framework) is shipped as a code asset and opened via
// `package:ffi`'s `DynamicLibrary.open` on Android (and other targets).
//
// On Android the C++ runtime ships in the platform; nothing extra is linked.
// The full port will link libjpeg-turbo (Android NDK bundled) and platform
// image codecs (ImageIO on Apple), but the spike intentionally has zero
// external deps to isolate build-hook/toolchain risk from library risk.

#include "spike.h"

int32_t spike_add(int32_t a, int32_t b) {
  return a + b;
}

// PHASE 5 SPIKE
// Trivial C++ library compiled via Flutter's `native_toolchain_c` build hook.
// Existence of this .so on the Android target device proves the build hook
// works under the pinned JDK 25 / AGP 8.7.3 toolchain before we commit to
// the full 1213-LOC subsampling_scale_image_view image_decoder.cpp port.
//
// Uses the same `__attribute__((visibility("default")))` export pattern that
// mangayomi's image_decoder.h defines, so the spike validates the exact
// symbol-export mechanism the real port will rely on for `init_decoder` /
// `decode_region` / `free_decoder`.

#ifndef LNSTASH_SPIKE_H_
#define LNSTASH_SPIKE_H_

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

#ifdef _WIN32
#define SPIKE_EXPORT __declspec(dllexport)
#else
#define SPIKE_EXPORT __attribute__((visibility("default")))
#endif

// Returns a + b. Trivial ABI for the build-hook smoke test.
SPIKE_EXPORT int32_t spike_add(int32_t a, int32_t b);

#ifdef __cplusplus
}
#endif

#endif  // LNSTASH_SPIKE_H_

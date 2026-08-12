# Piper (libpiper) for Koma Android

On-device Piper TTS via [piper1-gpl](https://github.com/OHF-Voice/piper1-gpl) `libpiper` (GPL-3.0).

## Layout

- `libpiper/` — vendored `piper.cpp` + headers from piper1-gpl (pinned manually).
- `onnxruntime/` — download cache for the onnxruntime AAR (gitignored, created by CMake).
- `../app/src/main/cpp/` — JNI bridge (`koma_piper` shared library).
- `../app/src/main/assets/piper/espeak-ng-data/` — phonemizer data (required at runtime; not a voice model).

Voice models (`.onnx` + `.onnx.json`) are **user-imported** in the app, not shipped here.

## Build requirements

- Android NDK (via Flutter `ndkVersion`)
- CMake 3.22+
- Network on the first native build, to fetch espeak-ng and the onnxruntime AAR

`koma_piper` is built for `arm64-v8a` only.

## onnxruntime

The `onnxruntime-android` AAR ships no prefab metadata, so `find_package(onnxruntime)`
cannot resolve it. Instead, `../app/src/main/cpp/CMakeLists.txt` downloads the AAR from
Maven Central into `onnxruntime/`, unpacks it, and links against
`jni/<abi>/libonnxruntime.so` using the bundled `headers/`.

The `.so` that actually ships in the APK comes from the Gradle
`com.microsoft.onnxruntime:onnxruntime-android` dependency. **`ONNXRUNTIME_VERSION` in
CMakeLists.txt must match that Gradle coordinate**, otherwise the app links against one
version and loads another.

## Building espeak-ng

`espeak-ng` is cross-compiled as a static library via `ExternalProject` at the pin used by
piper1-gpl. Intonation/phoneme data compilation is disabled (`COMPILE_INTONATIONS=OFF`)
because it requires a host `espeak-ng` binary that does not exist when cross-compiling;
the data is shipped prebuilt in app assets instead.

## Refreshing libpiper source

```sh
git clone --depth 1 https://github.com/OHF-Voice/piper1-gpl.git /tmp/piper1-gpl
cp /tmp/piper1-gpl/libpiper/src/piper.cpp libpiper/src/
cp -R /tmp/piper1-gpl/libpiper/include/* libpiper/include/
cp /tmp/piper1-gpl/COPYING COPYING
```

## espeak-ng-data assets

Bundled from a Piper release tarball (`piper_linux_aarch64`) for phonemization. To refresh:

```sh
curl -fsL -o /tmp/piper.tar.gz \
  https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_linux_aarch64.tar.gz
tar -xzf /tmp/piper.tar.gz -C /tmp piper/espeak-ng-data
cp -R /tmp/piper/espeak-ng-data ../app/src/main/assets/piper/espeak-ng-data
```

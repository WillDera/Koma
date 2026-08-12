# Piper (libpiper) for Koma Android

On-device Piper TTS via [piper1-gpl](https://github.com/OHF-Voice/piper1-gpl) `libpiper` (GPL-3.0).

## Layout

- `libpiper/` — vendored `piper.cpp` + headers from piper1-gpl (pinned manually).
- `../app/src/main/cpp/` — JNI bridge (`koma_piper` shared library).
- `../app/src/main/assets/piper/espeak-ng-data/` — phonemizer data (required at runtime; not a voice model).

Voice models (`.onnx` + `.onnx.json`) are **user-imported** in the app, not shipped here.

## Build requirements

- Android NDK (via Flutter `ndkVersion`)
- CMake 3.22+
- Network on first native build (ExternalProject fetches espeak-ng)

Gradle links `com.microsoft.onnxruntime:onnxruntime-android` via prefab and builds `koma_piper` for `arm64-v8a`.

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

# Third-party notices

Koma includes third-party software. Each component remains under its own
license and copyright. This file summarizes what a typical Koma Android
release ships with the APK.

Koma itself is licensed under the GNU General Public License version 3 or
later (GPL-3.0-or-later). See [LICENSE](LICENSE).

## Piper (libpiper)

- **Source:** [OHF-Voice/piper1-gpl](https://github.com/OHF-Voice/piper1-gpl)
- **Location:** [`android/piper/`](android/piper/) (vendored `libpiper`)
- **License:** GPL-3.0 (see [`android/piper/COPYING`](android/piper/COPYING))
- **Copyright:** OHF-Voice and contributors

On-device neural TTS via a native JNI bridge (`koma_piper`).

## ONNX Runtime

- **Package:** `com.microsoft.onnxruntime:onnxruntime-android:1.23.0`
- **Also pinned in:** [`android/app/src/main/cpp/CMakeLists.txt`](android/app/src/main/cpp/CMakeLists.txt) (`ONNXRUNTIME_VERSION`)
- **License:** MIT
- **Copyright:** Microsoft Corporation

MIT-licensed code may be included in a GPL project; ONNX Runtime is not
relicensed as GPL.

## eSpeak NG

- **Repository:** [espeak-ng/espeak-ng](https://github.com/espeak-ng/espeak-ng)
- **Build pin:** Git tag `212928b394a96e8fd2096616bfd54e17845c48f6` (CMake `ExternalProject`)
- **Runtime data:** [`android/app/src/main/assets/piper/espeak-ng-data/`](android/app/src/main/assets/piper/espeak-ng-data/)
- **License:** GPL-3.0-or-later (upstream)
- **Copyright:** eSpeak NG contributors

Used for phonemization with Piper. The static library is built at the pin
above; phoneme data is shipped as app assets (not a voice model).

## Flutter and pub packages

Dart/Flutter dependencies are listed in [`pubspec.yaml`](pubspec.yaml). Each
package retains its own license (commonly BSD-3-Clause, MIT, Apache-2.0, or
similar). See **Settings → About → Open source licenses** in the app for
in-app notices.

## Piper voice models

Piper voice models (`.onnx` and `.onnx.json`) are **user-imported**. Koma does
not distribute them. They are third-party works under their own licenses and
are **not** covered by Koma’s GPL license grant.

# Third-party notices

Koma includes third-party software. Each component remains under its own
license and copyright. This file summarizes what a typical Koma Android
release ships with the APK.

Koma itself is licensed under the MIT License. See [LICENSE](LICENSE).

## Flutter and pub packages

Dart/Flutter dependencies are listed in [`pubspec.yaml`](pubspec.yaml). Each
package retains its own license (commonly BSD-3-Clause, MIT, Apache-2.0, or
similar). See **Settings → About → Open source licenses** in the app for
in-app notices.

## Native / build tooling

- **Cargokit** ([`rust_builder/cargokit/`](rust_builder/cargokit/)) — MIT and
  Apache-2.0 dual license; see [`rust_builder/cargokit/LICENSE`](rust_builder/cargokit/LICENSE).
  Copyright 2022 Matej Knopp.

## TTS

On-device speech uses the device TTS engine and optional Edge TTS networking.
No Piper voice models or eSpeak NG data are shipped in the APK.

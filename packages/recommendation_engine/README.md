# How recommendations stay out of the public tree

Public repo ships `packages/recommendation_engine` — same package name and
API as the private engine, but `recommend()` always returns empty (`stub`
diagnostic). Host adapters and UI live under `lib/core/recommendations/` and
`lib/widgets/recommendations_rail.dart`.

Private / your release builds:

1. Make [recommendation-engine](https://github.com/just-nibble/recommendation-engine) private.
2. Clone into a gitignored path:
   `git clone <url> packages/recommendation_engine_private`
3. Use `pubspec_overrides.yaml` (gitignored; see `*.example`) pointing at that path.
4. `flutter pub get` — ranking is compiled into your APK only.

Public clones never get the private folder or overrides; they keep the stub and
see no recommendation rails (empty results hide the UI).

## Versioning

Always update app version after each code change. Bump the patch number in both `pubspec.yaml` and `lib/features/settings/settings_screen.dart` after any file change. Use semVer: patch for fixes/minor tweaks, minor for new features, major for breaking changes.

## Build / Toolchain

- **Android Gradle:** 9.1.0 / AGP 8.7.3 / Kotlin 2.4.10 / `compileSdk` follows Flutter's default (currently 35/36). The AGP/Kotlin versions will be dropped by Flutter soon — bump when convenient.
- **JDK:** Build with **JDK 25** (`/Library/Java/JavaVirtualMachines/jdk-25.jdk/Contents/Home`). JDK 26 hits a `jlink` bug against `android-35/core-for-system-modules.jar` and fails inside the `flutter_plugin_android_lifecycle` / `jni` plugin chain before `:app:compileDebugKotlin` even runs. Pinned via `flutter config --jdk-dir=...` (sticky).
- **Source/target compat:** Java 17 in `android/app/build.gradle.kts`. Don't change it.
- **Keystore:** `android/app/stashreader-debug.keystore` is committed and referenced by both debug + release `signingConfigs`. Don't regenerate.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).

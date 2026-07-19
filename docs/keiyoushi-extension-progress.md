# Keiyoushi Extension Installation — Progress & Current Issue

## Goal
Enable the Flutter app to install and load Keiyoushi/Mihon extension APKs at runtime using `DexClassLoader` on Android 14+.

## What We Built
- **Dart side (`lib/core/services/extension_manager.dart`)**: fetches `index.min.json`, downloads APKs, and calls the Kotlin bridge.
- **Kotlin bridge (`KeiyoushiMethodChannel.kt` → `KeiyoushiEngine.kt` → `ExtensionLoader.kt`)**: receives `apkPath` + `className`, marks files read-only for Android 14 DCL, and loads the class via `DexClassLoader`.
- **Tachiyomi stub library** (under `android/app/src/main/kotlin/eu/kanade/tachiyomi/`):
  - `source/Source.kt`
  - `source/SourceFactory.kt`
  - `source/ConfigurableSource.kt`
  - `source/model/Models.kt`
  - `source/model/Filter.kt`
  - `source/online/HttpSource.kt`
  - `source/online/ParsedHttpSource.kt`
  - `network/NetworkHelper.kt`
  - `util/ResponseExtensions.kt`

These stubs satisfy the extension APKs’ references to `eu.kanade.tachiyomi.*` classes.

## Issues Encountered (chronological)

### 1. Writable dex file / `SecurityException`
**Fix**: `ExtensionLoader.kt` now marks the APK and optimized-dex directory read-only before `DexClassLoader` opens them.

### 2. Relative class names (`ClassNotFoundException: ".ExtensionGenerated"`)
**Fix**: `ExtensionLoader.kt` resolves class names starting with `.` by prepending the APK’s manifest package name.

### 3. Missing `SourceFactory` (`NoClassDefFoundError`)
**Fix**: Added `SourceFactory.kt` stub.

### 4. Duplicate `Requests.kt` conflicting with `NetworkHelper.kt`
**Fix**: Deleted the duplicate `Requests.kt` file.

### 5. `ExtensionGenerated does not implement Source`
**Current blocker**.

## Current Issue: `SourceFactory` vs `Source`

**Error**:
```
IllegalArgumentException: eu.kanade.tachiyomi.extension.all.mangadex.ExtensionGenerated does not implement Source
```

**Root cause**: Multi-source extensions (e.g. MangaDex, MangaFire) expose many sources per APK. In the upstream Mihon/Keiyoushi build system, the generated `ExtensionGenerated` class typically implements **`SourceFactory`**, not `Source` directly. Our `ExtensionLoader` was checking `Source::class.java.isAssignableFrom(clazz)` and rejecting classes that only implement `SourceFactory`.

**Partial fix applied**: `ExtensionLoader.instantiate()` now detects `SourceFactory` implementations, calls `createSources()`, and returns the first source. The `Source` interface was also expanded with `baseUrl` and `supportsLatest`.

**Remaining problem**: Real extension APKs still fail at load time. The suspicion is that the app’s stub `Source`/`HttpSource` interfaces are too minimal compared to the real tachiyomi/mihon APIs the extensions were compiled against. Extensions reference additional types (`SourceFactory`, `ConfigurableSource`, filter model classes, coroutine-based suspend APIs, etc.). If any required class is missing or has an incompatible shape, class loading or instantiation will fail.

**Evidence gathered**:
- Keiyoushi `index.min.json` does **not** contain a `className` field; the class name is read from the APK manifest meta-data `tachiyomi.extension.class`.
- Extensions like MangaDex and MangaFire do **not** ship that meta-data in their manifests (or it is not readable by our extractor).
- Extensions compiled against the real tachiyomi source-api expect many more members than our stubs provide.

## Next Steps
1. **Use the real stub library** (`mihonapp/tachiyomix`) instead of hand-written stubs, or otherwise align our stubs with the upstream `Source` API surface.
2. **Verify the actual extension class hierarchy** by decompiling the APK (e.g. `jadx`, `apktool`, or `dex2jar`) to see exactly what the generated class extends/implements.
3. **Confirm the manifest meta-data**: inspect APK manifests with `aapt2 dump xmltree` or a binary XML parser to see whether `tachiyomi.extension.class` is present and what value it contains.
4. **Fix the build environment**: resolve the AGP/JDK 26 / `flutter_plugin_android_lifecycle` `jlink` failure (switch to JDK 17 per `AGENTS.md`, or use `--android-skip-build-dependency-validation`).

## Version
`2.5.8+31`

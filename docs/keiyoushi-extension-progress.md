# Keiyoushi Extension Loading — Progress

## Goal
Enable the Flutter app to install and load Keiyoushi/Mihon extension APKs at runtime on Android 14+.

## Architecture (current)

```
Dart (KeiyoushiService) ──HTTP POST──→ DalvikServer (raw ServerSocket)
                                           │
                                     KeiyoushiEngine
                                           │
                                     ExtensionLoader (DexClassLoader)
                                           │
                                     ExtensionGenerated (reflectively)
```

- **`DalvikServer.kt`**: HTTP server listening on a local port. Receives JSON-RPC requests from Dart, dispatches to `KeiyoushiEngine`, serializes responses as `JsonElement` (never `Any`).
- **`KeiyoushiEngine.kt`**: Manages loaded extensions by source ID, calls `ExtensionLoader`, provides `getPopularManga`/`getMangaDetails`/`getChapterList`/`getPageList` etc. Catches all `Throwable` from extension overrides and returns fallback values (bare `SManga`, empty list).
- **`ExtensionLoader.kt`**: Creates `ChildFirstPathClassLoader` per APK, resolves relative class names, instantiates `Source` objects.
- **Tachiyomi stub library** (`android/app/src/main/kotlin/eu/kanade/tachiyomi/`): `Source`, `HttpSource`, `SManga`, `SChapter`, `Page`, etc.

## Completed

- [x] Extension APK download and install from Keiyoushi repos
- [x] `DexClassLoader` with read-only enforcement for Android 14 DCL
- [x] Relative class name resolution (`.ExtensionGenerated` → FQN)
- [x] `SourceFactory` detection and first-source extraction
- [x] All `catch (e: Exception)` → `catch (e: Throwable)` in server (NPE coverage)
- [x] `_post()` no longer throws on JSON `error` field; `_postChecked()` for operations that must fail
- [x] `KeiyoushiEngine.getMangaDetails` / `getChapterList` — try-catch around `getMangaUpdate`, returns fallback on failure
- [x] `Image.network` → `CustomExtendedNetworkImageProvider` (50 MB memory + 500 MB disk LRU)
- [x] `contentLength` normalized `-1` → `0` for `ImageChunkEvent` assertion
- [x] All `json.encodeToString(mapOf(...))` → `buildJsonObject { put(...) }` / `toJsonObject()` to avoid `Serializer for class 'Any'` crash
- [x] `KeiyoushiMethodChannel.kt` deleted (functionality moved into `DalvikServer` / `MainActivity`)
- [x] Version `2.19.19+149`

## Remaining

- [ ] Stateless per-request APK loading (mangayomi pattern: base64 APK in every POST, temp file per request, no `sourceById` caching)
- [ ] Delete `KeiyoushiEngine.kt` / `ExtensionLoader.kt` if/when functionality fully inlined into `DalvikServer`
- [ ] Verify all `Image.network` remnants replaced (3 locations: `min_subsampling_image_view.dart:50`, `history_screen.dart:355`, `double_page_view.dart:148`)

## Known Issues

- **JDK 26**: `jlink` bug against `android-36/core-for-system-modules.jar` — build with JDK 25. Pinned via `flutter config --jdk-dir=...`.
- **`ExtensionGenerated.getMangaUpdate` is the method override** — fixing `CatalogueSource.kt` interface default is ineffective. Error handling must live in `KeiyoushiEngine.kt` and the Dart client.

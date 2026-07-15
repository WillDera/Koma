# Native Keiyoushi/Tachiyomi Extension Support via DexClassLoader (Android Only)

Add support for reading manga, comics, and manhwa by executing standard [Keiyoushi (Tachiyomi/Mihon) compiled APK extensions](https://github.com/keiyoushi/extensions) directly. Since this application is target-locked to Android, we can leverage Android's native runtime environment to download, load, and execute the actual Kotlin/Java extension bytecode from Keiyoushi APKs.

To prevent friction, we load extensions dynamically via `DexClassLoader` from our app's internal private storage, completely avoiding the need to prompt the user for system-level installation.

## User Review Required

> [!IMPORTANT]
> **This is an Android-exclusive architecture (minor version bump → 2.5.0).** It utilizes:
> - Android `DexClassLoader` to dynamically load uninstalled APK files at runtime.
> - An embedded implementation of the Tachiyomi `source-api` interfaces (`Source`, `HttpSource`, `ParsedHttpSource`, and models) inside the Kotlin source folder (`android/app/src/main/kotlin/`).
> - Native `okhttp3` and `jsoup` dependencies inside the host app Gradle.
> - Android 14 Dynamic Code Loading (DCL) compliance (moving APKs to internal files and marking them read-only before execution).

> [!TIP]
> **Why this is better than JS engines:**
> - 🚀 **Performance:** Native Kotlin/Java code executing on the Android runtime (Dalvik/ART) is significantly faster and uses less memory than running scripts in a sandboxed JavaScript interpreter.
> - 🌐 **Direct Compatibility:** It supports the official Keiyoushi `.apk` extensions exactly as they are built, meaning we get access to their 1000+ high-quality scraping sources without converting them to JS.
> - 🔏 **Zero Installation Dialogs:** By loading uninstalled APK files directly, the user doesn't have to enable "sideloading from unknown sources" or click through system prompts for each extension.

## Open Questions

> [!IMPORTANT]
> 1. **Default Repo:** Should we pre-configure the Keiyoushi extension repo URL (`https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json`) so extensions are instantly browseable, or let the user input it? I recommend pre-configuring it as the default.
> 2. **Navigation Integration:** I recommend integrating manga browsing inside the existing **Discover** tab with a top segmented toggle (Ebooks | Manga) to keep navigation clean.
> 3. **Library Integration:** I recommend displaying manga added from sources inside the same **Library** tab, using filter chips at the top to filter between "All", "Books", and "Manga".

## Proposed Changes

### Component 1: Android Configuration (Gradle)

#### [MODIFY] [android/app/build.gradle](file:///Volumes/thezone/Documents/LNStash/android/app/build.gradle)
Add dependencies required by Tachiyomi extensions:
- `implementation("org.jsoup:jsoup:1.17.2")` — for HTML parsing
- `implementation("com.squareup.okhttp3:okhttp:4.12.0")` — for network calls
- `implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")` — for modern async extension methods

---

### Component 2: Native Android — Tachiyomi Source API Stubs/Implementations

We will create the core classes expected by the extension's bytecode on our JVM classpath under their exact expected package names (`eu.kanade.tachiyomi`).

#### [NEW] `android/app/src/main/kotlin/eu/kanade/tachiyomi/source/Source.kt`
Defines the base `Source` interface.

#### [NEW] `android/app/src/main/kotlin/eu/kanade/tachiyomi/source/online/HttpSource.kt`
The abstract base class for network-based extensions. Handles building standard `okhttp3.Request` headers and exposes the OkHttp client instance.

#### [NEW] `android/app/src/main/kotlin/eu/kanade/tachiyomi/source/online/ParsedHttpSource.kt`
Extends `HttpSource`. Implements `popularMangaParse`, `searchMangaParse`, `latestUpdatesParse`, etc., by parsing HTML using Jsoup selectors and calling abstract methods implemented by the subclass.

#### [NEW] `android/app/src/main/kotlin/eu/kanade/tachiyomi/source/model/Models.kt`
Defines `SManga` (and `SMangaImpl`), `SChapter` (and `SChapterImpl`), `Page`, and `MangasPage` classes/interfaces that carry manga, chapter, and page metadata.

#### [NEW] `android/app/src/main/kotlin/eu/kanade/tachiyomi/network/NetworkHelper.kt`
Provides helper functions like `GET` and `POST` that extensions use to construct OkHttp requests.

#### [NEW] `android/app/src/main/kotlin/eu/kanade/tachiyomi/util/ResponseExtensions.kt`
Provides extension functions like `Response.asJsoup()` which parse the response body into Jsoup Documents.

---

### Component 3: Native Android — DexClassLoader & MethodChannel Bridge

#### [NEW] `android/app/src/main/kotlin/eu/kanade/tachiyomi/extension/ExtensionLoader.kt`
Handles loading uninstalled APKs from internal storage:
1. Copies downloaded APKs to the code cache/files directory.
2. Marks the file as read-only (crucial for Android 14 DCL security).
3. Instantiates `DexClassLoader` with the host classloader as parent.
4. Uses reflection to read the class name from metadata or parses the APK's manifest.
5. Instantiates the subclass of `Source`.

#### [NEW] `android/app/src/main/kotlin/eu/kanade/tachiyomi/extension/KeiyoushiMethodChannel.kt`
The Platform Channel handler that bridges Dart and Kotlin:
- `loadExtension(apkPath, className)`
- `getPopularManga(sourceId, page)`
- `searchManga(sourceId, query, page)`
- `getMangaDetails(sourceId, url)`
- `getChapterList(sourceId, url)`
- `getPageList(sourceId, url)`

---

### Component 4: Database Schema (Dart)

#### [MODIFY] [database.dart](file:///Volumes/thezone/Documents/LNStash/lib/core/database/database.dart)
Add tables to store user library manga, downloaded chapters, and installed sources:
- `manga` — columns for id, name, url, imageUrl, author, artist, description, status, genre, sourceId, inLibrary, and reading status.
- `manga_chapters` — columns for id, mangaId, name, url, scanlator, dateUpload, index, isRead, lastPageRead, and scrollPosition.
- `installed_extensions` — columns for id (package name), name, version, lang, apkPath, className, iconUrl.

#### [MODIFY] [database_service.dart](file:///Volumes/thezone/Documents/LNStash/lib/core/services/database_service.dart)
Add SQLite CRUD operations for manga, manga chapters, and extension sources.

---

### Component 5: Dart Extension Service & Manager

#### [NEW] `lib/core/services/keiyoushi_service.dart`
Exposes the Dart-side interface for interacting with loaded extensions via the MethodChannel.

#### [NEW] `lib/core/services/extension_manager.dart`
Downloads extensions from the Keiyoushi index JSON, stores the APK in the app's internal filesystem, and registers the loaded source with the `KeiyoushiService`.

---

### Component 6: Paged & Webtoon Reader UI (Dart)

#### [NEW] `lib/features/manga_reader/manga_reader_screen.dart`
A dedicated full-screen image viewer supporting:
- **Webtoon Mode (Vertical):** Continuous layout using a scrollable list view with prefetched `CachedNetworkImage` pages.
- **Paged Mode (Horizontal):** Single-page swipe views utilizing pinch-to-zoom controls.
- **Overlay UI:** Double-tap zoom, page/chapter seeker bar, LTR/RTL reading direction toggle, background color settings.
- Auto-advances to the next chapter and tracks read-state progress.

---

### Component 7: Browse, Detail, and Library UIs (Dart)

#### [MODIFY] [discover_screen.dart](file:///Volumes/thezone/Documents/LNStash/lib/features/discover/discover_screen.dart)
Add a segmented control at the top: **Ebooks | Manga**. When **Manga** is selected:
- Lists installed sources.
- Clicking a source loads its popular page.
- Search query runs against the loaded Keiyoushi source.

#### [NEW] `lib/features/manga_detail/manga_detail_screen.dart`
Shows manga cover, title, status, description, genre tags, "Add to Library" button, and list of chapters. Clicking a chapter opens the reader.

#### [NEW] `lib/features/extensions/extensions_screen.dart`
Manage extension repos and installed APKs.

#### [MODIFY] [settings_screen.dart](file:///Volumes/thezone/Documents/LNStash/lib/features/settings/settings_screen.dart)
Add an option to open the "Extensions Manager" and bump version to `2.5.0`.

#### [MODIFY] [library_screen.dart](file:///Volumes/thezone/Documents/LNStash/lib/features/library/library_screen.dart)
Add a "Manga" filter chip and display saved manga.

---

### Component 8: Version Bump

#### [MODIFY] [pubspec.yaml](file:///Volumes/thezone/Documents/LNStash/pubspec.yaml)
Bump `version` to `2.5.0+24`

#### [MODIFY] [settings_screen.dart](file:///Volumes/thezone/Documents/LNStash/lib/features/settings/settings_screen.dart)
Bump version string to `2.5.0`

---

## Verification Plan

### Automated Tests
- Run `flutter test` to ensure no ebook/snippet regression.
- Run `dart analyze lib/` for clean analysis.

### Manual Verification
1. Open Extensions manager → fetch Keiyoushi index → download MangaPill extension.
2. Select MangaPill in Discover → check that popular list pulls and displays manga covers.
3. Search for a title → verify results match.
4. Tap details → verify chapter list is parsed.
5. Tap chapter → verify image reader loads and pages can be read/scrolled.
6. Add to library → verify manga shows up under Library tab with unread chapter count.

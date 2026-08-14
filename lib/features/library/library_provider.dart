import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/models/book.dart';
import '../../core/models/library_category.dart';
import '../../core/models/manga.dart';
import '../../core/providers.dart';
import '../../core/services/background_task.dart';
import '../../core/services/library_update_auto_download.dart';
import '../../core/services/library_update_prefs.dart';
import '../../core/services/library_update_service.dart';
import '../../core/services/notification_service.dart';
import '../../widgets/library_book_card.dart';

/// Immutable state for the library screen.
class LibraryState {
  const LibraryState({
    this.books = const [],
    this.mangas = const [],
    this.categories = const [],
    this.loading = true,
    this.error,
    this.selectedIds = const {},
    this.selectionMode = false,
    this.isGridView = true,
    this.gridColumns = 2,
    this.cardVariant = LibraryCardVariant.grid,
    this.showSourcePills = true,
    this.extensionNames = const {},
    this.newChapters = const {},
  });

  final List<Book> books;
  final List<Manga> mangas;
  final List<LibraryCategory> categories;
  final bool loading;
  final String? error;
  final Set<String> selectedIds;
  final bool selectionMode;
  final bool isGridView;
  final int gridColumns;
  final LibraryCardVariant cardVariant;
  final bool showSourcePills;
  final Map<String, String> extensionNames;

  /// mangaId → count of unopened (new) chapters. Populated by loadBooks.
  final Map<int, int> newChapters;

  int get totalNewChapters => newChapters.values.fold(0, (a, b) => a + b);

  LibraryState copyWith({
    List<Book>? books,
    List<Manga>? mangas,
    List<LibraryCategory>? categories,
    bool? loading,
    String? Function()? error,
    Set<String>? selectedIds,
    bool? selectionMode,
    bool? isGridView,
    int? gridColumns,
    LibraryCardVariant? cardVariant,
    bool? showSourcePills,
    Map<String, String>? extensionNames,
    Map<int, int>? newChapters,
  }) {
    return LibraryState(
      books: books ?? this.books,
      mangas: mangas ?? this.mangas,
      categories: categories ?? this.categories,
      loading: loading ?? this.loading,
      error: error != null ? error() : this.error,
      selectedIds: selectedIds ?? this.selectedIds,
      selectionMode: selectionMode ?? this.selectionMode,
      isGridView: isGridView ?? this.isGridView,
      gridColumns: gridColumns ?? this.gridColumns,
      cardVariant: cardVariant ?? this.cardVariant,
      showSourcePills: showSourcePills ?? this.showSourcePills,
      extensionNames: extensionNames ?? this.extensionNames,
      newChapters: newChapters ?? this.newChapters,
    );
  }
}

class LibraryNotifier extends Notifier<LibraryState> {
  static const _keyIsGridView = 'library_is_grid_view';
  static const _keyShowSourcePills = 'library_show_source_pills';
  static const _keyGridColumns = 'library_grid_columns';
  static const _keyCardVariant = 'library_card_variant';

  @override
  LibraryState build() => const LibraryState();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      isGridView: prefs.getBool(_keyIsGridView) ?? true,
      showSourcePills: prefs.getBool(_keyShowSourcePills) ?? true,
      gridColumns: prefs.getInt(_keyGridColumns) ?? 2,
      cardVariant:
          LibraryCardVariant.values[prefs.getInt(_keyCardVariant) ?? 0],
    );
  }

  void toggleLayout() {
    final next = !state.isGridView;
    state = state.copyWith(isGridView: next);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool(_keyIsGridView, next),
    );
  }

  void setShowSourcePills(bool value) {
    state = state.copyWith(showSourcePills: value);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool(_keyShowSourcePills, value),
    );
  }

  void setGridColumns(int value) {
    final clamped = value.clamp(2, 3);
    state = state.copyWith(gridColumns: clamped);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setInt(_keyGridColumns, clamped),
    );
  }

  void setCardVariant(LibraryCardVariant value) {
    state = state.copyWith(cardVariant: value);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setInt(_keyCardVariant, value.index),
    );
  }

  Future<void> loadBooks() async {
    state = state.copyWith(loading: true, error: () => null);
    final repos = ref.read(repositoriesProvider);
    try {
      final books = await repos.books.getBooks();
      final mangas = await repos.manga.getMangasInLibrary();
      final categories = await repos.categories.getCategories();
      final newChapters = await repos.manga.countNewChaptersByManga();
      final extNames = <String, String>{};
      final extensions = await repos.extensions.getInstalledExtensions();
      for (final ext in extensions) {
        if (ext.name.isEmpty) continue;
        // Manga.sourceId may be the bridge hex id OR Mihon Source.id.
        if (ext.sourceId.isNotEmpty) extNames[ext.sourceId] = ext.name;
        if (ext.id.isNotEmpty) extNames[ext.id] = ext.name;
      }
      state = state.copyWith(
        books: books,
        mangas: mangas,
        categories: categories,
        extensionNames: extNames,
        newChapters: newChapters,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(error: () => e.toString(), loading: false);
    }
  }

  Future<int> addBook(Book book) async {
    final repos = ref.read(repositoriesProvider);
    final id = await repos.books.insertBook(book);
    await loadBooks();
    return id;
  }

  Future<void> deleteBook(int id) async {
    final repos = ref.read(repositoriesProvider);
    await repos.books.deleteBook(id);
    final ids = Set<String>.from(state.selectedIds)..remove('b:$id');
    state = state.copyWith(selectedIds: ids);
    await loadBooks();
  }

  Future<void> deleteManga(int id) async {
    final repos = ref.read(repositoriesProvider);
    final manga = state.mangas.firstWhereOrNull((m) => m.id == id);
    if (manga != null) {
      try {
        final supportDir = await getApplicationSupportDirectory();
        final mangaKey = sha256
            .convert(utf8.encode(manga.url))
            .toString()
            .substring(0, 16);
        final mangaDir = Directory(
          '${supportDir.path}/manga/${manga.sourceId}/$mangaKey',
        );
        if (await mangaDir.exists()) {
          await mangaDir.delete(recursive: true);
        }
        final docsDir = await getApplicationDocumentsDirectory();
        final thumbHash = sha256
            .convert(utf8.encode(manga.imageUrl ?? ''))
            .toString();
        final thumbFile = File('${docsDir.path}/thumbnails/$thumbHash.jpg');
        if (await thumbFile.exists()) {
          await thumbFile.delete();
        }
      } catch (_) {}
    }
    await repos.manga.deleteMangaChapters(id);
    await repos.manga.deleteManga(id);
    final ids = Set<String>.from(state.selectedIds)..remove('m:$id');
    state = state.copyWith(selectedIds: ids);
    await loadBooks();
  }

  void toggleSelection(String key) {
    final ids = Set<String>.from(state.selectedIds);
    bool mode = state.selectionMode;
    if (ids.contains(key)) {
      ids.remove(key);
      if (ids.isEmpty) mode = false;
    } else {
      ids.add(key);
      mode = true;
    }
    state = state.copyWith(selectedIds: ids, selectionMode: mode);
  }

  void clearSelection() {
    state = state.copyWith(selectedIds: {}, selectionMode: false);
  }

  void selectAll() {
    if (state.selectedIds.length == state.books.length + state.mangas.length &&
        state.books.length + state.mangas.length > 0) {
      clearSelection();
      return;
    }
    final ids = <String>{};
    for (final book in state.books) {
      ids.add('b:${book.id}');
    }
    for (final manga in state.mangas) {
      ids.add('m:${manga.id}');
    }
    state = state.copyWith(selectedIds: ids, selectionMode: true);
  }

  Future<void> deleteSelected() async {
    if (state.selectedIds.isEmpty) return;
    final repos = ref.read(repositoriesProvider);
    for (final key in state.selectedIds.toList()) {
      if (key.startsWith('b:')) {
        final id = int.parse(key.substring(2));
        await repos.books.deleteBook(id);
      } else if (key.startsWith('m:')) {
        final id = int.parse(key.substring(2));
        final manga = state.mangas.firstWhereOrNull((m) => m.id == id);
        if (manga != null) {
          try {
            final supportDir = await getApplicationSupportDirectory();
            final mangaKey = sha256
                .convert(utf8.encode(manga.url))
                .toString()
                .substring(0, 16);
            final mangaDir = Directory(
              '${supportDir.path}/manga/${manga.sourceId}/$mangaKey',
            );
            if (await mangaDir.exists()) {
              await mangaDir.delete(recursive: true);
            }
            final docsDir = await getApplicationDocumentsDirectory();
            final thumbHash = sha256
                .convert(utf8.encode(manga.imageUrl ?? ''))
                .toString();
            final thumbFile = File('${docsDir.path}/thumbnails/$thumbHash.jpg');
            if (await thumbFile.exists()) {
              await thumbFile.delete();
            }
          } catch (_) {}
          await repos.manga.deleteMangaChapters(id);
          await repos.manga.deleteManga(id);
        }
      }
    }
    state = state.copyWith(selectedIds: {}, selectionMode: false);
    await loadBooks();
  }
}

/// Auto-update state + poller for library manga (mangayomi's LibUpdatesAlarm
/// parity). Watched by the library screen for the "new chapters" badge and
/// by settings for the interval toggle.
class LibraryUpdateState {
  final bool enabled;
  final Duration interval;
  final DateTime? lastCheckedAt;
  final int lastNewChapterCount;
  final bool checking;
  final String? error;
  final bool wifiOnly;
  final bool chargingOnly;

  const LibraryUpdateState({
    this.enabled = false,
    this.interval = const Duration(hours: 6),
    this.lastCheckedAt,
    this.lastNewChapterCount = 0,
    this.checking = false,
    this.error,
    this.wifiOnly = LibraryUpdatePrefs.defaultWifiOnly,
    this.chargingOnly = LibraryUpdatePrefs.defaultChargingOnly,
  });

  LibraryUpdateState copyWith({
    bool? enabled,
    Duration? interval,
    DateTime? Function()? lastCheckedAt,
    int? lastNewChapterCount,
    bool? checking,
    String? Function()? error,
    bool? wifiOnly,
    bool? chargingOnly,
  }) {
    return LibraryUpdateState(
      enabled: enabled ?? this.enabled,
      interval: interval ?? this.interval,
      lastCheckedAt: lastCheckedAt != null
          ? lastCheckedAt()
          : this.lastCheckedAt,
      lastNewChapterCount: lastNewChapterCount ?? this.lastNewChapterCount,
      checking: checking ?? this.checking,
      error: error != null ? error() : this.error,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      chargingOnly: chargingOnly ?? this.chargingOnly,
    );
  }
}

class LibraryUpdateNotifier extends Notifier<LibraryUpdateState> {
  static const _keyEnabled = 'library_auto_update_enabled';
  static const _keyIntervalHours = 'library_auto_update_interval_hours';

  Timer? _timer;

  @override
  LibraryUpdateState build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    return const LibraryUpdateState();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyEnabled) ?? false;
    final intervalHours =
        prefs.getInt(_keyIntervalHours) ?? state.interval.inHours;
    final device = await LibraryUpdatePrefs.loadDeviceConstraints();
    state = state.copyWith(
      enabled: enabled,
      interval: Duration(hours: intervalHours),
      wifiOnly: device.wifiOnly,
      chargingOnly: device.chargingOnly,
    );
    _reschedule();
    await _syncBackgroundTask();
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
    state = state.copyWith(enabled: value);
    _reschedule();
    await _syncBackgroundTask();
  }

  Future<void> setInterval(Duration value) async {
    final prefs = await SharedPreferences.getInstance();
    final hours = value.inHours < 1 ? 1 : value.inHours;
    await prefs.setInt(_keyIntervalHours, hours);
    state = state.copyWith(interval: Duration(hours: hours));
    _reschedule();
    await _syncBackgroundTask();
  }

  Future<void> setWifiOnly(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(LibraryUpdatePrefs.keyWifiOnly, value);
    state = state.copyWith(wifiOnly: value);
    await _syncBackgroundTask();
  }

  Future<void> setChargingOnly(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(LibraryUpdatePrefs.keyChargingOnly, value);
    state = state.copyWith(chargingOnly: value);
    await _syncBackgroundTask();
  }

  void _reschedule() {
    _timer?.cancel();
    _timer = null;
    if (!state.enabled) return;
    _timer = Timer.periodic(state.interval, (_) => checkForNewChapters());
  }

  /// Mirror the in-app timer into a WorkManager periodic task so polling keeps
  /// happening while the app is backgrounded (or killed). Android's minimum
  /// period is 15 minutes; our smallest interval is 1h so the value passes
  /// through unchanged.
  ///
  /// Device constraints (Wi‑Fi / charging) apply only here — manual "Check
  /// now" and the foreground timer stay unconstrained (Mihon manual job
  /// parity).
  Future<void> _syncBackgroundTask() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      if (state.enabled) {
        await Workmanager().registerPeriodicTask(
          kLibraryPollTaskName,
          kLibraryPollTaskName,
          frequency: state.interval,
          existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
          constraints: LibraryUpdatePrefs.workConstraints(
            LibraryUpdateDeviceConstraints(
              wifiOnly: state.wifiOnly,
              chargingOnly: state.chargingOnly,
            ),
          ),
        );
      } else {
        await Workmanager().cancelByUniqueName(kLibraryPollTaskName);
      }
    } catch (_) {
      // Background scheduling is best-effort (e.g. unavailable in tests or
      // on some emulators); the in-app timer still covers the foreground.
    }
  }

  /// Poll every library manga for new chapters. Safe to call manually (the
  /// library screen's refresh) or from the periodic timer.
  ///
  /// [applyRestrictions]: when true (auto / background), honor Settings skip
  /// filters. Manual "Check now" passes false so titles with unread chapters
  /// still hit the source.
  Future<void> checkForNewChapters({bool applyRestrictions = true}) async {
    if (state.checking) return;
    state = state.copyWith(checking: true, error: () => null);
    try {
      final service = LibraryUpdateService(
        ref.read(repositoriesProvider),
        ref.read(extensionServiceProvider),
        extensionManager: ref.read(extensionManagerProvider),
      );
      final report = await service.checkForNewChapters(
        restrictions: applyRestrictions
            ? null
            : LibraryUpdateMangaRestrictions.none,
      );
      // Reload library so the new-chapter badges + card state refresh.
      await ref.read(libraryProvider.notifier).loadBooks();
      if (report.totalNew > 0) {
        ref.read(libraryUpdateResultProvider.notifier).setReport(report);
        // Foreground path: also surface a system notification. The background
        // isolate posts its own (NotificationService is self-contained).
        unawaited(NotificationService.instance.notifyNewChapters(report));
        unawaited(
          enqueueNewChaptersFromUpdate(
            manager: ref.read(downloadManagerProvider.notifier).manager,
            report: report,
          ),
        );
      }
      state = state.copyWith(
        checking: false,
        lastCheckedAt: () => DateTime.now(),
        lastNewChapterCount: report.totalNew,
      );
    } catch (e) {
      state = state.copyWith(checking: false, error: () => '$e');
    }
  }
}

/// Holds the most recent update report so the library screen can surface an
/// in-app "N new chapters" toast when a poll discovers something new.
class LibraryUpdateResultNotifier extends Notifier<LibraryUpdateReport?> {
  @override
  LibraryUpdateReport? build() => null;

  void setReport(LibraryUpdateReport report) => state = report;
}

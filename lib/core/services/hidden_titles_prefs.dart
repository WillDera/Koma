import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/manga.dart';
import '../../features/reader/reader_settings_sheet.dart';

/// Hidden / "secret shelf" titles — manga via [ViewerFlags.hidden], books via
/// a prefs id set. History/Updates visibility is opt-in.
class HiddenTitlesPrefs {
  static const _booksKey = 'hidden_book_ids';
  static const _showHistoryKey = 'hidden_show_in_history';
  static const _showUpdatesKey = 'hidden_show_in_updates';

  static Future<Set<int>> hiddenBookIds() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_booksKey) ?? const [];
    return {
      for (final s in raw) int.tryParse(s),
    }.whereType<int>().toSet();
  }

  static Future<void> setBookHidden(int bookId, bool hidden) async {
    final p = await SharedPreferences.getInstance();
    final next = await hiddenBookIds();
    if (hidden) {
      next.add(bookId);
    } else {
      next.remove(bookId);
    }
    await p.setStringList(
      _booksKey,
      [for (final id in next) '$id'],
    );
  }

  static Future<bool> isBookHidden(int bookId) async {
    return (await hiddenBookIds()).contains(bookId);
  }

  static bool isMangaHidden(Manga manga) =>
      ViewerFlags.isHidden(manga.viewerFlags);

  static Future<bool> showInHistory() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_showHistoryKey) ?? false;
  }

  static Future<void> setShowInHistory(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_showHistoryKey, v);
  }

  static Future<bool> showInUpdates() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_showUpdatesKey) ?? false;
  }

  static Future<void> setShowInUpdates(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_showUpdatesKey, v);
  }
}

class HiddenTitlesNotifier extends Notifier<HiddenTitlesState> {
  @override
  HiddenTitlesState build() {
    Future.microtask(_reload);
    return const HiddenTitlesState();
  }

  Future<void> _reload() async {
    final books = await HiddenTitlesPrefs.hiddenBookIds();
    final hist = await HiddenTitlesPrefs.showInHistory();
    final upd = await HiddenTitlesPrefs.showInUpdates();
    state = HiddenTitlesState(
      hiddenBookIds: books,
      showInHistory: hist,
      showInUpdates: upd,
      ready: true,
    );
  }

  Future<void> refresh() => _reload();

  Future<void> setShowInHistory(bool v) async {
    await HiddenTitlesPrefs.setShowInHistory(v);
    state = state.copyWith(showInHistory: v);
  }

  Future<void> setShowInUpdates(bool v) async {
    await HiddenTitlesPrefs.setShowInUpdates(v);
    state = state.copyWith(showInUpdates: v);
  }

  Future<void> setBookHidden(int bookId, bool hidden) async {
    await HiddenTitlesPrefs.setBookHidden(bookId, hidden);
    final next = {...state.hiddenBookIds};
    if (hidden) {
      next.add(bookId);
    } else {
      next.remove(bookId);
    }
    state = state.copyWith(hiddenBookIds: next);
  }
}

class HiddenTitlesState {
  final Set<int> hiddenBookIds;
  final bool showInHistory;
  final bool showInUpdates;
  final bool ready;

  const HiddenTitlesState({
    this.hiddenBookIds = const {},
    this.showInHistory = false,
    this.showInUpdates = false,
    this.ready = false,
  });

  HiddenTitlesState copyWith({
    Set<int>? hiddenBookIds,
    bool? showInHistory,
    bool? showInUpdates,
    bool? ready,
  }) {
    return HiddenTitlesState(
      hiddenBookIds: hiddenBookIds ?? this.hiddenBookIds,
      showInHistory: showInHistory ?? this.showInHistory,
      showInUpdates: showInUpdates ?? this.showInUpdates,
      ready: ready ?? this.ready,
    );
  }

  bool isBookHidden(int id) => hiddenBookIds.contains(id);
}

final hiddenTitlesProvider =
    NotifierProvider<HiddenTitlesNotifier, HiddenTitlesState>(
      HiddenTitlesNotifier.new,
    );

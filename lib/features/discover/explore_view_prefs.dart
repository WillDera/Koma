import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Explore-only: manga search results as short horizontal rails (max 5 + See all).
const kExploreCompactMangaRailsKey = 'explore_compact_manga_rails';
const kExploreCompactMangaRailsDefault = false;

class ExploreCompactMangaRailsNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return kExploreCompactMangaRailsDefault;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final v =
        prefs.getBool(kExploreCompactMangaRailsKey) ??
        kExploreCompactMangaRailsDefault;
    if (state != v) state = v;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kExploreCompactMangaRailsKey, value);
  }

  Future<void> toggle() => setEnabled(!state);
}

final exploreCompactMangaRailsProvider =
    NotifierProvider<ExploreCompactMangaRailsNotifier, bool>(
      ExploreCompactMangaRailsNotifier.new,
    );

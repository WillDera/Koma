import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Edge placement for the shared ebook/novel reading progress pill.
enum TextProgressPillPlacement { left, bottom, right }

@immutable
class TextProgressPillPrefs {
  const TextProgressPillPrefs({
    this.enabled = true,
    this.placement = TextProgressPillPlacement.bottom,
  });

  final bool enabled;
  final TextProgressPillPlacement placement;

  TextProgressPillPrefs copyWith({
    bool? enabled,
    TextProgressPillPlacement? placement,
  }) {
    return TextProgressPillPrefs(
      enabled: enabled ?? this.enabled,
      placement: placement ?? this.placement,
    );
  }
}

class TextProgressPillPrefsNotifier extends Notifier<TextProgressPillPrefs> {
  static const _keyEnabled = 'text_progress_pill_enabled';
  static const _keyPlacement = 'text_progress_pill_placement';

  @override
  TextProgressPillPrefs build() {
    // Sync load isn't available; start with defaults then hydrate.
    Future.microtask(_load);
    return const TextProgressPillPrefs();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final placementIndex = prefs.getInt(_keyPlacement) ?? 1;
    state = TextProgressPillPrefs(
      enabled: prefs.getBool(_keyEnabled) ?? true,
      placement: TextProgressPillPlacement.values[placementIndex.clamp(
        0,
        TextProgressPillPlacement.values.length - 1,
      )],
    );
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
  }

  Future<void> setPlacement(TextProgressPillPlacement placement) async {
    state = state.copyWith(placement: placement);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPlacement, placement.index);
  }
}

final textProgressPillPrefsProvider =
    NotifierProvider<TextProgressPillPrefsNotifier, TextProgressPillPrefs>(
      TextProgressPillPrefsNotifier.new,
    );

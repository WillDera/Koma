import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Placement for ebook / novel TTS media controls.
enum TtsControlsPlacement { left, bottom, right }

@immutable
class TtsControlsPrefs {
  const TtsControlsPrefs({
    this.placement = TtsControlsPlacement.bottom,
  });

  final TtsControlsPlacement placement;

  TtsControlsPrefs copyWith({TtsControlsPlacement? placement}) {
    return TtsControlsPrefs(placement: placement ?? this.placement);
  }
}

class TtsControlsPrefsNotifier extends Notifier<TtsControlsPrefs> {
  static const _keyPlacement = 'tts_controls_placement';

  @override
  TtsControlsPrefs build() {
    Future.microtask(_load);
    return const TtsControlsPrefs();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_keyPlacement) ?? TtsControlsPlacement.bottom.index;
    state = TtsControlsPrefs(
      placement: TtsControlsPlacement.values[index.clamp(
        0,
        TtsControlsPlacement.values.length - 1,
      )],
    );
  }

  Future<void> setPlacement(TtsControlsPlacement placement) async {
    state = state.copyWith(placement: placement);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPlacement, placement.index);
  }
}

final ttsControlsPrefsProvider =
    NotifierProvider<TtsControlsPrefsNotifier, TtsControlsPrefs>(
      TtsControlsPrefsNotifier.new,
    );

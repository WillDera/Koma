import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/reader/tts_controls_prefs.dart';
import '../features/reader/tts_provider.dart';
import '../theme/tokens/app_motion.dart';
import 'reader_bottom_bar.dart';
import 'reader_top_bar.dart';
import 'tts_controls.dart';

/// Positions active TTS media controls per [ttsControlsPrefsProvider].
///
/// Bottom mode sits above the chapter bar while chrome is visible, then
/// animates down into the bar's slot when chrome hides.
class TtsControlsOverlay extends ConsumerWidget {
  const TtsControlsOverlay({
    super.key,
    required this.provider,
    required this.chromeVisible,
  });

  final TtsProvider provider;
  final bool chromeVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        if (!provider.isActive) return const SizedBox.shrink();

        final placement = ref.watch(ttsControlsPrefsProvider).placement;
        final padding = MediaQuery.paddingOf(context);
        final edgeInset = 10.0;

        switch (placement) {
          case TtsControlsPlacement.left:
            return Positioned(
              left: math.max(padding.left, edgeInset),
              top: padding.top + ReaderTopBar.bodyHeight,
              bottom: padding.bottom +
                  (chromeVisible ? ReaderBottomBar.bodyHeight : edgeInset),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TtsControls(
                  provider: provider,
                  axis: Axis.vertical,
                  padBottomSafeArea: false,
                ),
              ),
            );
          case TtsControlsPlacement.right:
            return Positioned(
              right: math.max(padding.right, edgeInset),
              top: padding.top + ReaderTopBar.bodyHeight,
              bottom: padding.bottom +
                  (chromeVisible ? ReaderBottomBar.bodyHeight : edgeInset),
              child: Align(
                alignment: Alignment.centerRight,
                child: TtsControls(
                  provider: provider,
                  axis: Axis.vertical,
                  padBottomSafeArea: false,
                ),
              ),
            );
          case TtsControlsPlacement.bottom:
            // Lift above the chapter bar while chrome is showing; drop into
            // that slot (with home-indicator SafeArea) when chrome hides.
            final lift = chromeVisible
                ? padding.bottom + ReaderBottomBar.bodyHeight
                : 0.0;
            return AnimatedPositioned(
              duration: AppMotion.base,
              curve: AppMotion.standard,
              left: 0,
              right: 0,
              bottom: lift,
              child: TtsControls(
                provider: provider,
                axis: Axis.horizontal,
                padBottomSafeArea: !chromeVisible,
              ),
            );
        }
      },
    );
  }
}

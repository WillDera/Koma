import 'package:flutter/material.dart';

import 'scene_chrome.dart';

/// Environment frost / ambient veils behind chapter text.
class SceneChromeLayer extends StatelessWidget {
  const SceneChromeLayer({super.key, required this.chrome});

  final SceneChrome chrome;

  @override
  Widget build(BuildContext context) {
    final frost = chrome.frostOverlayAlpha;
    final ambient = chrome.ambientOverlayAlpha;
    if (frost <= 0 && ambient <= 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (ambient > 0 && chrome.ambient != null)
            ColoredBox(color: chrome.ambient!.withValues(alpha: ambient)),
          if (frost > 0)
            ColoredBox(color: const Color(0xFFFFFFFF).withValues(alpha: frost)),
        ],
      ),
    );
  }
}

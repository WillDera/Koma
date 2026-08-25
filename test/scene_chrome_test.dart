import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koma/features/reader/scene/scene_chrome.dart';

void main() {
  test('tryParseHex accepts #RGB, #RRGGBB, #RRGGBBAA', () {
    expect(SceneChrome.tryParseHex('#0b0'), const Color(0xFF00BB00));
    expect(SceneChrome.tryParseHex('#0b0e14'), const Color(0xFF0B0E14));
    expect(SceneChrome.tryParseHex('#e8e6e380'), const Color(0x80E8E6E3));
    expect(SceneChrome.tryParseHex('nope'), isNull);
  });

  test('default white/black pages are not authored atmosphere', () {
    const white = SceneChrome(
      environmentKind: 'abstract',
      background: Color(0xFFFFFFFF),
    );
    const black = SceneChrome(
      environmentKind: 'abstract',
      background: Color(0xFF000000),
    );
    const imperial = SceneChrome(
      environmentKind: 'abstract',
      background: Color(0xFF0B0E14),
    );
    expect(white.hasAuthoredBackground, isFalse);
    expect(black.hasAuthoredBackground, isFalse);
    expect(imperial.hasAuthoredBackground, isTrue);
  });

  test('pageBackground keeps user color unless scene matches brightness', () {
    const userLight = Color(0xFFFAFAFA);
    const userDark = Color(0xFF121212);
    const sceneDark = SceneChrome(
      environmentKind: 'abstract',
      background: Color(0xFF0B0E14),
    );
    expect(
      SceneChrome.pageBackground(sceneDark, userLight, userDark: false),
      userLight,
    );
    expect(
      SceneChrome.pageBackground(sceneDark, userDark, userDark: true),
      const Color(0xFF0B0E14),
    );
    expect(
      SceneChrome.pageBackground(null, userLight, userDark: false),
      userLight,
    );
  });

  test('frost and ambient alphas stay readable', () {
    const chrome = SceneChrome(
      environmentKind: 'abstract',
      background: Color(0xFF0B0E14),
      ambient: Color(0xFFE8E6E3),
      ambientIntensity: 0.85,
      frost: 0.6,
    );
    expect(chrome.frostOverlayAlpha, closeTo(0.084, 0.0001));
    expect(chrome.ambientOverlayAlpha, closeTo(0.033, 0.0001));
    const defaults = SceneChrome(
      environmentKind: 'abstract',
      background: Color(0xFFFFFFFF),
      ambientIntensity: 0.0,
    );
    expect(defaults.ambientOverlayAlpha, 0);
  });

  test('switchDuration honors reduce-motion', () {
    const chrome = SceneChrome(
      environmentKind: 'abstract',
      fade: Duration(milliseconds: 800),
    );
    expect(
      SceneChrome.switchDuration(
        chrome,
        const Duration(milliseconds: 420),
        disableAnimations: true,
      ),
      Duration.zero,
    );
    expect(
      SceneChrome.switchDuration(
        chrome,
        const Duration(milliseconds: 420),
        disableAnimations: false,
      ),
      const Duration(milliseconds: 800),
    );
  });
}

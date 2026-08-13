import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'reader_settings_sheet.dart';

class ReaderSettingsNotifier extends Notifier<ReaderSettings> {
  static const _key = 'reader_settings';

  @override
  ReaderSettings build() {
    _load();
    return ReaderSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        state = ReaderSettings.fromJson(json);
      } catch (_) {}
    }
  }

  Future<void> _persist(ReaderSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(s.toJson()));
  }

  void update(ReaderSettings s) {
    state = s;
    _persist(s);
  }

  void setReadingMode(ReadingMode mode) =>
      update(state.copyWithReadingMode(mode));
  void setRotationMode(RotationMode mode) =>
      update(state.copyWithRotationMode(mode));
  void setTapZones(TapZoneMode mode) => update(state.copyWithTapZones(mode));
  void setSidePadding(double v) => update(state.copyWithSidePadding(v));
  void setCropBorders(bool v) => update(state.copyWithCropBorders(v));
  void setBookMode(bool v) => update(state.copyWithBookMode(v));
  void setBrightness(double v) => update(state.copyWithBrightness(v));
  void setContrast(double v) => update(state.copyWithContrast(v));
  void setSaturation(double v) => update(state.copyWithSaturation(v));
  void setTint(Color? c, double o) => update(state.copyWithTint(c, o));
}

extension CopyWithReaderSettings on ReaderSettings {
  ReaderSettings copyWithReadingMode(ReadingMode r) => ReaderSettings(
    readingMode: r,
    rotationMode: rotationMode,
    tapZones: tapZones,
    sidePadding: sidePadding,
    cropBorders: cropBorders,
    bookMode: bookMode,
    disableDoubleTap: disableDoubleTap,
    disableZoomOut: disableZoomOut,
    showPageNumber: showPageNumber,
    showPageNavigator: showPageNavigator,
    fullscreen: fullscreen,
    keepScreenOn: keepScreenOn,
    showActionsOnLongTap: showActionsOnLongTap,
    animatePageTransition: animatePageTransition,
    progressBarPlacement: progressBarPlacement,
    brightness: brightness,
    contrast: contrast,
    saturation: saturation,
    tintColor: tintColor,
    tintOpacity: tintOpacity,
  );

  ReaderSettings copyWithRotationMode(RotationMode r) => ReaderSettings(
    readingMode: readingMode,
    rotationMode: r,
    tapZones: tapZones,
    sidePadding: sidePadding,
    cropBorders: cropBorders,
    bookMode: bookMode,
    disableDoubleTap: disableDoubleTap,
    disableZoomOut: disableZoomOut,
    showPageNumber: showPageNumber,
    showPageNavigator: showPageNavigator,
    fullscreen: fullscreen,
    keepScreenOn: keepScreenOn,
    showActionsOnLongTap: showActionsOnLongTap,
    animatePageTransition: animatePageTransition,
    progressBarPlacement: progressBarPlacement,
    brightness: brightness,
    contrast: contrast,
    saturation: saturation,
    tintColor: tintColor,
    tintOpacity: tintOpacity,
  );

  ReaderSettings copyWithTapZones(TapZoneMode t) => ReaderSettings(
    readingMode: readingMode,
    rotationMode: rotationMode,
    tapZones: t,
    sidePadding: sidePadding,
    cropBorders: cropBorders,
    bookMode: bookMode,
    disableDoubleTap: disableDoubleTap,
    disableZoomOut: disableZoomOut,
    showPageNumber: showPageNumber,
    showPageNavigator: showPageNavigator,
    fullscreen: fullscreen,
    keepScreenOn: keepScreenOn,
    showActionsOnLongTap: showActionsOnLongTap,
    animatePageTransition: animatePageTransition,
    progressBarPlacement: progressBarPlacement,
    brightness: brightness,
    contrast: contrast,
    saturation: saturation,
    tintColor: tintColor,
    tintOpacity: tintOpacity,
  );

  ReaderSettings copyWithSidePadding(double s) => ReaderSettings(
    readingMode: readingMode,
    rotationMode: rotationMode,
    tapZones: tapZones,
    sidePadding: s,
    cropBorders: cropBorders,
    bookMode: bookMode,
    disableDoubleTap: disableDoubleTap,
    disableZoomOut: disableZoomOut,
    showPageNumber: showPageNumber,
    showPageNavigator: showPageNavigator,
    fullscreen: fullscreen,
    keepScreenOn: keepScreenOn,
    showActionsOnLongTap: showActionsOnLongTap,
    animatePageTransition: animatePageTransition,
    progressBarPlacement: progressBarPlacement,
    brightness: brightness,
    contrast: contrast,
    saturation: saturation,
    tintColor: tintColor,
    tintOpacity: tintOpacity,
  );

  ReaderSettings copyWithCropBorders(bool v) => ReaderSettings(
    readingMode: readingMode,
    rotationMode: rotationMode,
    tapZones: tapZones,
    sidePadding: sidePadding,
    cropBorders: v,
    bookMode: bookMode,
    disableDoubleTap: disableDoubleTap,
    disableZoomOut: disableZoomOut,
    showPageNumber: showPageNumber,
    showPageNavigator: showPageNavigator,
    fullscreen: fullscreen,
    keepScreenOn: keepScreenOn,
    showActionsOnLongTap: showActionsOnLongTap,
    animatePageTransition: animatePageTransition,
    progressBarPlacement: progressBarPlacement,
    brightness: brightness,
    contrast: contrast,
    saturation: saturation,
    tintColor: tintColor,
    tintOpacity: tintOpacity,
  );

  ReaderSettings copyWithBookMode(bool v) => ReaderSettings(
    readingMode: readingMode,
    rotationMode: rotationMode,
    tapZones: tapZones,
    sidePadding: sidePadding,
    cropBorders: cropBorders,
    bookMode: v,
    disableDoubleTap: disableDoubleTap,
    disableZoomOut: disableZoomOut,
    showPageNumber: showPageNumber,
    showPageNavigator: showPageNavigator,
    fullscreen: fullscreen,
    keepScreenOn: keepScreenOn,
    showActionsOnLongTap: showActionsOnLongTap,
    animatePageTransition: animatePageTransition,
    progressBarPlacement: progressBarPlacement,
    brightness: brightness,
    contrast: contrast,
    saturation: saturation,
    tintColor: tintColor,
    tintOpacity: tintOpacity,
  );

  ReaderSettings copyWithBrightness(double v) => ReaderSettings(
    readingMode: readingMode,
    rotationMode: rotationMode,
    tapZones: tapZones,
    sidePadding: sidePadding,
    cropBorders: cropBorders,
    bookMode: bookMode,
    disableDoubleTap: disableDoubleTap,
    disableZoomOut: disableZoomOut,
    showPageNumber: showPageNumber,
    showPageNavigator: showPageNavigator,
    fullscreen: fullscreen,
    keepScreenOn: keepScreenOn,
    showActionsOnLongTap: showActionsOnLongTap,
    animatePageTransition: animatePageTransition,
    progressBarPlacement: progressBarPlacement,
    brightness: v,
    contrast: contrast,
    saturation: saturation,
    tintColor: tintColor,
    tintOpacity: tintOpacity,
  );

  ReaderSettings copyWithContrast(double v) => ReaderSettings(
    readingMode: readingMode,
    rotationMode: rotationMode,
    tapZones: tapZones,
    sidePadding: sidePadding,
    cropBorders: cropBorders,
    bookMode: bookMode,
    disableDoubleTap: disableDoubleTap,
    disableZoomOut: disableZoomOut,
    showPageNumber: showPageNumber,
    showPageNavigator: showPageNavigator,
    fullscreen: fullscreen,
    keepScreenOn: keepScreenOn,
    showActionsOnLongTap: showActionsOnLongTap,
    animatePageTransition: animatePageTransition,
    progressBarPlacement: progressBarPlacement,
    brightness: brightness,
    contrast: v,
    saturation: saturation,
    tintColor: tintColor,
    tintOpacity: tintOpacity,
  );

  ReaderSettings copyWithSaturation(double v) => ReaderSettings(
    readingMode: readingMode,
    rotationMode: rotationMode,
    tapZones: tapZones,
    sidePadding: sidePadding,
    cropBorders: cropBorders,
    bookMode: bookMode,
    disableDoubleTap: disableDoubleTap,
    disableZoomOut: disableZoomOut,
    showPageNumber: showPageNumber,
    showPageNavigator: showPageNavigator,
    fullscreen: fullscreen,
    keepScreenOn: keepScreenOn,
    showActionsOnLongTap: showActionsOnLongTap,
    animatePageTransition: animatePageTransition,
    progressBarPlacement: progressBarPlacement,
    brightness: brightness,
    contrast: contrast,
    saturation: v,
    tintColor: tintColor,
    tintOpacity: tintOpacity,
  );

  ReaderSettings copyWithTint(Color? c, double o) => ReaderSettings(
    readingMode: readingMode,
    rotationMode: rotationMode,
    tapZones: tapZones,
    sidePadding: sidePadding,
    cropBorders: cropBorders,
    bookMode: bookMode,
    disableDoubleTap: disableDoubleTap,
    disableZoomOut: disableZoomOut,
    showPageNumber: showPageNumber,
    showPageNavigator: showPageNavigator,
    fullscreen: fullscreen,
    keepScreenOn: keepScreenOn,
    showActionsOnLongTap: showActionsOnLongTap,
    animatePageTransition: animatePageTransition,
    progressBarPlacement: progressBarPlacement,
    brightness: brightness,
    contrast: contrast,
    saturation: saturation,
    tintColor: c,
    tintOpacity: o,
  );
}

final readerSettingsProvider =
    NotifierProvider<ReaderSettingsNotifier, ReaderSettings>(
      ReaderSettingsNotifier.new,
    );

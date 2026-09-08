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
      update(state.copyWith(readingMode: mode));
  void setRotationMode(RotationMode mode) =>
      update(state.copyWith(rotationMode: mode));
  void setTapZones(TapZoneMode mode) => update(state.copyWith(tapZones: mode));
  void setSidePadding(double v) => update(state.copyWith(sidePadding: v));
  void setCropBorders(bool v) => update(state.copyWith(cropBorders: v));
  void setBookMode(bool v) => update(state.copyWith(bookMode: v));
  void setBrightness(double v) => update(state.copyWith(brightness: v));
  void setContrast(double v) => update(state.copyWith(contrast: v));
  void setSaturation(double v) => update(state.copyWith(saturation: v));
  void setTint(Color? c, double o) =>
      update(state.copyWith(tintColor: c, tintOpacity: o));
  void setSepiaPanels(bool v) => update(state.copyWith(sepiaPanels: v));
}

extension CopyWithReaderSettings on ReaderSettings {
  ReaderSettings copyWithReadingMode(ReadingMode r) => copyWith(readingMode: r);
  ReaderSettings copyWithRotationMode(RotationMode r) =>
      copyWith(rotationMode: r);
  ReaderSettings copyWithTapZones(TapZoneMode t) => copyWith(tapZones: t);
  ReaderSettings copyWithSidePadding(double s) => copyWith(sidePadding: s);
  ReaderSettings copyWithCropBorders(bool v) => copyWith(cropBorders: v);
  ReaderSettings copyWithBookMode(bool v) => copyWith(bookMode: v);
  ReaderSettings copyWithBrightness(double v) => copyWith(brightness: v);
  ReaderSettings copyWithContrast(double v) => copyWith(contrast: v);
  ReaderSettings copyWithSaturation(double v) => copyWith(saturation: v);
  ReaderSettings copyWithTint(Color? c, double o) =>
      copyWith(tintColor: c, tintOpacity: o);
}

final readerSettingsProvider =
    NotifierProvider<ReaderSettingsNotifier, ReaderSettings>(
      ReaderSettingsNotifier.new,
    );

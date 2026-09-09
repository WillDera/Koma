import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/segmented_control.dart';
import '../../widgets/settings_section.dart';

enum ReadingMode {
  defaultL2R,
  rightToLeft,
  webtoon,
  longStrip,
  longStripWithGaps,
}

enum RotationMode { portrait, free, landscape }

/// Tap-zone layouts for paged manga reading.
///
/// - [leftRight]: three full-height columns L | M | R — sides navigate,
///   middle toggles the toolbar.
/// - [leftMiddleRight]: mangayomi default — same columns plus top/bottom
///   strips so middle-top = prev and middle-bottom = next.
///
/// Legacy [leftTopRightBottom] is kept only for deserialization; it is
/// migrated to [leftRight] on load and is no longer offered in the UI.
enum TapZoneMode { leftRight, leftTopRightBottom, leftMiddleRight }

enum ProgressBarPlacement {
  horizontalTop,
  horizontalBottom,
  verticalLeft,
  verticalRight,
}

class ReaderSettings {
  ReadingMode readingMode;
  RotationMode rotationMode;
  TapZoneMode tapZones;
  double sidePadding;
  bool cropBorders;
  bool bookMode;
  bool disableDoubleTap;
  bool disableZoomOut;
  bool showPageNumber;
  bool showPageNavigator;
  bool fullscreen;
  bool keepScreenOn;
  bool showActionsOnLongTap;
  bool animatePageTransition;
  /// Light haptics when flipping panels (paged) or crossing pages.
  bool hapticFeedback;
  ProgressBarPlacement progressBarPlacement;
  double brightness;
  double contrast;
  double saturation;
  Color? tintColor;
  double tintOpacity;
  /// When app Appearance is sepia, warm the manga page paper to match.
  bool sepiaPanels;
  /// Auto-scroll continuous (webtoon / long strip) modes.
  bool autoScroll;
  /// Pages advanced per tick interval; higher = faster.
  double autoScrollSpeed;

  ReaderSettings({
    this.readingMode = ReadingMode.defaultL2R,
    this.rotationMode = RotationMode.free,
    this.tapZones = TapZoneMode.leftRight,
    this.sidePadding = 0.0,
    this.cropBorders = false,
    this.bookMode = false,
    this.disableDoubleTap = false,
    this.disableZoomOut = false,
    this.showPageNumber = true,
    this.showPageNavigator = true,
    this.fullscreen = false,
    this.keepScreenOn = true,
    this.showActionsOnLongTap = true,
    this.animatePageTransition = true,
    this.hapticFeedback = true,
    this.progressBarPlacement = ProgressBarPlacement.horizontalBottom,
    this.brightness = 1.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
    this.tintColor,
    this.tintOpacity = 0.0,
    this.sepiaPanels = true,
    this.autoScroll = false,
    this.autoScrollSpeed = 1.0,
  });

  ReaderSettings copyWith({
    ReadingMode? readingMode,
    RotationMode? rotationMode,
    TapZoneMode? tapZones,
    double? sidePadding,
    bool? cropBorders,
    bool? bookMode,
    bool? disableDoubleTap,
    bool? disableZoomOut,
    bool? showPageNumber,
    bool? showPageNavigator,
    bool? fullscreen,
    bool? keepScreenOn,
    bool? showActionsOnLongTap,
    bool? animatePageTransition,
    bool? hapticFeedback,
    ProgressBarPlacement? progressBarPlacement,
    double? brightness,
    double? contrast,
    double? saturation,
    Color? tintColor,
    double? tintOpacity,
    bool? sepiaPanels,
    bool? autoScroll,
    double? autoScrollSpeed,
  }) {
    return ReaderSettings(
      readingMode: readingMode ?? this.readingMode,
      rotationMode: rotationMode ?? this.rotationMode,
      tapZones: tapZones ?? this.tapZones,
      sidePadding: sidePadding ?? this.sidePadding,
      cropBorders: cropBorders ?? this.cropBorders,
      bookMode: bookMode ?? this.bookMode,
      disableDoubleTap: disableDoubleTap ?? this.disableDoubleTap,
      disableZoomOut: disableZoomOut ?? this.disableZoomOut,
      showPageNumber: showPageNumber ?? this.showPageNumber,
      showPageNavigator: showPageNavigator ?? this.showPageNavigator,
      fullscreen: fullscreen ?? this.fullscreen,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      showActionsOnLongTap: showActionsOnLongTap ?? this.showActionsOnLongTap,
      animatePageTransition:
          animatePageTransition ?? this.animatePageTransition,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      progressBarPlacement: progressBarPlacement ?? this.progressBarPlacement,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      tintColor: tintColor ?? this.tintColor,
      tintOpacity: tintOpacity ?? this.tintOpacity,
      sepiaPanels: sepiaPanels ?? this.sepiaPanels,
      autoScroll: autoScroll ?? this.autoScroll,
      autoScrollSpeed: autoScrollSpeed ?? this.autoScrollSpeed,
    );
  }

  Map<String, dynamic> toJson() => {
    'readingMode': readingMode.index,
    'rotationMode': rotationMode.index,
    // Persist the effective layout; legacy leftTopRightBottom → leftRight.
    'tapZones': (tapZones == TapZoneMode.leftTopRightBottom
            ? TapZoneMode.leftRight
            : tapZones)
        .index,
    'tapZonesV2': 1,
    'sidePadding': sidePadding,
    'cropBorders': cropBorders ? 1 : 0,
    'bookMode': bookMode ? 1 : 0,
    'disableDoubleTap': disableDoubleTap ? 1 : 0,
    'disableZoomOut': disableZoomOut ? 1 : 0,
    'showPageNumber': showPageNumber ? 1 : 0,
    'showPageNavigator': showPageNavigator ? 1 : 0,
    'fullscreen': fullscreen ? 1 : 0,
    'keepScreenOn': keepScreenOn ? 1 : 0,
    'showActionsOnLongTap': showActionsOnLongTap ? 1 : 0,
    'animatePageTransition': animatePageTransition ? 1 : 0,
    'hapticFeedback': hapticFeedback ? 1 : 0,
    'progressBarPlacement': progressBarPlacement.index,
    'brightness': brightness,
    'contrast': contrast,
    'saturation': saturation,
    'tintColor': tintColor?.toARGB32(),
    'tintOpacity': tintOpacity,
    'sepiaPanels': sepiaPanels ? 1 : 0,
    'autoScroll': autoScroll ? 1 : 0,
    'autoScrollSpeed': autoScrollSpeed,
  };

  factory ReaderSettings.fromJson(Map<String, dynamic> json) {
    final rawZones = json['tapZones'] as int?;
    final isV2 = (json['tapZonesV2'] as int? ?? 0) == 1;
    final TapZoneMode tapZones;
    if (isV2) {
      tapZones = switch (rawZones) {
        2 => TapZoneMode.leftMiddleRight,
        1 => TapZoneMode.leftRight, // legacy value still in some saves
        _ => TapZoneMode.leftRight,
      };
    } else {
      // Pre-v2: 0 = old 3-col "L/M/R", 1 = "L/T R/B", 2 = leftCenterRight.
      tapZones = switch (rawZones) {
        1 => TapZoneMode.leftRight,
        _ => TapZoneMode.leftMiddleRight,
      };
    }
    final modeIdx = json['readingMode'] as int? ?? 0;
    return ReaderSettings(
      readingMode: modeIdx >= 0 && modeIdx < ReadingMode.values.length
          ? ReadingMode.values[modeIdx]
          : ReadingMode.defaultL2R,
      rotationMode: RotationMode.values[json['rotationMode'] as int? ?? 1],
      tapZones: tapZones,
      sidePadding: (json['sidePadding'] as num?)?.toDouble() ?? 0.0,
      cropBorders: (json['cropBorders'] as int? ?? 0) == 1,
      bookMode: (json['bookMode'] as int? ?? 0) == 1,
      disableDoubleTap: (json['disableDoubleTap'] as int? ?? 0) == 1,
      disableZoomOut: (json['disableZoomOut'] as int? ?? 0) == 1,
      showPageNumber: (json['showPageNumber'] as int? ?? 1) == 1,
      showPageNavigator: (json['showPageNavigator'] as int? ?? 1) == 1,
      fullscreen: (json['fullscreen'] as int? ?? 0) == 1,
      keepScreenOn: (json['keepScreenOn'] as int? ?? 1) == 1,
      showActionsOnLongTap: (json['showActionsOnLongTap'] as int? ?? 1) == 1,
      animatePageTransition: (json['animatePageTransition'] as int? ?? 1) == 1,
      hapticFeedback: (json['hapticFeedback'] as int? ?? 1) == 1,
      progressBarPlacement: ProgressBarPlacement
          .values[json['progressBarPlacement'] as int? ?? 1],
      brightness: (json['brightness'] as num?)?.toDouble() ?? 1.0,
      contrast: (json['contrast'] as num?)?.toDouble() ?? 1.0,
      saturation: (json['saturation'] as num?)?.toDouble() ?? 1.0,
      tintColor: json['tintColor'] != null
          ? Color(json['tintColor'] as int)
          : null,
      tintOpacity: (json['tintOpacity'] as num?)?.toDouble() ?? 0.0,
      // Default on so existing installs keep the warm paper look.
      sepiaPanels: (json['sepiaPanels'] as int? ?? 1) == 1,
      autoScroll: (json['autoScroll'] as int? ?? 0) == 1,
      autoScrollSpeed: (json['autoScrollSpeed'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// Mihon viewer flag bitfield (READING_MODE_*).
class ViewerFlags {
  static const mask = 0x7;
  static const ltr = 1;
  static const rtl = 2;
  static const vertical = 3;
  static const webtoon = 4;
  static const continuousVertical = 5;

  static ReadingMode? readingModeFromFlags(int flags) {
    final mode = flags & mask;
    return switch (mode) {
      ltr => ReadingMode.defaultL2R,
      rtl => ReadingMode.rightToLeft,
      vertical => ReadingMode.longStrip,
      webtoon => ReadingMode.webtoon,
      continuousVertical => ReadingMode.longStripWithGaps,
      _ => null,
    };
  }

  static int flagsForReadingMode(ReadingMode mode, int existing) {
    final cleared = existing & ~mask;
    final bit = switch (mode) {
      ReadingMode.defaultL2R => ltr,
      ReadingMode.rightToLeft => rtl,
      ReadingMode.webtoon => webtoon,
      ReadingMode.longStrip => vertical,
      ReadingMode.longStripWithGaps => continuousVertical,
    };
    return cleared | bit;
  }
}

class ReaderSettingsSheet extends StatefulWidget {
  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onChanged;
  /// True when reading mode is persisted on MangaExtras.viewerFlags.
  final bool seriesReadingModeSaved;

  const ReaderSettingsSheet({
    super.key,
    required this.settings,
    required this.onChanged,
    this.seriesReadingModeSaved = false,
  });

  @override
  State<ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<ReaderSettingsSheet> {
  late ReaderSettings _s;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _s = widget.settings;
  }

  void _update(ReaderSettings v) {
    setState(() {
      _s = v;
      widget.onChanged(_s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: c.bgElevated,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: SegmentedControl<int>(
              segments: const {0: 'Reading', 1: 'Display'},
              value: _tab,
              onChanged: (v) => setState(() => _tab = v),
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: c.bg,
              child: _tab == 0
                  ? _ReadingTab(
                      settings: _s,
                      onChanged: _update,
                      seriesReadingModeSaved: widget.seriesReadingModeSaved,
                    )
                  : _DisplayTab(settings: _s, onChanged: _update),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingTab extends StatelessWidget {
  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onChanged;
  final bool seriesReadingModeSaved;

  const _ReadingTab({
    required this.settings,
    required this.onChanged,
    required this.seriesReadingModeSaved,
  });

  TapZoneMode get _effectiveZones =>
      settings.tapZones == TapZoneMode.leftTopRightBottom
      ? TapZoneMode.leftRight
      : settings.tapZones;

  bool get _isContinuous =>
      settings.readingMode == ReadingMode.webtoon ||
      settings.readingMode == ReadingMode.longStrip ||
      settings.readingMode == ReadingMode.longStripWithGaps;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _SectionLabel('Reading direction'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in const {
              ReadingMode.defaultL2R: 'L→R',
              ReadingMode.rightToLeft: 'R→L',
              ReadingMode.webtoon: 'Webtoon',
              ReadingMode.longStrip: 'Long strip',
              ReadingMode.longStripWithGaps: 'Strip + gaps',
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: settings.readingMode == entry.key,
                onSelected: (_) =>
                    onChanged(settings.copyWith(readingMode: entry.key)),
              ),
          ],
        ),
        if (seriesReadingModeSaved) ...[
          const SizedBox(height: 8),
          Text(
            'Saved for this series',
            style: TextStyle(color: c.accent, fontSize: 12),
          ),
        ],
        const SizedBox(height: 24),
        _SectionLabel('Tap zones'),
        const SizedBox(height: 8),
        SegmentedControl<TapZoneMode>(
          segments: const {
            TapZoneMode.leftRight: 'L/R',
            TapZoneMode.leftMiddleRight: 'L/M/R',
          },
          value: _effectiveZones,
          onChanged: (mode) => onChanged(settings.copyWith(tapZones: mode)),
        ),
        const SizedBox(height: 24),
        _SectionLabel('Options'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: AppSpacing.brLg,
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Column(
            children: [
              SettingsRow(
                icon: Icons.menu_book_outlined,
                title: 'Book mode',
                subtitle:
                    'Two pages per spread — starts zoomed out; double-tap to fit',
                trailing: Switch(
                  value: settings.bookMode,
                  activeThumbColor: c.accent,
                  onChanged: (v) =>
                      onChanged(settings.copyWith(bookMode: v)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 1, thickness: 0.5, color: c.border),
              ),
              SettingsRow(
                icon: Icons.crop_outlined,
                title: 'Crop borders',
                subtitle: 'Trim whitespace from images',
                trailing: Switch(
                  value: settings.cropBorders,
                  activeThumbColor: c.accent,
                  onChanged: (v) =>
                      onChanged(settings.copyWith(cropBorders: v)),
                ),
              ),
              if (_isContinuous) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1, thickness: 0.5, color: c.border),
                ),
                SettingsRow(
                  icon: Icons.swipe_vertical_rounded,
                  title: 'Auto-scroll',
                  subtitle: 'Advance continuously in strip modes',
                  trailing: Switch(
                    value: settings.autoScroll,
                    activeThumbColor: c.accent,
                    onChanged: (v) =>
                        onChanged(settings.copyWith(autoScroll: v)),
                  ),
                ),
                if (settings.autoScroll)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Text(
                          'Speed',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: settings.autoScrollSpeed.clamp(0.25, 4.0),
                            min: 0.25,
                            max: 4.0,
                            divisions: 15,
                            label: settings.autoScrollSpeed.toStringAsFixed(2),
                            onChanged: (v) => onChanged(
                              settings.copyWith(autoScrollSpeed: v),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DisplayTab extends StatelessWidget {
  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onChanged;

  const _DisplayTab({required this.settings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _SectionLabel('Rotation'),
        const SizedBox(height: 8),
        SegmentedControl<RotationMode>(
          segments: const {
            RotationMode.portrait: 'Portrait',
            RotationMode.free: 'Free',
            RotationMode.landscape: 'Landscape',
          },
          value: settings.rotationMode,
          onChanged: (mode) =>
              onChanged(settings.copyWith(rotationMode: mode)),
        ),
        const SizedBox(height: 24),
        _SectionLabel('UI options'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: AppSpacing.brLg,
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Column(
            children: [
              SettingsRow(
                icon: Icons.fullscreen,
                title: 'Fullscreen',
                subtitle: 'Hide system bars',
                trailing: Switch(
                  value: settings.fullscreen,
                  activeThumbColor: c.accent,
                  onChanged: (v) =>
                      onChanged(settings.copyWith(fullscreen: v)),
                ),
              ),
              _rowDivider(c),
              SettingsRow(
                icon: Icons.wb_sunny_outlined,
                title: 'Keep screen on',
                subtitle: 'Prevent display sleep',
                trailing: Switch(
                  value: settings.keepScreenOn,
                  activeThumbColor: c.accent,
                  onChanged: (v) =>
                      onChanged(settings.copyWith(keepScreenOn: v)),
                ),
              ),
              _rowDivider(c),
              SettingsRow(
                icon: Icons.pin_outlined,
                title: 'Show page number',
                trailing: Switch(
                  value: settings.showPageNumber,
                  activeThumbColor: c.accent,
                  onChanged: (v) =>
                      onChanged(settings.copyWith(showPageNumber: v)),
                ),
              ),
              _rowDivider(c),
              SettingsRow(
                icon: Icons.animation_outlined,
                title: 'Animated page transition',
                subtitle: 'Animate tap-to-turn (swipes always slide)',
                trailing: Switch(
                  value: settings.animatePageTransition,
                  activeThumbColor: c.accent,
                  onChanged: (v) => onChanged(
                    settings.copyWith(animatePageTransition: v),
                  ),
                ),
              ),
              _rowDivider(c),
              SettingsRow(
                icon: Icons.vibration,
                title: 'Haptic feedback',
                subtitle: 'Vibrate lightly when changing panels',
                trailing: Switch(
                  value: settings.hapticFeedback,
                  activeThumbColor: c.accent,
                  onChanged: (v) =>
                      onChanged(settings.copyWith(hapticFeedback: v)),
                ),
              ),
              _rowDivider(c),
              SettingsRow(
                icon: Icons.tonality_outlined,
                title: 'Sepia on panels',
                subtitle: 'Warm page paper when app theme is sepia',
                trailing: Switch(
                  value: settings.sepiaPanels,
                  activeThumbColor: c.accent,
                  onChanged: (v) =>
                      onChanged(settings.copyWith(sepiaPanels: v)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rowDivider(KomaColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, thickness: 0.5, color: c.border),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: c.textTertiary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

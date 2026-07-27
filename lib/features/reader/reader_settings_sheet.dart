import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum ReadingMode { defaultL2R, rightToLeft, webtoon, longStrip, longStripWithGaps }
enum RotationMode { portrait, free, landscape }
enum TapZoneMode { leftRight, leftTopRightBottom, leftCenterRight }
enum ProgressBarPlacement { horizontalTop, horizontalBottom, verticalLeft, verticalRight }

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
  ProgressBarPlacement progressBarPlacement;
  double brightness;
  double contrast;
  double saturation;
  Color? tintColor;
  double tintOpacity;

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
    this.progressBarPlacement = ProgressBarPlacement.horizontalBottom,
    this.brightness = 1.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
    this.tintColor,
    this.tintOpacity = 0.0,
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
    ProgressBarPlacement? progressBarPlacement,
    double? brightness,
    double? contrast,
    double? saturation,
    Color? tintColor,
    double? tintOpacity,
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
      animatePageTransition: animatePageTransition ?? this.animatePageTransition,
      progressBarPlacement: progressBarPlacement ?? this.progressBarPlacement,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      tintColor: tintColor ?? this.tintColor,
      tintOpacity: tintOpacity ?? this.tintOpacity,
    );
  }

  Map<String, dynamic> toJson() => {
        'readingMode': readingMode.index,
        'rotationMode': rotationMode.index,
        'tapZones': tapZones.index,
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
        'progressBarPlacement': progressBarPlacement.index,
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
        'tintColor': tintColor?.toARGB32(),
        'tintOpacity': tintOpacity,
      };

  factory ReaderSettings.fromJson(Map<String, dynamic> json) => ReaderSettings(
        readingMode: ReadingMode.values[json['readingMode'] as int? ?? 0],
        rotationMode: RotationMode.values[json['rotationMode'] as int? ?? 1],
        tapZones: TapZoneMode.values[json['tapZones'] as int? ?? 1],
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
        progressBarPlacement: ProgressBarPlacement.values[json['progressBarPlacement'] as int? ?? 1],
        brightness: (json['brightness'] as num?)?.toDouble() ?? 1.0,
        contrast: (json['contrast'] as num?)?.toDouble() ?? 1.0,
        saturation: (json['saturation'] as num?)?.toDouble() ?? 1.0,
        tintColor: json['tintColor'] != null ? Color(json['tintColor'] as int) : null,
        tintOpacity: (json['tintOpacity'] as num?)?.toDouble() ?? 0.0,
      );
}

class ReaderSettingsSheet extends StatefulWidget {
  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onChanged;

  const ReaderSettingsSheet({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  @override
  State<ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<ReaderSettingsSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late ReaderSettings _s;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _s = widget.settings;
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged(_s);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: TabBar(
              controller: _tabs,
              indicatorColor: Theme.of(context).colorScheme.primary,
              labelColor: Theme.of(context).colorScheme.onSurface,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              tabs: const [
                Tab(text: 'Reading'),
                Tab(text: 'Display'),
                Tab(text: 'Filters'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ReadingTab(settings: _s, onChanged: (v) { _s = v; _emit(); }),
                _DisplayTab(settings: _s, onChanged: (v) { _s = v; _emit(); }),
                _FilterTab(settings: _s, onChanged: (v) { _s = v; _emit(); }),
              ],
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

  const _ReadingTab({required this.settings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section(context, 'Reading Direction', [
            SegmentedButton<ReadingMode>(
              segments: const [
                ButtonSegment(value: ReadingMode.defaultL2R, label: Text('L→R')),
                ButtonSegment(value: ReadingMode.rightToLeft, label: Text('R→L')),
                ButtonSegment(value: ReadingMode.webtoon, label: Text('Webtoon')),
              ],
              selected: {settings.readingMode},
              onSelectionChanged: (v) {
                final mode = v.firstOrNull ?? ReadingMode.defaultL2R;
                onChanged(ReaderSettings(
                  readingMode: mode,
                  rotationMode: settings.rotationMode,
                  tapZones: settings.tapZones,
                  sidePadding: settings.sidePadding,
                  cropBorders: settings.cropBorders,
                  bookMode: settings.bookMode,
                  disableDoubleTap: settings.disableDoubleTap,
                  disableZoomOut: settings.disableZoomOut,
                  showPageNumber: settings.showPageNumber,
                  showPageNavigator: settings.showPageNavigator,
                  fullscreen: settings.fullscreen,
                  keepScreenOn: settings.keepScreenOn,
                  showActionsOnLongTap: settings.showActionsOnLongTap,
                  animatePageTransition: settings.animatePageTransition,
                  progressBarPlacement: settings.progressBarPlacement,
                  brightness: settings.brightness,
                  contrast: settings.contrast,
                  saturation: settings.saturation,
                  tintColor: settings.tintColor,
                  tintOpacity: settings.tintOpacity,
                ));
              },
            ),
          ]),
          const SizedBox(height: 16),
          _section(context, 'Tap Zones', [
            SegmentedButton<TapZoneMode>(
              segments: const [
                ButtonSegment(value: TapZoneMode.leftRight, label: Text('L/M/R')),
                ButtonSegment(value: TapZoneMode.leftTopRightBottom, label: Text('L/T R/B')),
              ],
              selected: {settings.tapZones},
              onSelectionChanged: (v) {
                final mode = v.firstOrNull ?? TapZoneMode.leftRight;
                onChanged(ReaderSettings(
                  readingMode: settings.readingMode,
                  rotationMode: settings.rotationMode,
                  tapZones: mode,
                  sidePadding: settings.sidePadding,
                  cropBorders: settings.cropBorders,
                  bookMode: settings.bookMode,
                  disableDoubleTap: settings.disableDoubleTap,
                  disableZoomOut: settings.disableZoomOut,
                  showPageNumber: settings.showPageNumber,
                  showPageNavigator: settings.showPageNavigator,
                  fullscreen: settings.fullscreen,
                  keepScreenOn: settings.keepScreenOn,
                  showActionsOnLongTap: settings.showActionsOnLongTap,
                  animatePageTransition: settings.animatePageTransition,
                  progressBarPlacement: settings.progressBarPlacement,
                  brightness: settings.brightness,
                  contrast: settings.contrast,
                  saturation: settings.saturation,
                  tintColor: settings.tintColor,
                  tintOpacity: settings.tintOpacity,
                ));
              },
            ),
          ]),
          const SizedBox(height: 16),
          _section(context, 'Options', [
            SwitchListTile(
              title: const Text('Book Mode'),
              subtitle: const Text('Two pages per spread'),
              value: settings.bookMode,
              onChanged: (v) => onChanged(ReaderSettings(
                readingMode: settings.readingMode,
                rotationMode: settings.rotationMode,
                tapZones: settings.tapZones,
                sidePadding: settings.sidePadding,
                cropBorders: settings.cropBorders,
                bookMode: v,
                disableDoubleTap: settings.disableDoubleTap,
                disableZoomOut: settings.disableZoomOut,
                showPageNumber: settings.showPageNumber,
                showPageNavigator: settings.showPageNavigator,
                fullscreen: settings.fullscreen,
                keepScreenOn: settings.keepScreenOn,
                showActionsOnLongTap: settings.showActionsOnLongTap,
                animatePageTransition: settings.animatePageTransition,
                progressBarPlacement: settings.progressBarPlacement,
                brightness: settings.brightness,
                contrast: settings.contrast,
                saturation: settings.saturation,
                tintColor: settings.tintColor,
                tintOpacity: settings.tintOpacity,
              )),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Crop Borders'),
              subtitle: const Text('Trim whitespace from images'),
              value: settings.cropBorders,
              onChanged: (v) => onChanged(ReaderSettings(
                readingMode: settings.readingMode,
                rotationMode: settings.rotationMode,
                tapZones: settings.tapZones,
                sidePadding: settings.sidePadding,
                cropBorders: v,
                bookMode: settings.bookMode,
                disableDoubleTap: settings.disableDoubleTap,
                disableZoomOut: settings.disableZoomOut,
                showPageNumber: settings.showPageNumber,
                showPageNavigator: settings.showPageNavigator,
                fullscreen: settings.fullscreen,
                keepScreenOn: settings.keepScreenOn,
                showActionsOnLongTap: settings.showActionsOnLongTap,
                animatePageTransition: settings.animatePageTransition,
                progressBarPlacement: settings.progressBarPlacement,
                brightness: settings.brightness,
                contrast: settings.contrast,
                saturation: settings.saturation,
                tintColor: settings.tintColor,
                tintOpacity: settings.tintOpacity,
              )),
              contentPadding: EdgeInsets.zero,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...children,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section(context, 'Rotation', [
            SegmentedButton<RotationMode>(
              segments: const [
                ButtonSegment(value: RotationMode.portrait, label: Text('Portrait')),
                ButtonSegment(value: RotationMode.free, label: Text('Free')),
                ButtonSegment(value: RotationMode.landscape, label: Text('Landscape')),
              ],
              selected: {settings.rotationMode},
              onSelectionChanged: (v) {
                final mode = v.firstOrNull ?? RotationMode.free;
                onChanged(ReaderSettings(
                  readingMode: settings.readingMode,
                  rotationMode: mode,
                  tapZones: settings.tapZones,
                  sidePadding: settings.sidePadding,
                  cropBorders: settings.cropBorders,
                  bookMode: settings.bookMode,
                  disableDoubleTap: settings.disableDoubleTap,
                  disableZoomOut: settings.disableZoomOut,
                  showPageNumber: settings.showPageNumber,
                  showPageNavigator: settings.showPageNavigator,
                  fullscreen: settings.fullscreen,
                  keepScreenOn: settings.keepScreenOn,
                  showActionsOnLongTap: settings.showActionsOnLongTap,
                  animatePageTransition: settings.animatePageTransition,
                  progressBarPlacement: settings.progressBarPlacement,
                  brightness: settings.brightness,
                  contrast: settings.contrast,
                  saturation: settings.saturation,
                  tintColor: settings.tintColor,
                  tintOpacity: settings.tintOpacity,
                ));
              },
            ),
          ]),
          const SizedBox(height: 16),
          _section(context, 'UI Options', [
            SwitchListTile(
              title: const Text('Fullscreen'),
              subtitle: const Text('Hide system bars'),
              value: settings.fullscreen,
              onChanged: (v) => onChanged(_copy(fullscreen: v)),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Keep Screen On'),
              subtitle: const Text('Prevent display sleep'),
              value: settings.keepScreenOn,
              onChanged: (v) => onChanged(_copy(keepScreenOn: v)),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Show Page Number'),
              value: settings.showPageNumber,
              onChanged: (v) => onChanged(_copy(showPageNumber: v)),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Animated Page Transition'),
              value: settings.animatePageTransition,
              onChanged: (v) => onChanged(_copy(animatePageTransition: v)),
              contentPadding: EdgeInsets.zero,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  ReaderSettings _copy({bool? fullscreen, bool? keepScreenOn, bool? showPageNumber, bool? animatePageTransition}) {
    return settings.copyWith(fullscreen: fullscreen, keepScreenOn: keepScreenOn, showPageNumber: showPageNumber, animatePageTransition: animatePageTransition);
  }
}

class _FilterTab extends StatelessWidget {
  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onChanged;

  const _FilterTab({required this.settings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          _slider(context, 'Brightness', settings.brightness, 0.5, 1.5, (v) => onChanged(ReaderSettings(
            readingMode: settings.readingMode,
            rotationMode: settings.rotationMode,
            tapZones: settings.tapZones,
            sidePadding: settings.sidePadding,
            cropBorders: settings.cropBorders,
            bookMode: settings.bookMode,
            disableDoubleTap: settings.disableDoubleTap,
            disableZoomOut: settings.disableZoomOut,
            showPageNumber: settings.showPageNumber,
            showPageNavigator: settings.showPageNavigator,
            fullscreen: settings.fullscreen,
            keepScreenOn: settings.keepScreenOn,
            showActionsOnLongTap: settings.showActionsOnLongTap,
            animatePageTransition: settings.animatePageTransition,
            progressBarPlacement: settings.progressBarPlacement,
            brightness: v,
            contrast: settings.contrast,
            saturation: settings.saturation,
            tintColor: settings.tintColor,
            tintOpacity: settings.tintOpacity,
          ))),
          _slider(context, 'Contrast', settings.contrast, 0.5, 1.5, (v) => onChanged(ReaderSettings(
            readingMode: settings.readingMode,
            rotationMode: settings.rotationMode,
            tapZones: settings.tapZones,
            sidePadding: settings.sidePadding,
            cropBorders: settings.cropBorders,
            bookMode: settings.bookMode,
            disableDoubleTap: settings.disableDoubleTap,
            disableZoomOut: settings.disableZoomOut,
            showPageNumber: settings.showPageNumber,
            showPageNavigator: settings.showPageNavigator,
            fullscreen: settings.fullscreen,
            keepScreenOn: settings.keepScreenOn,
            showActionsOnLongTap: settings.showActionsOnLongTap,
            animatePageTransition: settings.animatePageTransition,
            progressBarPlacement: settings.progressBarPlacement,
            brightness: settings.brightness,
            contrast: v,
            saturation: settings.saturation,
            tintColor: settings.tintColor,
            tintOpacity: settings.tintOpacity,
          ))),
          _slider(context, 'Saturation', settings.saturation, 0.0, 2.0, (v) => onChanged(ReaderSettings(
            readingMode: settings.readingMode,
            rotationMode: settings.rotationMode,
            tapZones: settings.tapZones,
            sidePadding: settings.sidePadding,
            cropBorders: settings.cropBorders,
            bookMode: settings.bookMode,
            disableDoubleTap: settings.disableDoubleTap,
            disableZoomOut: settings.disableZoomOut,
            showPageNumber: settings.showPageNumber,
            showPageNavigator: settings.showPageNavigator,
            fullscreen: settings.fullscreen,
            keepScreenOn: settings.keepScreenOn,
            showActionsOnLongTap: settings.showActionsOnLongTap,
            animatePageTransition: settings.animatePageTransition,
            progressBarPlacement: settings.progressBarPlacement,
            brightness: settings.brightness,
            contrast: settings.contrast,
            saturation: v,
            tintColor: settings.tintColor,
            tintOpacity: settings.tintOpacity,
          ))),
        ],
      ),
    );
  }

  Widget _slider(BuildContext context, String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// ── Settings model ─────────────────────────────────────────────────────
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
  });

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
      );
}

enum ReadingMode { defaultL2R, rightToLeft, webtoon, longStrip, longStripWithGaps }

enum RotationMode { portrait, free, landscape }

enum TapZoneMode { leftRight, leftTopRightBottom, leftCenterRight }

enum ProgressBarPlacement { horizontalTop, horizontalBottom, verticalLeft, verticalRight }

// ── Settings bottom sheet ──────────────────────────────────────────────
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
    _tabs = TabController(length: 2, vsync: this);
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
            child: SafeArea(
              bottom: false,
              child: TabBar(
                controller: _tabs,
                indicatorColor: c.accent,
                labelColor: c.accent,
                unselectedLabelColor: c.textSecondary,
                tabs: const [
                  Tab(text: 'Reading'),
                  Tab(text: 'Other'),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ReadingTab(settings: _s, onChange: () => setState(_emit)),
                _OtherTab(settings: _s, onChange: () => setState(_emit)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reading tab ────────────────────────────────────────────────────────
class _ReadingTab extends StatelessWidget {
  final ReaderSettings settings;
  final VoidCallback onChange;

  const _ReadingTab({required this.settings, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionLabel(c, 'Reading mode'),
        const SizedBox(height: 8),
        _ChipRow(
          options: ReadingMode.values,
          labels: const ['Default (L2R)', 'Right to left', 'Webtoon', 'Long strip', 'Long strip w/ gaps'],
          selected: settings.readingMode.index,
          onSelect: (i) {
            settings.readingMode = ReadingMode.values[i];
            onChange();
          },
        ),
        const SizedBox(height: 20),
        _SectionLabel(c, 'Rotation'),
        const SizedBox(height: 8),
        _ChipRow(
          options: RotationMode.values,
          labels: const ['Portrait', 'Free', 'Landscape'],
          selected: settings.rotationMode.index,
          onSelect: (i) {
            settings.rotationMode = RotationMode.values[i];
            onChange();
          },
        ),
        const SizedBox(height: 20),
        _SectionLabel(c, 'Tap zones'),
        const SizedBox(height: 8),
        _ChipRow(
          options: TapZoneMode.values,
          labels: const ['Left/Right', 'Left/Top · Right/Bottom', 'Left/Center/Right'],
          selected: settings.tapZones.index,
          onSelect: (i) {
            settings.tapZones = TapZoneMode.values[i];
            onChange();
          },
        ),
        const SizedBox(height: 20),
        _SectionLabel(c, 'Side padding'),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: 8),
            Text('0%', style: TextStyle(color: c.textTertiary, fontSize: 12)),
            Expanded(
              child: Slider(
                value: settings.sidePadding,
                min: 0,
                max: 0.3,
                divisions: 30,
                activeColor: c.accent,
                onChanged: (v) {
                  settings.sidePadding = v;
                  onChange();
                },
              ),
            ),
            Text('30%', style: TextStyle(color: c.textTertiary, fontSize: 12)),
            const SizedBox(width: 8),
            Text('${(settings.sidePadding * 100).round()}%',
                style: TextStyle(color: c.textPrimary, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 12),
        _CheckboxTile(c, 'Crop borders', settings.cropBorders, (v) {
          settings.cropBorders = v;
          onChange();
        }),
        _CheckboxTile(c, 'Book mode (2 pages in landscape)', settings.bookMode, (v) {
          settings.bookMode = v;
          onChange();
        }),
        _CheckboxTile(c, 'Disable double tap to zoom', settings.disableDoubleTap, (v) {
          settings.disableDoubleTap = v;
          onChange();
        }),
        _CheckboxTile(c, 'Disable zoom out', settings.disableZoomOut, (v) {
          settings.disableZoomOut = v;
          onChange();
        }),
      ],
    );
  }
}

// ── Other tab ─────────────────────────────────────────────────────────
class _OtherTab extends StatelessWidget {
  final ReaderSettings settings;
  final VoidCallback onChange;

  const _OtherTab({required this.settings, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CheckboxTile(c, 'Show page number', settings.showPageNumber, (v) {
          settings.showPageNumber = v;
          onChange();
        }),
        _CheckboxTile(c, 'Show page navigator', settings.showPageNavigator, (v) {
          settings.showPageNavigator = v;
          onChange();
        }),
        _CheckboxTile(c, 'Fullscreen', settings.fullscreen, (v) {
          settings.fullscreen = v;
          onChange();
        }),
        _CheckboxTile(c, 'Keep screen on', settings.keepScreenOn, (v) {
          settings.keepScreenOn = v;
          onChange();
        }),
        _CheckboxTile(c, 'Show actions on long tap', settings.showActionsOnLongTap, (v) {
          settings.showActionsOnLongTap = v;
          onChange();
        }),
        _CheckboxTile(c, 'Animate page transition', settings.animatePageTransition, (v) {
          settings.animatePageTransition = v;
          onChange();
        }),
        const SizedBox(height: 20),
        _SectionLabel(c, 'Progress bar placement'),
        const SizedBox(height: 8),
        _ChipRow(
          options: [0, 1, 2, 3],
          labels: const ['Horizontal top', 'Horizontal bottom', 'Vertical left', 'Vertical right'],
          selected: settings.progressBarPlacement.index,
          onSelect: (i) {
            settings.progressBarPlacement = ProgressBarPlacement.values[i];
            onChange();
          },
        ),
      ],
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final KomaColors c;
  final String label;
  const _SectionLabel(this.c, this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: TextStyle(
            color: c.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600));
  }
}

class _ChipRow extends StatelessWidget {
  final List<dynamic> options;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  const _ChipRow({
    required this.options,
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: List.generate(labels.length, (i) {
        final active = i == selected;
        return ChoiceChip(
          label: Text(labels[i], style: TextStyle(fontSize: 12, color: active ? c.onAccent : c.textPrimary)),
          selected: active,
          selectedColor: c.accent,
          backgroundColor: c.surfaceMuted,
          onSelected: (_) => onSelect(i),
        );
      }),
    );
  }
}

class _CheckboxTile extends StatelessWidget {
  final KomaColors c;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CheckboxTile(this.c, this.title, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          SizedBox(
            height: 24,
            width: 24,
            child: Checkbox(
              value: value,
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              activeColor: c.accent,
              side: BorderSide(color: c.textTertiary),
            ),
          ),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(color: c.textPrimary, fontSize: 14)),
        ],
      ),
    );
  }
}

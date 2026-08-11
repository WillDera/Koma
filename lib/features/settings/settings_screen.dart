import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/source.dart';
import '../../core/providers.dart';
import '../../core/services/export_service.dart';
import '../../core/services/extension_manager.dart';
import '../../core/services/keiyoushi_service.dart';
import '../../core/services/library_update_prefs.dart';
import '../../core/services/metadata_enrichment_service.dart';
import '../../core/services/source_service.dart';
import '../../router/router.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens/app_colors.dart';
import '../../theme/tokens/app_motion.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../theme/tokens/app_type.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/dialog_sheet.dart';
import '../../widgets/library_book_card.dart';
import '../../widgets/library_header.dart';
import '../../widgets/one_hand_spacer.dart';
import '../../widgets/reading_streak_card.dart';
import '../../widgets/screen_chrome.dart';
import '../../widgets/segmented_control.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/toast.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenBackdrop(
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            const OneHandSpacer(),
            const LibraryHeader(
              title: 'Settings',
              subtitle: 'Customize your reading experience',
              padding: EdgeInsets.fromLTRB(20, 8, 16, 12),
            ),
            const StaggeredEntrance(index: 0, child: _ThemePreviewPill()),
            const SizedBox(height: 16),
            const StaggeredEntrance(index: 1, child: _SettingsHub()),
          ],
        ),
      ),
    );
  }
}

class _ThemePreviewPill extends ConsumerWidget {
  const _ThemePreviewPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final theme = ref.watch(themeProvider);
    final modeLabel = switch (theme.themeMode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'Auto',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.accentMuted,
          borderRadius: AppSpacing.brLg,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: AppSpacing.brMd,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$modeLabel theme',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${theme.readingFont.label} · ${theme.fontSize.toInt()}px · ${theme.lineHeight.toStringAsFixed(2)}× leading',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsHub extends StatelessWidget {
  const _SettingsHub();

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Settings',
      showHeader: false,
      children: [
        SettingsRow(
          icon: Icons.palette_outlined,
          iconColor: AppColors.figmaViolet,
          title: 'Appearance',
          subtitle: 'Theme, accent, single hand mode',
          onTap: () => _open(context, 'Appearance', const _AppearanceSection()),
        ),
        SettingsRow(
          icon: Icons.text_fields_rounded,
          iconColor: AppColors.figmaGreen,
          title: 'Typography',
          subtitle: 'Font, size, line height, bionic reading',
          onTap: () => _open(context, 'Typography', const _TypographySection()),
        ),
        SettingsRow(
          icon: Icons.storage_outlined,
          iconColor: AppColors.figmaAmber,
          title: 'Data',
          subtitle: 'Export and import your library data',
          onTap: () => _open(context, 'Data', const _DataAndStatsPage()),
        ),
        SettingsRow(
          icon: Icons.layers_outlined,
          iconColor: AppColors.figmaCyan,
          title: 'Sources',
          subtitle: 'Ebook sources and manga plugins',
          onTap: () =>
              _open(context, 'Sources', const _SourcesAndPluginsPage()),
        ),
        SettingsRow(
          icon: Icons.info_outline_rounded,
          iconColor: const Color(0xFF8888A0),
          title: 'About',
          subtitle: 'App info, version, credits',
          onTap: () => _open(context, 'About', const _AboutSection()),
        ),
      ],
    );
  }

  void _open(BuildContext context, String title, Widget child) {
    // rootNavigator: true so the settings sub-page covers the bottom nav,
    // matching pre-go_router full-screen behavior (the Settings tab now
    // has its own nested Navigator under the StatefulShellRoute).
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => _SettingsDestinationScreen(title: title, child: child),
      ),
    );
  }
}

class _SettingsDestinationScreen extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsDestinationScreen({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ScreenBackdrop(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const OneHandSpacer(),
              LibraryHeader(
                title: title,
                showBackButton: true,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _DataAndStatsPage extends StatelessWidget {
  const _DataAndStatsPage();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _DataSection(),
        SizedBox(height: 20),
        _DownloadQueueSection(),
        SizedBox(height: 20),
        _LibraryUpdateSection(),
        SizedBox(height: 20),
        _BookMetadataSection(),
        SizedBox(height: 20),
        _StatsSection(),
      ],
    );
  }
}

class _SourcesAndPluginsPage extends StatelessWidget {
  const _SourcesAndPluginsPage();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [_SourcesSection(), SizedBox(height: 20), _PluginsSection()],
    );
  }
}

// ─── Appearance ──────────────────────────────────────────────────────────
class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  static const _pad = EdgeInsets.symmetric(horizontal: 16);
  static const _gap = SizedBox(height: 20);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final theme = ref.watch(themeProvider);
    final tn = ref.read(themeProvider.notifier);
    final library = ref.watch(libraryProvider);
    final ln = ref.read(libraryProvider.notifier);
    final violet = AppColors.figmaViolet;

    return Column(
      children: [
        SettingsSection(
          title: 'Theme',
          headerColor: violet,
          padding: _pad,
          children: [
            _ThemeModePicker(
              value: theme.themeMode,
              onChanged: tn.setThemeMode,
            ),
            SettingsRow(
              title: 'Sepia mode',
              subtitle: 'Warm paper-like background',
              trailing: Switch(
                value: theme.sepiaMode,
                activeThumbColor: c.accent,
                onChanged: tn.setSepiaMode,
              ),
            ),
            SettingsRow(
              title: 'AMOLED dark mode',
              subtitle: 'True black for OLED screens',
              trailing: Switch(
                value: theme.amoledMode,
                activeThumbColor: c.accent,
                onChanged: tn.setAmoledMode,
              ),
            ),
            SettingsRow(
              title: 'Use device font',
              subtitle: 'System default instead of Inter',
              trailing: Switch(
                value: theme.useDeviceFont,
                activeThumbColor: c.accent,
                onChanged: tn.setUseDeviceFont,
              ),
            ),
          ],
        ),
        _gap,
        SettingsSection(
          title: 'Accent color',
          headerColor: violet,
          padding: _pad,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Used for highlights, selections, and the active state.',
                    style: TextStyle(color: c.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (final entry in const [
                        (
                          AccentPreset.indigo,
                          AppColors.accentIndigo,
                          AppColors.accentIndigoDark,
                          'Indigo',
                        ),
                        (
                          AccentPreset.amber,
                          AppColors.accentAmber,
                          AppColors.accentAmberDark,
                          'Amber',
                        ),
                        (
                          AccentPreset.forest,
                          AppColors.accentForest,
                          AppColors.accentForestDark,
                          'Forest',
                        ),
                        (
                          AccentPreset.aethelgard,
                          AppColors.aethelgardPrimary,
                          AppColors.aethelgardPrimaryDark,
                          'Neo-Noir',
                        ),
                      ]) ...[
                        _AccentSwatch(
                          light: entry.$2,
                          dark: entry.$3,
                          label: entry.$4,
                          selected:
                              theme.customAccentHex == null &&
                              theme.accent == entry.$1,
                          onTap: () => tn.setAccent(entry.$1),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Custom color',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _CustomAccentPicker(
                    current: theme.customAccentHex,
                    fallback: theme.accentColor,
                    onSubmit: tn.setCustomAccentHex,
                  ),
                ],
              ),
            ),
          ],
        ),
        _gap,
        SettingsSection(
          title: 'Ergonomics',
          headerColor: violet,
          padding: _pad,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dominant hand',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Floating buttons on your preferred side for one-thumb reach.',
                    style: TextStyle(color: c.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  SegmentedControl<HandMode>(
                    segments: const {
                      HandMode.right: 'Right',
                      HandMode.left: 'Left',
                    },
                    value: theme.handMode,
                    onChanged: tn.setHandMode,
                  ),
                ],
              ),
            ),
            const _OneHandToggle(),
          ],
        ),
        _gap,
        SettingsSection(
          title: 'Library',
          headerColor: violet,
          padding: _pad,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Library grid',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedControl<int>(
                    segments: const {2: '2 cols', 3: '3 cols'},
                    value: library.gridColumns,
                    onChanged: (v) => ln.setGridColumns(v),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Card style',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedControl<LibraryCardVariant>(
                    segments: const {
                      LibraryCardVariant.grid: 'Grid',
                      LibraryCardVariant.list: 'List',
                      LibraryCardVariant.compact: 'Compact',
                      LibraryCardVariant.overlay: 'Overlay',
                    },
                    value: library.cardVariant,
                    onChanged: (v) => ln.setCardVariant(v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Figma-style 3-column Light / Dark / System theme cards.
class _ThemeModePicker extends StatelessWidget {
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeModePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const options = <(ThemeMode, String, IconData)>[
      (ThemeMode.light, 'Light', Icons.wb_sunny_outlined),
      (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
      (ThemeMode.system, 'System', Icons.desktop_windows_outlined),
    ];
    // Match SettingsSection card corners (brLg) on the end cells.
    final endRadius = Radius.circular(AppSpacing.radiusLg);
    return IntrinsicHeight(
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            Expanded(
              child: AnimatedPress(
                onTap: () => onChanged(options[i].$1),
                child: AnimatedContainer(
                  duration: AppMotion.base,
                  curve: AppMotion.standard,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: value == options[i].$1
                        ? c.accent.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.only(
                      topLeft: i == 0 ? endRadius : Radius.zero,
                      topRight: i == options.length - 1
                          ? endRadius
                          : Radius.zero,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        options[i].$3,
                        size: 20,
                        color: value == options[i].$1
                            ? c.accent
                            : c.textSecondary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        options[i].$2,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: value == options[i].$1
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: value == options[i].$1
                              ? c.accent
                              : c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (i < options.length - 1)
              VerticalDivider(
                width: 0.5,
                thickness: 0.5,
                color: c.border,
              ),
          ],
        ],
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  final Color light;
  final Color dark;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AccentSwatch({
    required this.light,
    required this.dark,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? dark : light;
    return AnimatedPress(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: AppMotion.base,
            curve: AppMotion.standard,
            padding: selected ? const EdgeInsets.all(3) : EdgeInsets.zero,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(selected ? 14 : 10),
              border: selected
                  ? Border.all(color: color, width: 2)
                  : Border.all(color: Colors.transparent, width: 0),
            ),
            child: AnimatedContainer(
              duration: AppMotion.base,
              curve: AppMotion.standard,
              width: selected ? 40 : 44,
              height: selected ? 40 : 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: AppSpacing.brMd,
                border: Border.all(
                  color: selected ? Colors.transparent : c.border,
                  width: selected ? 0 : 1,
                ),
              ),
              child: selected
                  ? Icon(
                      Icons.check,
                      size: 18,
                      color: color.computeLuminance() > 0.5
                          ? const Color(0xFF1A1815)
                          : Colors.white,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: selected ? color : c.textSecondary,
              fontSize: 10,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomAccentPicker extends StatefulWidget {
  final String? current;
  final Color fallback;
  final ValueChanged<String?> onSubmit;

  const _CustomAccentPicker({
    required this.current,
    required this.fallback,
    required this.onSubmit,
  });

  @override
  State<_CustomAccentPicker> createState() => _CustomAccentPickerState();
}

class _CustomAccentPickerState extends State<_CustomAccentPicker> {
  Color? _draft;

  @override
  void initState() {
    super.initState();
    _draft = ThemeState.resolveHex(widget.current ?? '');
  }

  @override
  void didUpdateWidget(covariant _CustomAccentPicker old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current) {
      _draft = ThemeState.resolveHex(widget.current ?? '');
    }
  }

  String _toHex(Color color) {
    final r = ((color.r * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
    final g = ((color.g * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
    final b = ((color.b * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
    return '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }

  Future<void> _openPicker() async {
    final initial = _draft ??
        ThemeState.resolveHex(widget.current ?? '') ??
        widget.fallback;
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) => _AccentColorPickerDialog(initial: initial),
    );
    if (picked == null || !mounted) return;
    setState(() => _draft = picked);
  }

  void _apply() {
    final draft = _draft;
    if (draft == null) return;
    widget.onSubmit(_toHex(draft));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final preview = _draft ??
        ThemeState.resolveHex(widget.current ?? '') ??
        widget.fallback;
    final hex = _draft != null
        ? _toHex(_draft!)
        : (widget.current?.trim().isNotEmpty == true
            ? widget.current!.trim()
            : null);
    final canApply = _draft != null;

    return Row(
      children: [
        AnimatedPress(
          onTap: _openPicker,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: preview,
              borderRadius: AppSpacing.brSm,
              border: Border.all(color: c.border, width: 0.5),
            ),
            child: Icon(
              Icons.colorize_rounded,
              size: 18,
              color: preview.computeLuminance() > 0.5
                  ? const Color(0xFF1A1815)
                  : Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AnimatedPress(
            onTap: _openPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: c.surfaceMuted,
                borderRadius: AppSpacing.brSm,
                border: Border.all(color: c.border, width: 0.5),
              ),
              child: Text(
                hex ?? 'Tap to pick a color',
                style: TextStyle(
                  color: hex != null ? c.textPrimary : c.textTertiary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedPress(
          onTap: canApply ? _apply : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: canApply ? c.accent : c.surfaceMuted,
              borderRadius: AppSpacing.brPill,
            ),
            child: Text(
              'Apply',
              style: TextStyle(
                color: canApply ? c.onAccent : c.textTertiary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AccentColorPickerDialog extends StatefulWidget {
  final Color initial;
  const _AccentColorPickerDialog({required this.initial});

  @override
  State<_AccentColorPickerDialog> createState() =>
      _AccentColorPickerDialogState();
}

class _AccentColorPickerDialogState extends State<_AccentColorPickerDialog> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
  }

  String _toHex(Color color) {
    final r = ((color.r * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
    final g = ((color.g * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
    final b = ((color.b * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
    return '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = _hsv.toColor();
    return AlertDialog(
      backgroundColor: c.surface,
      title: Text('Pick accent color', style: TextStyle(color: c.textPrimary)),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1.2,
              child: _SvPicker(
                hsv: _hsv,
                onChanged: (v) => setState(() => _hsv = v),
              ),
            ),
            const SizedBox(height: 14),
            _HueSlider(
              hue: _hsv.hue,
              onChanged: (h) => setState(() => _hsv = _hsv.withHue(h)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: AppSpacing.brSm,
                    border: Border.all(color: c.border, width: 0.5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _toHex(color),
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, color),
          child: Text('Select', style: TextStyle(color: c.accent)),
        ),
      ],
    );
  }
}

class _HueSlider extends StatelessWidget {
  final double hue;
  final ValueChanged<double> onChanged;
  const _HueSlider({required this.hue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) {
              final local = (d.localPosition.dx).clamp(0.0, w);
              onChanged((local / w) * 360.0);
            },
            onTapDown: (d) {
              final local = d.localPosition.dx.clamp(0.0, w);
              onChanged((local / w) * 360.0);
            },
            child: CustomPaint(
              size: Size(w, 28),
              painter: _HueTrackPainter(hue: hue),
            ),
          );
        },
      ),
    );
  }
}

class _HueTrackPainter extends CustomPainter {
  final double hue;
  const _HueTrackPainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 8, size.width, 12),
      const Radius.circular(6),
    );
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFF0000),
          Color(0xFFFFFF00),
          Color(0xFF00FF00),
          Color(0xFF00FFFF),
          Color(0xFF0000FF),
          Color(0xFFFF00FF),
          Color(0xFFFF0000),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(r, paint);
    final x = (hue / 360.0).clamp(0.0, 1.0) * size.width;
    canvas.drawCircle(
      Offset(x, size.height / 2),
      10,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(x, size.height / 2),
      10,
      Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _HueTrackPainter old) => old.hue != hue;
}

class _SvPicker extends StatelessWidget {
  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;
  const _SvPicker({required this.hsv, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        void update(Offset local) {
          final s = (local.dx / size.width).clamp(0.0, 1.0);
          final v = 1.0 - (local.dy / size.height).clamp(0.0, 1.0);
          onChanged(hsv.withSaturation(s).withValue(v));
        }

        return GestureDetector(
          onPanDown: (d) => update(d.localPosition),
          onPanUpdate: (d) => update(d.localPosition),
          child: CustomPaint(
            size: size,
            painter: _SvPainter(hsv: hsv),
          ),
        );
      },
    );
  }
}

class _SvPainter extends CustomPainter {
  final HSVColor hsv;
  const _SvPainter({required this.hsv});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.save();
    canvas.clipRRect(rrect);

    final hueColor = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();
    canvas.drawRect(rect, Paint()..color = hueColor);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, Colors.white.withValues(alpha: 0)],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );

    final cx = hsv.saturation * size.width;
    final cy = (1.0 - hsv.value) * size.height;
    canvas.drawCircle(
      Offset(cx, cy),
      9,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      9,
      Paint()
        ..color = Colors.black38
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SvPainter old) =>
      old.hsv.hue != hsv.hue ||
      old.hsv.saturation != hsv.saturation ||
      old.hsv.value != hsv.value;
}

class _OneHandToggle extends ConsumerWidget {
  const _OneHandToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final tn = ref.read(themeProvider.notifier);
    final c = context.colors;
    return SettingsRow(
      title: 'Single hand mode',
      subtitle:
          'Pushes content toward the bottom half of the screen for easier thumb reach.',
      trailing: Switch(
        value: theme.oneHandMode,
        activeThumbColor: c.accent,
        onChanged: tn.setOneHandMode,
      ),
    );
  }
}

// ─── Typography ──────────────────────────────────────────────────────────
class _TypographySection extends ConsumerWidget {
  const _TypographySection();

  static const _pad = EdgeInsets.symmetric(horizontal: 16);
  static const _gap = SizedBox(height: 20);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(themeProvider);
    final tn = ref.read(themeProvider.notifier);
    final green = AppColors.figmaGreen;
    return Column(
      children: [
        SettingsSection(
          title: 'Reading font',
          headerColor: green,
          padding: _pad,
          children: [
            SettingsRow(
              icon: Icons.text_fields,
              iconColor: green,
              title: 'Reading font',
              subtitle: p.readingFont.label,
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => _showFontPicker(context, ref, p),
            ),
          ],
        ),
        _gap,
        SettingsSection(
          title: 'Layout',
          headerColor: green,
          padding: _pad,
          children: [
            SettingsRow(
              icon: Icons.format_size,
              iconColor: green,
              title: 'Font size',
              subtitle: '${p.fontSize.toInt()}px',
              trailing: SizedBox(
                width: 110,
                child: Slider(
                  value: p.fontSize,
                  min: 13,
                  max: 26,
                  divisions: 13,
                  activeColor: green,
                  onChanged: tn.setFontSize,
                ),
              ),
            ),
            SettingsRow(
              icon: Icons.format_line_spacing,
              iconColor: green,
              title: 'Line height',
              subtitle: '${p.lineHeight.toStringAsFixed(2)}×',
              trailing: SizedBox(
                width: 110,
                child: Slider(
                  value: p.lineHeight,
                  min: 1.2,
                  max: 2.2,
                  divisions: 10,
                  activeColor: green,
                  onChanged: tn.setLineHeight,
                ),
              ),
            ),
            SettingsRow(
              icon: Icons.width_normal,
              iconColor: green,
              title: 'Page width',
              subtitle: '${p.pageWidth.toInt()}px',
              trailing: SizedBox(
                width: 110,
                child: Slider(
                  value: p.pageWidth,
                  min: 520,
                  max: 760,
                  divisions: 12,
                  activeColor: green,
                  onChanged: tn.setPageWidth,
                ),
              ),
            ),
          ],
        ),
        _gap,
        SettingsSection(
          title: 'Reading mode',
          headerColor: green,
          padding: _pad,
          children: [
            SettingsRow(
              icon: Icons.bolt,
              iconColor: green,
              title: 'Bionic reading',
              subtitle: 'Bold the first 40% of every word',
              trailing: Switch(
                value: p.bionicReading,
                activeThumbColor: green,
                onChanged: tn.setBionicReading,
              ),
            ),
            SettingsRow(
              icon: Icons.format_align_left,
              iconColor: green,
              title: 'Text alignment',
              subtitle: _alignName(p.textAlign),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => _showAlignPicker(context, ref, p),
            ),
          ],
        ),
      ],
    );
  }

  String _alignName(TextAlign a) {
    switch (a) {
      case TextAlign.left:
        return 'Left';
      case TextAlign.justify:
        return 'Justify';
      case TextAlign.center:
        return 'Center';
      case TextAlign.right:
        return 'Right';
      case TextAlign.start:
        return 'Start';
      case TextAlign.end:
        return 'End';
    }
  }

  void _showFontPicker(BuildContext context, WidgetRef ref, ThemeState p) {
    final tn = ref.read(themeProvider.notifier);
    StashSheet.show<void>(
      context,
      title: 'Reading font',
      subtitle: 'Choose a face for long-form reading.',
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          for (final f in ReadingFont.values) ...[
            AnimatedPress(
              onTap: () {
                tn.setReadingFont(f);
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: p.readingFont == f
                      ? context.colors.accentMuted
                      : context.colors.surface,
                  borderRadius: AppSpacing.brLg,
                  border: Border.all(
                    color: p.readingFont == f
                        ? context.colors.accent
                        : context.colors.border,
                    width: p.readingFont == f ? 1.2 : 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.label,
                            style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Aa — long-form sample text',
                              style: AppType.fontStyle(
                                fontFamily: f.googleFontFamily,
                                fontSize: 15,
                                lineHeight: 1.4,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (p.readingFont == f)
                      Icon(Icons.check, color: context.colors.accent, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAlignPicker(BuildContext context, WidgetRef ref, ThemeState p) {
    final tn = ref.read(themeProvider.notifier);
    final c = context.colors;
    final options = const [
      (TextAlign.left, 'Left', Icons.format_align_left),
      (TextAlign.justify, 'Justify', Icons.format_align_justify),
      (TextAlign.center, 'Center', Icons.format_align_center),
    ];
    StashSheet.show<void>(
      context,
      title: 'Text alignment',
      subtitle: 'How chapter text is aligned.',
      initialChildSize: 0.5,
      maxChildSize: 0.7,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          for (final o in options) ...[
            AnimatedPress(
              onTap: () {
                tn.setTextAlign(o.$1);
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: p.textAlign == o.$1 ? c.accentMuted : c.surface,
                  borderRadius: AppSpacing.brLg,
                  border: Border.all(
                    color: p.textAlign == o.$1 ? c.accent : c.border,
                    width: p.textAlign == o.$1 ? 1.2 : 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.surfaceMuted,
                        borderRadius: AppSpacing.brSm,
                      ),
                      child: Icon(o.$3, size: 20, color: c.textPrimary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.$2,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sample preview paragraph for ${o.$2.toLowerCase()} alignment.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (p.textAlign == o.$1)
                      Icon(Icons.check, color: c.accent, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Book metadata (Open Library / Google Books via Rust engine) ───────
class _BookMetadataSection extends ConsumerStatefulWidget {
  const _BookMetadataSection();

  @override
  ConsumerState<_BookMetadataSection> createState() =>
      _BookMetadataSectionState();
}

class _BookMetadataSectionState extends ConsumerState<_BookMetadataSection> {
  late final TextEditingController _apiKeyCtrl;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _apiKeyCtrl = TextEditingController();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      _apiKeyCtrl.text = prefs.getString(kGoogleBooksApiKeyPref) ?? '';
      setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveKey(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(kGoogleBooksApiKeyPref);
    } else {
      await prefs.setString(kGoogleBooksApiKeyPref, trimmed);
    }
  }

  Future<void> _fetchAll() async {
    final books = ref.read(libraryProvider).books;
    if (books.isEmpty) {
      if (!mounted) return;
      StashToast.show(
        context,
        message: 'No books in library',
        icon: Icons.info_outline,
      );
      return;
    }
    final enrichment = ref.read(metadataEnrichmentProvider.notifier);
    await enrichment.enrichAll(books);
    await ref.read(libraryProvider.notifier).loadBooks();
    if (!mounted) return;
    final progress = ref.read(metadataEnrichmentProvider);
    StashToast.show(
      context,
      message: progress.lastMessage ?? 'Done',
      icon: progress.errors.isEmpty ? Icons.auto_awesome : Icons.error_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final progress = ref.watch(metadataEnrichmentProvider);
    return SettingsSection(
      title: 'Book metadata',
      headerColor: AppColors.figmaAmber,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      footer:
          'Looks up author, cover, genres, and release date via Open Library (primary) and Google Books (fallback). An API key improves Google Books rate limits but is optional.',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _apiKeyCtrl,
            enabled: _loaded && !progress.running,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Google Books API key (optional)',
              labelStyle: TextStyle(color: c.textSecondary),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: _saveKey,
          ),
        ),
        SettingsRow(
          icon: Icons.auto_awesome,
          title: 'Fetch metadata for all books',
          subtitle: progress.running
              ? 'Fetching ${progress.current}/${progress.total}…'
              : (progress.lastMessage ?? 'Enrich library books from the web'),
          trailing: progress.running
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: progress.running ? null : _fetchAll,
        ),
      ],
    );
  }
}

// ─── Download queue ────────────────────────────────────────────────────
class _DownloadQueueSection extends ConsumerWidget {
  const _DownloadQueueSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(downloadManagerProvider).pendingCount;
    return SettingsSection(
      title: 'Downloads',
      headerColor: AppColors.figmaAmber,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      footer:
          'Chapter downloads run in a shared queue across titles. Pause, cancel, or retry from the queue screen.',
      children: [
        SettingsRow(
          icon: Icons.download_outlined,
          title: 'Download queue',
          subtitle: pending > 0
              ? '$pending chapter${pending == 1 ? '' : 's'} pending'
              : 'Pause, cancel, or retry chapter downloads',
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () => context.pushNamed(Routes.downloadQueue),
        ),
      ],
    );
  }
}

// ─── Library updates (chapter polling) ─────────────────────────────────
class _LibraryUpdateSection extends ConsumerWidget {
  const _LibraryUpdateSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final update = ref.watch(libraryUpdateProvider);
    final lastReport = ref.watch(libraryUpdateResultProvider);
    final lastChecked = update.lastCheckedAt;
    return SettingsSection(
      title: 'Library updates',
      headerColor: AppColors.figmaAmber,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      footer:
          'Check now always fetches every library title. Skip filters below '
          'apply only to auto/background checks. Background checks can also '
          'wait for Wi‑Fi or charging. Turning on auto-download queues newly '
          'discovered chapters after each successful check.',
      children: [
        SettingsRow(
          icon: Icons.autorenew,
          title: 'Auto-check for new chapters',
          subtitle: update.enabled ? 'On' : 'Off',
          trailing: Switch(
            value: update.enabled,
            activeThumbColor: c.accent,
            onChanged: (v) =>
                ref.read(libraryUpdateProvider.notifier).setEnabled(v),
          ),
        ),
        _PrefSwitchRow(
          key: const Key('notify_new_chapters'),
          icon: Icons.notifications_outlined,
          title: 'Notify on new chapters',
          subtitle:
              'Send a system notification when a check finds new chapters',
          prefKey: 'notify_new_chapters',
          defaultValue: true,
        ),
        SettingsRow(
          icon: Icons.schedule_outlined,
          title: 'Check every',
          subtitle:
              '${update.interval.inHours} hour${update.interval.inHours == 1 ? '' : 's'}',
          trailing: PopupMenuButton<int>(
            icon: Icon(Icons.keyboard_arrow_down, color: c.textSecondary),
            tooltip: 'Interval',
            onSelected: (hours) => ref
                .read(libraryUpdateProvider.notifier)
                .setInterval(Duration(hours: hours)),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 1, child: Text('1 hour')),
              PopupMenuItem(value: 6, child: Text('6 hours')),
              PopupMenuItem(value: 12, child: Text('12 hours')),
              PopupMenuItem(value: 24, child: Text('24 hours')),
            ],
          ),
        ),
        SettingsRow(
          icon: Icons.wifi,
          title: 'Only on Wi‑Fi',
          subtitle: 'Background checks wait for an unmetered network',
          trailing: Switch(
            value: update.wifiOnly,
            activeThumbColor: c.accent,
            onChanged: update.enabled
                ? (v) =>
                      ref.read(libraryUpdateProvider.notifier).setWifiOnly(v)
                : null,
          ),
        ),
        SettingsRow(
          icon: Icons.battery_charging_full,
          title: 'Only while charging',
          subtitle: 'Background checks wait until the device is charging',
          trailing: Switch(
            value: update.chargingOnly,
            activeThumbColor: c.accent,
            onChanged: update.enabled
                ? (v) => ref
                      .read(libraryUpdateProvider.notifier)
                      .setChargingOnly(v)
                : null,
          ),
        ),
        _PrefSwitchRow(
          key: const Key('library_update_skip_completed'),
          icon: Icons.check_circle_outline,
          title: 'Skip completed titles',
          subtitle: 'Auto-check: skip manga marked completed by the source',
          prefKey: LibraryUpdatePrefs.keySkipCompleted,
          defaultValue: LibraryUpdatePrefs.defaultSkipCompleted,
        ),
        _PrefSwitchRow(
          key: const Key('library_update_skip_with_unread'),
          icon: Icons.mark_email_unread_outlined,
          title: 'Skip titles with unread chapters',
          subtitle: 'Auto-check: only titles you are fully caught up on',
          prefKey: LibraryUpdatePrefs.keySkipWithUnread,
          defaultValue: LibraryUpdatePrefs.defaultSkipWithUnread,
        ),
        _PrefSwitchRow(
          key: const Key('library_update_skip_not_started'),
          icon: Icons.play_circle_outline,
          title: 'Skip not-started titles',
          subtitle: 'Auto-check: only titles you have started reading',
          prefKey: LibraryUpdatePrefs.keySkipNotStarted,
          defaultValue: LibraryUpdatePrefs.defaultSkipNotStarted,
        ),
        _PrefSwitchRow(
          key: const Key('download_new'),
          icon: Icons.download_outlined,
          title: 'Download new chapters',
          subtitle: 'Auto-queue chapters discovered by a library check',
          prefKey: LibraryUpdatePrefs.keyDownloadNew,
          defaultValue: LibraryUpdatePrefs.defaultDownloadNew,
        ),
        SettingsRow(
          icon: Icons.refresh,
          title: 'Check now',
          subtitle: update.checking
              ? 'Checking all library titles…'
              : update.error != null
              ? 'Failed — tap to retry'
              : lastChecked != null
              ? 'Last checked ${_timeAgo(lastChecked)} · ${lastReport?.totalNew ?? update.lastNewChapterCount} new'
              : 'Fetches every library title from sources',
          trailing: update.checking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: update.checking
              ? null
              : () => ref
                    .read(libraryUpdateProvider.notifier)
                    .checkForNewChapters(applyRestrictions: false),
        ),
      ],
    );
  }
}

/// A SettingsRow whose Switch persists to a SharedPreferences boolean.
class _PrefSwitchRow extends StatefulWidget {
  const _PrefSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.prefKey,
    this.defaultValue = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String prefKey;
  final bool defaultValue;

  @override
  State<_PrefSwitchRow> createState() => _PrefSwitchRowState();
}

class _PrefSwitchRowState extends State<_PrefSwitchRow> {
  bool _value = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {
        _value = prefs.getBool(widget.prefKey) ?? widget.defaultValue;
        _loaded = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SettingsRow(
      icon: widget.icon,
      title: widget.title,
      subtitle: widget.subtitle,
      trailing: Switch(
        value: _loaded ? _value : widget.defaultValue,
        activeThumbColor: c.accent,
        onChanged: (v) async {
          setState(() {
            _value = v;
            _loaded = true;
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(widget.prefKey, v);
        },
      ),
    );
  }
}

String _timeAgo(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// Soft tinted pill used as Export / Import trailing affordance.
class _TintedActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _TintedActionChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: AppSpacing.brMd,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data ────────────────────────────────────────────────────────────────
class _DataSection extends ConsumerStatefulWidget {
  const _DataSection();

  @override
  ConsumerState<_DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends ConsumerState<_DataSection> {
  bool _importing = false;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final amber = AppColors.figmaAmber;
    final violet = AppColors.figmaVioletLight;
    return SettingsSection(
      title: 'Backup & restore',
      headerColor: amber,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      footer:
          'All your data lives on this device. Backups are plain JSON you can keep anywhere.',
      children: [
        SettingsRow(
          icon: Icons.file_upload_outlined,
          iconColor: amber,
          title: 'Export',
          subtitle: 'Save books & snippets as JSON',
          trailing: _exporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : _TintedActionChip(
                  label: 'Export',
                  icon: Icons.download_outlined,
                  color: amber,
                ),
          onTap: _exporting ? null : _export,
        ),
        SettingsRow(
          icon: Icons.file_download_outlined,
          iconColor: violet,
          title: 'Import',
          subtitle: 'Restore from a backup file',
          trailing: _importing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : _TintedActionChip(
                  label: 'Import',
                  icon: Icons.upload_outlined,
                  color: violet,
                ),
          onTap: _importing ? null : _import,
        ),
      ],
    );
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final repos = ref.watch(repositoriesProvider);
      final svc = ExportService(repos);
      final message = await svc.exportToJson();
      if (mounted) {
        StashToast.show(
          context,
          message: message,
          icon: message.startsWith('Backup') ? Icons.check : Icons.info_outline,
        );
      }
    } catch (e) {
      if (mounted) {
        StashToast.show(
          context,
          message: 'Export failed: $e',
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final repos = ref.watch(repositoriesProvider);
      final svc = ExportService(repos);
      String? jsonStr;
      try {
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (result == null || result.files.isEmpty) {
          if (mounted) setState(() => _importing = false);
          return;
        }
        jsonStr = File(result.files.single.path!).readAsStringSync();
      } catch (_) {
        if (mounted) setState(() => _importing = false);
        return;
      }
      final result = await svc.importFromJson(jsonStr);
      if (mounted) {
        ref.read(libraryProvider.notifier).loadBooks();
        StashToast.show(context, message: result.toString(), icon: Icons.check);
      }
    } catch (e) {
      if (mounted) {
        StashToast.show(
          context,
          message: 'Import failed: $e',
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }
}

// ─── Sources ─────────────────────────────────────────────────────────
class _SourcesSection extends ConsumerStatefulWidget {
  const _SourcesSection();
  @override
  ConsumerState<_SourcesSection> createState() => _SourcesSectionState();
}

class _SourcesSectionState extends ConsumerState<_SourcesSection> {
  List<Source> _sources = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final repos = ref.read(repositoriesProvider);
      final sources = await repos.stats.getSources();
      if (sources.isEmpty) {
        for (final s in SourceService.defaultSources()) {
          await repos.stats.insertSource(s);
        }
      }
      final updated = await repos.stats.getSources();
      if (!mounted) return;
      setState(() {
        _sources = updated;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_error != null) {
      return SettingsSection(
        title: 'Ebook sources',
        headerColor: AppColors.figmaCyan,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Failed to load sources: $_error',
              style: TextStyle(color: context.colors.accentMuted),
            ),
          ),
        ],
      );
    }
    return SettingsSection(
      title: 'Ebook sources',
      headerColor: AppColors.figmaCyan,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      footer:
          'Discover tab searches all enabled sources. Add sources with the correct tag for the scraper to use.',
      children: [
        ..._sources.map(
          (s) => _SourceRow(
            source: s,
            onToggle: (v) => _toggle(s.id, v),
            onDelete: () => _delete(s.id),
            onEdit: () => _edit(s),
          ),
        ),
        SettingsRow(icon: Icons.add, iconColor: AppColors.figmaCyan, title: 'Add source', onTap: _add),
      ],
    );
  }

  Future<void> _toggle(int id, bool enabled) async {
    final repos = ref.read(repositoriesProvider);
    final idx = _sources.indexWhere((s) => s.id == id);
    if (idx < 0) return;
    _sources[idx] = _sources[idx].copyWith(enabled: enabled);
    await repos.stats.updateSource(_sources[idx]);
    setState(() {});
  }

  Future<void> _delete(int id) async {
    final repos = ref.read(repositoriesProvider);
    await repos.stats.deleteSource(id);
    _sources.removeWhere((s) => s.id == id);
    setState(() {});
  }

  Future<void> _add() async {
    final result = await _sourceDialog(context, null);
    if (result == null) return;
    final repos = ref.read(repositoriesProvider);
    final id = await repos.stats.insertSource(result);
    _sources.add(result.copyWith(id: id));
    setState(() {});
  }

  Future<void> _edit(Source source) async {
    final result = await _sourceDialog(context, source);
    if (result == null) return;
    final repos = ref.read(repositoriesProvider);
    await repos.stats.updateSource(result);
    final idx = _sources.indexWhere((s) => s.id == result.id);
    if (idx >= 0) _sources[idx] = result;
    setState(() {});
  }
}

Future<Source?> _sourceDialog(BuildContext context, Source? existing) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final urlCtrl = TextEditingController(text: existing?.baseUrl ?? '');
  final langCtrl = TextEditingController(text: existing?.language ?? '');
  String tag = existing?.tag ?? 'libgen';
  final c = context.colors;

  return showDialog<Source>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.border, width: 0.5),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null ? 'Add source' : 'Edit source',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tag',
                style: TextStyle(color: c.textTertiary, fontSize: 12),
              ),
              const SizedBox(height: 4),
              DropdownButton<String>(
                value: tag,
                isExpanded: true,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(
                    value: 'libgen',
                    child: Text('Library Genesis'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setDlgState(() => tag = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(hintText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  hintText: 'Base URL (e.g. https://libgen.gs/index.php)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: langCtrl,
                decoration: const InputDecoration(
                  hintText: 'Language filter (e.g. English, French)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: c.textTertiary)),
          ),
          TextButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty || urlCtrl.text.trim().isEmpty) {
                return;
              }
              Navigator.of(ctx).pop(
                Source(
                  id: existing?.id ?? 0,
                  name: nameCtrl.text.trim(),
                  tag: tag,
                  baseUrl: urlCtrl.text.trim(),
                  enabled: existing?.enabled ?? true,
                  language: langCtrl.text.trim().isEmpty
                      ? null
                      : langCtrl.text.trim(),
                ),
              );
            },
            child: Text('Save', style: TextStyle(color: c.accent)),
          ),
        ],
      ),
    ),
  );
}

class _SourceRow extends StatelessWidget {
  final Source source;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  const _SourceRow({
    required this.source,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const cyan = AppColors.figmaCyan;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cyan.withValues(alpha: 0.13),
              borderRadius: AppSpacing.brMd,
            ),
            child: const Icon(Icons.language, size: 18, color: cyan),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onEdit,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    source.baseUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textTertiary, fontSize: 11),
                  ),
                  if (source.tag.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cyan.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        source.tag.toUpperCase(),
                        style: const TextStyle(
                          color: cyan,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Switch(value: source.enabled, onChanged: onToggle),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: c.textTertiary),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ─── Stats ────────────────────────────────────────────────────────────
class _StatsSection extends ConsumerStatefulWidget {
  const _StatsSection();

  @override
  ConsumerState<_StatsSection> createState() => _StatsSectionState();
}

class _StatsSectionState extends ConsumerState<_StatsSection> {
  Map<String, int> _genres = {};
  Map<String, int> _extensions = {};
  int _completed = 0;
  List<int> _minutesPerDay = List.filled(7, 0);
  int _streak = 0;
  bool _loading = true;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Riverpod forbids ref.watch/read from initState before the element
    // finishes mounting — load once after inherited-widget deps settle.
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void didUpdateWidget(_StatsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  Future<void> _load() async {
    final repos = ref.read(repositoriesProvider);
    final statsSvc = ref.read(statsServiceProvider);
    final results = await Future.wait([
      repos.books.getGenreCounts(),
      repos.books.getExtensionCounts(),
      repos.books.getCompletedBooksCount(),
      statsSvc.getWeeklyStreak(),
    ]);
    if (!mounted) return;
    setState(() {
      _genres = results[0] as Map<String, int>;
      _extensions = results[1] as Map<String, int>;
      _completed = results[2] as int;
      final streak =
          results[3] as ({List<int> minutesPerDay, int currentStreak});
      _minutesPerDay = streak.minutesPerDay;
      _streak = streak.currentStreak;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_loading) return const SizedBox.shrink();
    return SettingsSection(
      title: 'Stats',
      headerColor: AppColors.figmaAmber,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        ReadingStreakCard(
          minutesPerDay: _minutesPerDay,
          currentStreak: _streak,
          onTap: _showWeeklyDetail,
        ),
        _row(c, Icons.menu_book, 'Books completed', _completed),
        if (_genres.isNotEmpty)
          ..._genres.entries.map(
            (e) => _row(c, Icons.category_outlined, e.key, e.value),
          )
        else
          _row(
            c,
            Icons.category_outlined,
            'Genre metadata not available',
            null,
          ),
        if (_extensions.isNotEmpty)
          ..._extensions.entries.map(
            (e) => _row(c, Icons.insert_drive_file_outlined, e.key, e.value),
          )
        else
          _row(c, Icons.insert_drive_file_outlined, 'Extensions', 0),
      ],
    );
  }

  void _showWeeklyDetail() {
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final buf = StringBuffer();
    int total = 0;
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final mins = _minutesPerDay[6 - i];
      total += mins;
      final label = day.weekday - 1 == now.weekday - 1
          ? 'Today'
          : dayNames[day.weekday - 1];
      buf.writeln('$label · ${mins}min');
    }
    showDialog(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        return AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: c.border, width: 0.5),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_streak day streak',
                style: TextStyle(
                  color: c.accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$total min this week',
                style: TextStyle(color: c.textTertiary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                buf.toString().trim(),
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Streak resets when a day has 0 min read.',
                style: TextStyle(color: c.textTertiary, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'OK',
                style: TextStyle(color: c.accent, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(KomaColors c, IconData icon, String label, int? count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: c.textPrimary, fontSize: 15),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            count == null ? '—' : '$count',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Plugins ───────────────────────────────────────────────────────────
class _PluginsSection extends ConsumerWidget {
  const _PluginsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final updateCount = ref.watch(extensionUpdateCountProvider);
    return SettingsSection(
      title: 'Plugins',
      headerColor: AppColors.figmaCyan,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      footer:
          'Plugins extend Koma with new sources via Keiyoushi/Mihon extension APKs. Add a repo, fetch its index, and install the ones you want.',
      children: [
        SettingsRow(
          icon: Icons.extension_outlined,
          iconColor: AppColors.figmaCyan,
          title: 'Manage plugins',
          subtitle: updateCount > 0
              ? 'Browse, install, and remove extensions · $updateCount update${updateCount == 1 ? '' : 's'} available'
              : 'Browse, install, and remove extensions',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (updateCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$updateCount',
                    style: TextStyle(
                      color: c.bg,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
          onTap: () {
            context.pushNamed(Routes.extensions);
          },
        ),
        SettingsRow(
          icon: Icons.code,
          iconColor: AppColors.figmaCyan,
          title: 'Plugin SDK',
          subtitle: 'Documentation for authors',
          trailing: const Icon(Icons.chevron_right, size: 18),
        ),
        _PrefSwitchRow(
          key: const Key('notify_extension_updates'),
          icon: Icons.notifications_outlined,
          title: 'Notify on plugin updates',
          subtitle:
              'Send a system notification when updates are found on launch',
          prefKey: 'notify_extension_updates',
          defaultValue: true,
        ),
        _PrefSwitchRow(
          key: const Key('extension_auto_update_enabled'),
          icon: Icons.system_update_alt_outlined,
          title: 'Auto-install plugin updates',
          subtitle:
              'Download and reload newer extension APKs on launch when available',
          prefKey: 'extension_auto_update_enabled',
          defaultValue: false,
        ),
        SettingsRow(
          icon: Icons.security_outlined,
          iconColor: const Color(0xFFEF4444),
          title: 'Revoke all trusted extensions',
          subtitle:
              'Clear user-trusted sideloads. Repo-signed packages stay trusted.',
          destructive: true,
          onTap: () => _revokeTrustedExtensions(context, ref),
        ),
      ],
    );
  }

  Future<void> _revokeTrustedExtensions(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(
          'Revoke trusted extensions?',
          style: TextStyle(color: c.textPrimary),
        ),
        content: Text(
          'This clears extensions you explicitly trusted. Packages signed by '
          'a known repository remain usable.',
          style: TextStyle(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Revoke', style: TextStyle(color: c.accent)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final mgr = ExtensionManager(
      ref.read(repositoriesProvider),
      KeiyoushiService(),
    );
    final changed = await mgr.revokeAllTrusted();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          changed > 0
              ? 'Revoked trust · $changed extension${changed == 1 ? '' : 's'} rechecked'
              : 'Revoked all user-trusted extensions',
        ),
      ),
    );
  }
}

// ─── About ──────────────────────────────────────────────────────────────
class _AboutSection extends StatelessWidget {
  const _AboutSection();

  static const _muted = Color(0xFF8888A0);
  static const _pad = EdgeInsets.symmetric(horizontal: 16);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const features = <(IconData, String, Color)>[
      (Icons.menu_book_outlined, 'EPUB reading', AppColors.figmaViolet),
      (Icons.extension_outlined, 'Manga plugins', AppColors.figmaAmber),
      (Icons.bolt, 'Bionic reading', Color(0xFFEF4444)),
      (Icons.shield_outlined, 'Local-first / offline', AppColors.figmaGreen),
    ];
    return Column(
      children: [
        Padding(
          padding: _pad,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: AppSpacing.brLg,
              border: Border.all(color: c.border, width: 0.5),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'app_icons/hon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stackTrace) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.figmaViolet, AppColors.figmaCyan],
                        ),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        size: 34,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Koma',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 2.37.16 · build 2.37.16+283',
                  style: TextStyle(color: c.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Text(
                  'A reader and a thinking tool. Local-first. No accounts. No tracking.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: _pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Text(
                  'FEATURES',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.6,
                children: [
                  for (final f in features)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: AppSpacing.brMd,
                        border: Border.all(color: c.border, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: f.$3.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(f.$1, size: 14, color: f.$3),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              f.$2,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SettingsSection(
          title: 'About',
          headerColor: _muted,
          padding: _pad,
          children: [
            SettingsRow(
              icon: Icons.info_outline,
              iconColor: _muted,
              title: 'Koma',
              subtitle: 'Version 2.37.16 · build 2.37.16+283',
            ),
            SettingsRow(
              icon: Icons.favorite_outline,
              iconColor: const Color(0xFFEF4444),
              title: 'A reader and a thinking tool',
              subtitle: 'Local-first. No accounts. No tracking.',
            ),
            SettingsRow(
              icon: Icons.book_outlined,
              iconColor: _muted,
              title: 'Open source licenses',
              trailing: const Icon(Icons.chevron_right, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Padding(
          padding: _pad,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: AppSpacing.brLg,
              border: Border.all(color: c.border, width: 0.5),
            ),
            child: Column(
              children: [
                Text(
                  'Made for readers who take their collections seriously.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  'Inspired by Mihon & Mangayomi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF3A3A55)
                        : const Color(0xFFC0C0D8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

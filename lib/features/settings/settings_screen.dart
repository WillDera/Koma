import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/export_service.dart';
import '../../core/services/database_service.dart';
import '../library/library_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens/app_colors.dart';
import '../../theme/tokens/app_motion.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/dialog_sheet.dart';
import '../../widgets/divider_hairline.dart';
import '../../widgets/one_hand_spacer.dart';
import '../../widgets/segmented_control.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/text_field.dart';
import '../../widgets/toast.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ScrollController _scrollCtrl = ScrollController();
  double _scrollProgress = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    final p = max <= 0 ? 0.0 : (_scrollCtrl.offset / max).clamp(0.0, 1.0);
    if ((p - _scrollProgress).abs() > 0.01) {
      setState(() => _scrollProgress = p);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  bool get _oneHand => context.watch<ThemeProvider>().oneHandMode;

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    return SafeArea(
      bottom: false,
      child: ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          const OneHandSpacer(),
          _Heading(
            title: 'Settings',
            oneHand: _oneHand,
            shrinkProgress: _oneHand ? _scrollProgress : 0.0,
            subtitle: 'Version 2.1.0',
          ),
          const SizedBox(height: 4),
          _AppearanceSection(themeProv: themeProv),
          const SizedBox(height: 24),
          const _TypographySection(),
          const SizedBox(height: 24),
          const _DataSection(),
          const SizedBox(height: 24),
          const _PluginsSection(),
          const SizedBox(height: 24),
          const _AboutSection(),
        ],
      ),
    );
  }
}

/// Page heading that animates in one-hand mode.
class _Heading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool oneHand;
  final double shrinkProgress;

  const _Heading({
    required this.title,
    this.subtitle,
    required this.oneHand,
    required this.shrinkProgress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = shrinkProgress.clamp(0.0, 1.0);
    final fontSize = (oneHand ? 64.0 : 32.0) * (1.0 - 0.5 * p);
    final opacity = (1.0 - p).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          if (subtitle != null)
            Opacity(
              opacity: opacity,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle!,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Appearance ──────────────────────────────────────────────────────────
class _AppearanceSection extends StatelessWidget {
  final ThemeProvider themeProv;
  const _AppearanceSection({required this.themeProv});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SettingsSection(
      title: 'Appearance',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              SegmentedControl<ThemeMode>(
                segments: const {
                  ThemeMode.light: 'Light',
                  ThemeMode.dark: 'Dark',
                  ThemeMode.system: 'Auto',
                },
                value: themeProv.themeMode,
                onChanged: themeProv.setThemeMode,
              ),
              const SizedBox(height: 12),
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sepia mode'),
                  subtitle: Text(
                    'Warm paper-like background',
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
                  value: themeProv.sepiaMode,
                  onChanged: themeProv.setSepiaMode,
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: HairlineDivider(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Accent',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                'Used for highlights, selections, and the active state.',
                style:
                    TextStyle(color: c.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final entry in const [
                    (AccentPreset.indigo, AppColors.accentIndigo,
                        AppColors.accentIndigoDark, 'Indigo'),
                    (AccentPreset.amber, AppColors.accentAmber,
                        AppColors.accentAmberDark, 'Amber'),
                    (AccentPreset.forest, AppColors.accentForest,
                        AppColors.accentForestDark, 'Forest'),
                  ]) ...[
                    _AccentSwatch(
                      light: entry.$2,
                      dark: entry.$3,
                      label: entry.$4,
                      selected: themeProv.customAccentHex == null &&
                          themeProv.accent == entry.$1,
                      onTap: () => themeProv.setAccent(entry.$1),
                    ),
                    const SizedBox(width: 10),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Custom hex',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              _CustomAccentInput(
                current: themeProv.customAccentHex,
                onSubmit: themeProv.setCustomAccentHex,
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: HairlineDivider(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Handedness',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                'Floating buttons on your preferred side for one-thumb reach.',
                style:
                    TextStyle(color: c.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 10),
              SegmentedControl<HandMode>(
                segments: const {
                  HandMode.right: 'Right',
                  HandMode.left: 'Left',
                },
                value: themeProv.handMode,
                onChanged: themeProv.setHandMode,
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: HairlineDivider(),
        ),
        const _OneHandToggle(),
      ],
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: AppSpacing.brMd,
              border: Border.all(
                color: selected ? c.textPrimary : c.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: selected
                ? Icon(Icons.check,
                    size: 20,
                    color: color.computeLuminance() > 0.5
                        ? const Color(0xFF1A1815)
                        : Colors.white)
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
                color: c.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _CustomAccentInput extends StatefulWidget {
  final String? current;
  final ValueChanged<String?> onSubmit;
  const _CustomAccentInput({required this.current, required this.onSubmit});

  @override
  State<_CustomAccentInput> createState() => _CustomAccentInputState();
}

class _CustomAccentInputState extends State<_CustomAccentInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.current ?? '');
  }

  @override
  void didUpdateWidget(covariant _CustomAccentInput old) {
    super.didUpdateWidget(old);
    final next = widget.current ?? '';
    if (next != _ctrl.text) {
      _ctrl.text = next;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _apply() {
    final v = _ctrl.text.trim();
    if (v.isEmpty) {
      widget.onSubmit(null);
    } else {
      widget.onSubmit(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final parsed = _parseColor(_ctrl.text);
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: parsed ?? c.surfaceMuted,
            borderRadius: AppSpacing.brSm,
            border: Border.all(color: c.border, width: 0.5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StashTextField(
            controller: _ctrl,
            hint: '#RRGGBB',
            leadingIcon: Icons.format_color_fill,
            showClearButton: true,
            onSubmitted: (_) => _apply(),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedPress(
          onTap: _apply,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: parsed == null ? c.surfaceMuted : c.accent,
              borderRadius: AppSpacing.brPill,
            ),
            child: Text(
              'Apply',
              style: TextStyle(
                color: parsed == null
                    ? c.textTertiary
                    : c.onAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color? _parseColor(String hex) {
    var v = hex.trim();
    if (v.isEmpty) return null;
    if (v.startsWith('#')) v = v.substring(1);
    if (v.length == 6) v = 'FF$v';
    if (v.length != 8) return null;
    final i = int.tryParse(v, radix: 16);
    if (i == null) return null;
    return Color(i);
  }
}

class _OneHandToggle extends StatelessWidget {
  const _OneHandToggle();

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'One-hand mode',
            style: TextStyle(
                color: c.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            'Pushes content toward the bottom half of the screen for easier thumb reach. Headers grow larger and shrink as you scroll.',
            style:
                TextStyle(color: c.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable one-hand layout'),
              value: themeProv.oneHandMode,
              onChanged: themeProv.setOneHandMode,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Typography ──────────────────────────────────────────────────────────
class _TypographySection extends StatelessWidget {
  const _TypographySection();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ThemeProvider>();
    return SettingsSection(
      title: 'Typography',
      children: [
        SettingsRow(
          icon: Icons.text_fields,
          title: 'Reading font',
          subtitle: p.readingFont.label,
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () => _showFontPicker(context, p),
        ),
        SettingsRow(
          icon: Icons.format_size,
          title: 'Font size',
          subtitle: '${p.fontSize.toInt()}px',
          trailing: SizedBox(
            width: 110,
            child: Slider(
              value: p.fontSize,
              min: 13,
              max: 26,
              divisions: 13,
              onChanged: p.setFontSize,
            ),
          ),
        ),
        SettingsRow(
          icon: Icons.format_line_spacing,
          title: 'Line height',
          subtitle: p.lineHeight.toStringAsFixed(2),
          trailing: SizedBox(
            width: 110,
            child: Slider(
              value: p.lineHeight,
              min: 1.2,
              max: 2.2,
              divisions: 10,
              onChanged: p.setLineHeight,
            ),
          ),
        ),
        const HairlineDivider(indent: 16, endIndent: 16),
        SettingsRow(
          icon: Icons.bolt,
          title: 'Bionic reading',
          subtitle: 'Bold the first 40% of every word',
          trailing: Switch(
            value: p.bionicReading,
            onChanged: p.setBionicReading,
          ),
        ),
        const HairlineDivider(indent: 16, endIndent: 16),
        SettingsRow(
          icon: Icons.format_align_left,
          title: 'Text alignment',
          subtitle: _alignName(p.textAlign),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () => _showAlignPicker(context, p),
        ),
        SettingsRow(
          icon: Icons.width_normal,
          title: 'Page width',
          subtitle: '${p.pageWidth.toInt()}px',
          trailing: SizedBox(
            width: 110,
            child: Slider(
              value: p.pageWidth,
              min: 520,
              max: 760,
              divisions: 12,
              onChanged: p.setPageWidth,
            ),
          ),
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

  void _showFontPicker(BuildContext context, ThemeProvider p) {
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
                p.setReadingFont(f);
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
                          if (f.googleFontFamily != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Aa — long-form sample text',
                                style: TextStyle(
                                  color: context.colors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (p.readingFont == f)
                      Icon(Icons.check,
                          color: context.colors.accent, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAlignPicker(BuildContext context, ThemeProvider p) {
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
                p.setTextAlign(o.$1);
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: p.textAlign == o.$1
                      ? c.accentMuted
                      : c.surface,
                  borderRadius: AppSpacing.brLg,
                  border: Border.all(
                    color: p.textAlign == o.$1
                        ? c.accent
                        : c.border,
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
                      child: Icon(o.$3,
                          size: 20, color: c.textPrimary),
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
                      Icon(Icons.check,
                          color: c.accent, size: 20),
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

// ─── Data ────────────────────────────────────────────────────────────────
class _DataSection extends StatefulWidget {
  const _DataSection();

  @override
  State<_DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends State<_DataSection> {
  bool _importing = false;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Data',
      footer:
          'All your data lives on this device. Backups are plain JSON you can keep anywhere.',
      children: [
        SettingsRow(
          icon: Icons.file_upload_outlined,
          title: 'Export',
          subtitle: 'Save books & snippets as JSON',
          trailing: _exporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _exporting ? null : _export,
        ),
        SettingsRow(
          icon: Icons.file_download_outlined,
          title: 'Import',
          subtitle: 'Restore from a backup file',
          trailing: _importing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _importing ? null : _import,
        ),
      ],
    );
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final db = context.read<DatabaseService>();
      final svc = ExportService(db);
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
            context, message: 'Export failed: $e', icon: Icons.error_outline);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final db = context.read<DatabaseService>();
      final svc = ExportService(db);
      final result = await svc.importFromJson();
      if (mounted) {
        context.read<LibraryProvider>().loadBooks();
        StashToast.show(context, message: result, icon: Icons.check);
      }
    } catch (e) {
      if (mounted) {
        StashToast.show(
            context, message: 'Import failed: $e', icon: Icons.error_outline);
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }
}

// ─── Plugins (placeholder) ──────────────────────────────────────────────
class _PluginsSection extends StatelessWidget {
  const _PluginsSection();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SettingsSection(
      title: 'Plugins',
      footer:
          'Plugins extend StashReader with new sources, parsers, and exporters. The plugin system is being prepared — a small set of official plugins will land in a future release.',
      children: [
        SettingsRow(
          icon: Icons.extension_outlined,
          title: 'Manage plugins',
          subtitle: 'Browse and enable extensions',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: c.accentMuted,
              borderRadius: AppSpacing.brPill,
            ),
            child: Text(
              'Coming soon',
              style: TextStyle(
                color: c.accent,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
        SettingsRow(
          icon: Icons.code,
          title: 'Plugin SDK',
          subtitle: 'Documentation for authors',
          trailing: const Icon(Icons.chevron_right, size: 18),
        ),
      ],
    );
  }
}

// ─── About ──────────────────────────────────────────────────────────────
class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'About',
      children: [
        SettingsRow(
          icon: Icons.info_outline,
          title: 'StashReader',
          subtitle: 'Version 2.1.0 · build 2.1.0+6',
        ),
        SettingsRow(
          icon: Icons.favorite_outline,
          title: 'A reader and a thinking tool',
          subtitle: 'Local-first. No accounts. No tracking.',
        ),
        SettingsRow(
          icon: Icons.book_outlined,
          title: 'Open source licenses',
          trailing: const Icon(Icons.chevron_right, size: 18),
        ),
      ],
    );
  }
}

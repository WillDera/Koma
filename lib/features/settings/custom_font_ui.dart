import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/custom_font.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../theme/theme_state.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../theme/tokens/app_type.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/dialog_sheet.dart';
import '../../widgets/toast.dart';

/// Shared UI for importing and picking custom fonts (UI + reading).
class CustomFontUi {
  const CustomFontUi._();

  static Future<void> pickAndImport(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf'],
      );
      if (result == null || result.files.isEmpty) return;

      final paths = result.files
          .map((f) => f.path)
          .whereType<String>()
          .where((p) => p.isNotEmpty)
          .toList();
      if (paths.isEmpty) return;

      final files = paths.map(File.new).toList();
      final font = await ref.read(themeProvider.notifier).importCustomFonts(files);
      if (!context.mounted) return;
      if (font != null) {
        StashToast.show(
          context,
          message: 'Added ${font.displayName}',
          icon: Icons.check,
        );
      } else {
        StashToast.show(
          context,
          message: 'Could not import font',
          icon: Icons.error_outline,
        );
      }
    } catch (e) {
      if (context.mounted) {
        StashToast.show(
          context,
          message: 'Import failed: $e',
          icon: Icons.error_outline,
        );
      }
    }
  }

  static Future<void> confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CustomFont font,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        return AlertDialog(
          backgroundColor: c.surface,
          title: Text('Remove font?', style: TextStyle(color: c.textPrimary)),
          content: Text(
            '${font.displayName} will be removed from your library.',
            style: TextStyle(color: c.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Remove', style: TextStyle(color: c.accent)),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await ref.read(themeProvider.notifier).deleteCustomFont(font.id);
    if (context.mounted) {
      StashToast.show(context, message: 'Font removed', icon: Icons.check);
    }
  }

  static void showAppFontPicker(BuildContext context, WidgetRef ref) {
    final p = ref.read(themeProvider);
  StashSheet.show<void>(
      context,
      title: 'App font',
      subtitle: 'UI typography across Koma. Import TTF/OTF files below.',
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      child: _AppFontPickerBody(
        initialUiFontId: p.uiFontId,
        customFonts: p.customFonts,
      ),
    );
  }

  static void showReadingFontPicker(BuildContext context, WidgetRef ref) {
    final p = ref.read(themeProvider);
    StashSheet.show<void>(
      context,
      title: 'Reading font',
      subtitle: 'Choose a face for long-form reading.',
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      child: _ReadingFontPickerBody(
        initialReadingFont: p.readingFont,
        initialReadingFontId: p.readingFontId,
        customFonts: p.customFonts,
      ),
    );
  }

  static void showManageFonts(BuildContext context, WidgetRef ref) {
    final p = ref.read(themeProvider);
    StashSheet.show<void>(
      context,
      title: 'Imported fonts',
      subtitle:
          'TTF and OTF files stored on device. OEM system fonts inside APKs cannot be extracted — import a copy here.',
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      child: _ManageFontsBody(customFonts: p.customFonts),
    );
  }
}

class _AppFontPickerBody extends ConsumerWidget {
  const _AppFontPickerBody({
    required this.initialUiFontId,
    required this.customFonts,
  });

  final String? initialUiFontId;
  final List<CustomFont> customFonts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(themeProvider);
    final tn = ref.read(themeProvider.notifier);
    final c = context.colors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _fontTile(
          context: context,
          label: 'Inter',
          sampleFamily: AppType.uiFont,
          selected: p.uiFontId == null,
          onTap: () {
            tn.setUiFontId(null);
            Navigator.pop(context);
          },
        ),
        for (final font in p.customFonts)
          _fontTile(
            context: context,
            label: font.displayName,
            sampleFamily: font.registeredFamily,
            selected: p.uiFontId == font.id,
            onTap: () {
              tn.setUiFontId(font.id);
              Navigator.pop(context);
            },
            onDelete: () => CustomFontUi.confirmDelete(context, ref, font),
          ),
        const SizedBox(height: 8),
        _actionRow(
          context,
          icon: Icons.add,
          label: 'Add font file…',
          onTap: () => CustomFontUi.pickAndImport(context, ref),
        ),
        _actionRow(
          context,
          icon: Icons.folder_open_outlined,
          label: 'Manage imported fonts',
          onTap: () {
            Navigator.pop(context);
            CustomFontUi.showManageFonts(context, ref);
          },
        ),
      ],
    );
  }

  Widget _fontTile({
    required BuildContext context,
    required String label,
    required String? sampleFamily,
    required bool selected,
    required VoidCallback onTap,
    VoidCallback? onDelete,
  }) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedPress(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? c.accentMuted : c.surface,
            borderRadius: AppSpacing.brLg,
            border: Border.all(
              color: selected ? c.accent : c.border,
              width: selected ? 1.2 : 0.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Aa — UI sample text',
                        style: AppType.fontStyle(
                          fontFamily: sampleFamily,
                          fontSize: 15,
                          lineHeight: 1.4,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: c.textTertiary, size: 20),
                  onPressed: onDelete,
                ),
              if (selected)
                Icon(Icons.check, color: c.accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedPress(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: AppSpacing.brLg,
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: c.accent),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadingFontPickerBody extends ConsumerWidget {
  const _ReadingFontPickerBody({
    required this.initialReadingFont,
    required this.initialReadingFontId,
    required this.customFonts,
  });

  final ReadingFont initialReadingFont;
  final String? initialReadingFontId;
  final List<CustomFont> customFonts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(themeProvider);
    final tn = ref.read(themeProvider.notifier);
    final c = context.colors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        for (final f in ReadingFont.values)
          _readingTile(
            context: context,
            label: f.label,
            sampleFamily: f.googleFontFamily,
            selected: p.readingFontId == null && p.readingFont == f,
            onTap: () {
              tn.setReadingFont(f);
              Navigator.pop(context);
            },
          ),
        if (p.customFonts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              'Imported',
              style: TextStyle(
                color: c.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final font in p.customFonts)
            _readingTile(
              context: context,
              label: font.displayName,
              sampleFamily: font.registeredFamily,
              selected: p.readingFontId == font.id,
              onTap: () {
                tn.setReadingFontId(font.id);
                Navigator.pop(context);
              },
            ),
        ],
        const SizedBox(height: 8),
        _AddFontButton(onTap: () => CustomFontUi.pickAndImport(context, ref)),
      ],
    );
  }

  Widget _readingTile({
    required BuildContext context,
    required String label,
    required String? sampleFamily,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedPress(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? c.accentMuted : c.surface,
            borderRadius: AppSpacing.brLg,
            border: Border.all(
              color: selected ? c.accent : c.border,
              width: selected ? 1.2 : 0.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Aa — long-form sample text',
                        style: AppType.fontStyle(
                          fontFamily: sampleFamily,
                          fontSize: 15,
                          lineHeight: 1.4,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check, color: c.accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddFontButton extends StatelessWidget {
  const _AddFontButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: AppSpacing.brLg,
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.add, size: 20, color: c.accent),
            const SizedBox(width: 12),
            Text(
              'Add font file…',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageFontsBody extends ConsumerWidget {
  const _ManageFontsBody({required this.customFonts});

  final List<CustomFont> customFonts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(themeProvider);
    final c = context.colors;

    if (p.customFonts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          children: [
            Text(
              'No imported fonts yet.',
              style: TextStyle(color: c.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            _AddFontButton(
              onTap: () => CustomFontUi.pickAndImport(context, ref),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        for (final font in p.customFonts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: AppSpacing.brLg,
                border: Border.all(color: c.border, width: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          font.displayName,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${font.faces.length} file(s)',
                          style: TextStyle(
                            color: c.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: c.textTertiary),
                    onPressed: () =>
                        CustomFontUi.confirmDelete(context, ref, font),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        _AddFontButton(onTap: () => CustomFontUi.pickAndImport(context, ref)),
      ],
    );
  }
}

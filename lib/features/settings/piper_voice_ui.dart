import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/services/piper_voice_service.dart';
import '../../theme/app_theme.dart';

/// Import and manage user-provided Piper voice files.
class PiperVoiceUi {
  PiperVoiceUi._();

  static Future<bool> importVoice(BuildContext context) async {
    if (!PiperPlatform.isSupported) {
      _snack(context, 'Piper voices are only supported on Android.');
      return false;
    }
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['onnx', 'json'],
    );
    if (result == null || result.files.isEmpty) return false;

    final files = result.paths
        .whereType<String>()
        .map((p) => File(p))
        .where((f) => f.existsSync())
        .toList();
    if (files.isEmpty) return false;

    final voice = await PiperVoiceService.instance.importFiles(files);
    if (!context.mounted) return voice != null;
    if (voice == null) {
      _snack(
        context,
        'Could not import voice. Need a .onnx file and matching .onnx.json.',
      );
      return false;
    }
    _snack(context, 'Imported "${voice.displayName}"');
    return true;
  }

  static Future<void> deleteVoice(BuildContext context, String id) async {
    await PiperVoiceService.instance.deleteVoice(id);
    if (context.mounted) {
      _snack(context, 'Voice removed');
    }
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// Piper voice import / manage block for TTS settings.
class PiperVoiceSettingsSection extends StatelessWidget {
  const PiperVoiceSettingsSection({
    super.key,
    required this.onCatalogChanged,
  });

  final VoidCallback onCatalogChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (!PiperPlatform.isSupported) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Piper on-device TTS is only available on Android.',
          style: TextStyle(color: c.textSecondary, fontSize: 12),
        ),
      );
    }

    return FutureBuilder(
      future: PiperVoiceService.instance.listVoices(),
      builder: (context, snapshot) {
        final voices = snapshot.data ?? [];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Piper voices',
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Import .onnx and .onnx.json files from HuggingFace '
                '(rhasspy/piper-voices). Koma does not bundle voices.',
                style: TextStyle(color: c.textTertiary, fontSize: 11),
              ),
              const SizedBox(height: 8),
              if (voices.isEmpty)
                Text(
                  'No voices imported yet.',
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
              for (final v in voices)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    v.displayName,
                    style: TextStyle(color: c.textPrimary, fontSize: 14),
                  ),
                  subtitle: v.locale != null
                      ? Text(
                          v.locale!,
                          style: TextStyle(color: c.textSecondary, fontSize: 11),
                        )
                      : null,
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline, color: c.textSecondary),
                    onPressed: () async {
                      await PiperVoiceUi.deleteVoice(context, v.id);
                      onCatalogChanged();
                    },
                  ),
                ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await PiperVoiceUi.importVoice(context);
                  if (ok) onCatalogChanged();
                },
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Import Piper voice'),
              ),
              const SizedBox(height: 4),
              Text(
                'Piper engine is GPL-3.0 (see Open source licenses).',
                style: TextStyle(color: c.textTertiary, fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }
}

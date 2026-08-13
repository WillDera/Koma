import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

/// Open-source license notices (Koma GPL + Piper and other deps).
class OpenSourceLicensesSheet extends StatelessWidget {
  const OpenSourceLicensesSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const OpenSourceLicensesSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Material(
          color: c.bgElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Text(
                      'Open source licenses',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: c.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<String>(
                  future: rootBundle.loadString(
                    'assets/legal/piper_gpl_notice.txt',
                  ),
                  builder: (context, snapshot) {
                    final piperText = snapshot.data ?? '';
                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      children: [
                        _heading(c, 'Koma'),
                        const SizedBox(height: 4),
                        Text(
                          'Koma is free and open-source software licensed under '
                          'the GNU General Public License version 3 or later '
                          '(GPL-3.0-or-later).',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _heading(c, 'Piper TTS (libpiper)'),
                        const SizedBox(height: 4),
                        Text(
                          'On-device neural TTS engine from OHF-Voice/piper1-gpl. '
                          'Licensed under GNU GPL v3. Voice models are '
                          'user-provided and are not distributed with Koma.',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'https://github.com/OHF-Voice/piper1-gpl',
                          style: TextStyle(color: c.accent, fontSize: 12),
                        ),
                        if (piperText.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            piperText,
                            style: TextStyle(
                              color: c.textTertiary,
                              fontSize: 10,
                              height: 1.35,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        _heading(c, 'ONNX Runtime'),
                        const SizedBox(height: 4),
                        Text(
                          'Microsoft ONNX Runtime (onnxruntime-android 1.22.0). '
                          'Licensed under MIT.',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _heading(c, 'eSpeak NG'),
                        const SizedBox(height: 4),
                        Text(
                          'Phonemizer library and espeak-ng-data assets. '
                          'Licensed under GPL-3.0-or-later (upstream).',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _heading(c, 'Flutter and other packages'),
                        const SizedBox(height: 4),
                        Text(
                          'Flutter, Riverpod, Isar, just_audio, flutter_tts, '
                          'Mihon extension bridge, and other packages listed in '
                          'pubspec.yaml — each under its own license.',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _heading(c, 'Piper voice models'),
                        const SizedBox(height: 4),
                        Text(
                          'Voice models (.onnx / .onnx.json) are imported by the '
                          'user. They are third-party works and are not covered '
                          'by Koma’s GPL license grant.',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _heading(KomaColors c, String title) {
    return Text(
      title,
      style: TextStyle(
        color: c.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

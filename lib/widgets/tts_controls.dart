import 'dart:ui';
import 'package:flutter/material.dart';
import '../features/reader/tts_provider.dart';
import '../theme/app_theme.dart';
import 'icon_button_round.dart';

class TtsControls extends StatelessWidget {
  final TtsProvider provider;

  const TtsControls({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: c.bg.withValues(alpha: 0.82),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButtonRound(
                    icon: Icons.close,
                    size: 36,
                    variant: IconButtonVariant.tonal,
                    onPressed: () {
                      provider.stop();
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButtonRound(
                    icon: Icons.skip_previous,
                    size: 36,
                    variant: IconButtonVariant.tonal,
                    onPressed: provider.currentIndex > 0
                        ? () => provider.previousSentence()
                        : null,
                  ),
                  const SizedBox(width: 4),
                  IconButtonRound(
                    icon: provider.isPaused
                        ? Icons.play_arrow
                        : Icons.pause,
                    size: 36,
                    variant: IconButtonVariant.filled,
                    iconColor: c.onAccent,
                    backgroundColor: c.accent,
                    onPressed: () {
                      if (provider.isPaused) {
                        provider.play();
                      } else {
                        provider.pause();
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButtonRound(
                    icon: Icons.skip_next,
                    size: 36,
                    variant: IconButtonVariant.tonal,
                    onPressed: provider.currentIndex < provider.totalSentences - 1
                        ? () => provider.nextSentence()
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${provider.currentIndex + 1} / ${provider.totalSentences}',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButtonRound(
                    icon: Icons.tune,
                    size: 36,
                    variant: IconButtonVariant.tonal,
                    onPressed: () => _showSettings(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TtsSettingsSheet(provider: provider),
    );
  }
}

class _TtsSettingsSheet extends StatefulWidget {
  final TtsProvider provider;
  const _TtsSettingsSheet({required this.provider});

  @override
  State<_TtsSettingsSheet> createState() => _TtsSettingsSheetState();
}

class _TtsSettingsSheetState extends State<_TtsSettingsSheet> {
  late double _rate;
  late double _pitch;

  @override
  void initState() {
    super.initState();
    _rate = widget.provider.rate;
    _pitch = widget.provider.pitch;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: c.textTertiary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Speech Settings',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButtonRound(
                  icon: Icons.close,
                  size: 32,
                  variant: IconButtonVariant.plain,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Speed', style: TextStyle(color: c.textSecondary, fontSize: 13)),
                Slider(
                  value: _rate,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  activeColor: c.accent,
                  onChanged: (v) => setState(() => _rate = v),
                  onChangeEnd: (v) => widget.provider.setRate(v),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pitch', style: TextStyle(color: c.textSecondary, fontSize: 13)),
                Slider(
                  value: _pitch,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  activeColor: c.accent,
                  onChanged: (v) => setState(() => _pitch = v),
                  onChangeEnd: (v) => widget.provider.setPitch(v),
                ),
              ],
            ),
          ),
          if (widget.provider.voices.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Voice', style: TextStyle(color: c.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButton<int>(
                    value: widget.provider.selectedVoiceIndex >= 0
                        ? widget.provider.selectedVoiceIndex
                        : null,
                    isExpanded: true,
                    dropdownColor: c.bgElevated,
                    style: TextStyle(color: c.textPrimary, fontSize: 14),
                    underline: const SizedBox(),
                    items: List.generate(widget.provider.voices.length, (i) {
                      final name = TtsProvider.friendlyVoiceName(widget.provider.voices[i]);
                      return DropdownMenuItem(
                        value: i,
                        child: Text(name, overflow: TextOverflow.ellipsis),
                      );
                    }),
                    onChanged: (idx) {
                      if (idx == null) return;
                      widget.provider.setVoice(widget.provider.voices[idx]);
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

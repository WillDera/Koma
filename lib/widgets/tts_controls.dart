import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/reader/tts/tts_engine.dart';
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
                    onPressed: () => provider.stop(),
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
                    icon: provider.isPaused ? Icons.play_arrow : Icons.pause,
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
      isScrollControlled: true,
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
  late TtsEngineType _engineType;
  late TextEditingController _apiCtrl;

  @override
  void initState() {
    super.initState();
    _rate = switch (widget.provider.engineType) {
      TtsEngineType.device => 0.5,
      TtsEngineType.googleCloud => 1.0,
      TtsEngineType.edge => 0.88,
    };
    _pitch = switch (widget.provider.engineType) {
      TtsEngineType.device => 1.0,
      TtsEngineType.googleCloud => 0.0,
      TtsEngineType.edge => -0.02,
    };
    _engineType = widget.provider.engineType;
    _apiCtrl = TextEditingController();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    if (widget.provider.engineType != TtsEngineType.googleCloud) return;
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('google_tts_api_key') ?? '';
    if (mounted) _apiCtrl.text = key;
  }

  void _onEngineChanged(TtsEngineType type) async {
    _rate = switch (type) {
      TtsEngineType.device => 0.5,
      TtsEngineType.googleCloud => 1.0,
      TtsEngineType.edge => 0.88,
    };
    _pitch = switch (type) {
      TtsEngineType.device => 1.0,
      TtsEngineType.googleCloud => 0.0,
      TtsEngineType.edge => -0.02,
    };
    setState(() => _engineType = type);
    widget.provider.setEngineType(type);
    if (type == TtsEngineType.googleCloud && _apiCtrl.text.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString('google_tts_api_key') ?? '';
      if (mounted) _apiCtrl.text = key;
      if (key.isNotEmpty) {
        await widget.provider.setGoogleApiKey(key);
      }
    }
  }

  @override
  void dispose() {
    _apiCtrl.dispose();
    super.dispose();
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

          // Engine selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Engine', style: TextStyle(color: c.textSecondary, fontSize: 13)),
                const SizedBox(height: 6),
                SegmentedButton<TtsEngineType>(
                  segments: const [
                    ButtonSegment(value: TtsEngineType.device, label: Text('Device')),
                    ButtonSegment(value: TtsEngineType.googleCloud, label: Text('Google')),
                    ButtonSegment(value: TtsEngineType.edge, label: Text('Edge')),
                  ],
                  selected: {_engineType},
                  onSelectionChanged: (selected) => _onEngineChanged(selected.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // API key for Google Cloud
          if (_engineType == TtsEngineType.googleCloud)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('API Key', style: TextStyle(color: c.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _apiCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter your Google Cloud TTS API key',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    style: TextStyle(color: c.textPrimary, fontSize: 14),
                  ),
                ],
              ),
            ),

          // Voice selector
          if (widget.provider.voices.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Voice', style: TextStyle(color: c.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  ListenableBuilder(
                    listenable: widget.provider,
                    builder: (context, _) {
                      return DropdownButton<int>(
                        value: widget.provider.selectedVoiceIndex >= 0
                            ? widget.provider.selectedVoiceIndex
                            : null,
                        isExpanded: true,
                        dropdownColor: c.bgElevated,
                        style: TextStyle(color: c.textPrimary, fontSize: 14),
                        underline: const SizedBox(),
                        items: List.generate(widget.provider.voices.length, (i) {
                          final v = widget.provider.voices[i];
                          return DropdownMenuItem(
                            value: i,
                            child: Text(v.displayName, overflow: TextOverflow.ellipsis),
                          );
                        }),
                        onChanged: (idx) {
                          if (idx == null) return;
                          widget.provider.setVoice(widget.provider.voices[idx]);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Speed', style: TextStyle(color: c.textSecondary, fontSize: 13)),
                Slider(
                  value: _rate,
                  min: _engineType == TtsEngineType.device ? 0.0 : 0.25,
                  max: _engineType == TtsEngineType.device ? 1.0 : 2.0,
                  divisions: _engineType == TtsEngineType.device ? 20 : 35,
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
                  value: _pitch.clamp(
                    _engineType == TtsEngineType.device ? 0.5 : -0.5,
                    _engineType == TtsEngineType.device ? 2.0 : 0.5,
                  ),
                  min: _engineType == TtsEngineType.device ? 0.5 : -0.5,
                  max: _engineType == TtsEngineType.device ? 2.0 : 0.5,
                  divisions: _engineType == TtsEngineType.device ? 15 : 20,
                  activeColor: c.accent,
                  onChanged: (v) => setState(() => _pitch = v),
                  onChangeEnd: (v) => widget.provider.setPitch(v),
                ),
              ],
            ),
          ),
          // Save API key if Google Cloud
          if (_engineType == TtsEngineType.googleCloud && _apiCtrl.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: c.accent),
                  onPressed: () async {
                    await widget.provider.setGoogleApiKey(_apiCtrl.text.trim());
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('API key saved'),
                          backgroundColor: c.accent,
                        ),
                      );
                    }
                  },
                  child: const Text('Save API Key'),
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

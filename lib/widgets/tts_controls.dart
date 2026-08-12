import 'package:flutter/material.dart';
import '../core/services/piper_voice_service.dart';
import '../features/reader/tts/tts_engine.dart';
import '../features/reader/tts_provider.dart';
import '../features/settings/piper_voice_ui.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/glass_blur.dart';
import 'icon_button_round.dart';

class TtsControls extends StatelessWidget {
  final TtsProvider provider;

  const TtsControls({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        return GlassBlur.layer(
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
                    provider.isBuffering
                        ? SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.accent,
                            ),
                          )
                        : IconButtonRound(
                            icon: provider.isPaused
                                ? Icons.play_arrow
                                : Icons.pause,
                            size: 36,
                            variant: IconButtonVariant.filled,
                            iconColor: c.onAccent,
                            backgroundColor: c.accent,
                            onPressed: () {
                              if (provider.isPaused) {
                                provider.playFromCurrent();
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
                      onPressed:
                          provider.currentIndex < provider.totalSentences - 1
                          ? () => provider.nextSentence()
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${provider.currentIndex + 1} / ${provider.totalSentences}',
                        style: TextStyle(color: c.textSecondary, fontSize: 12),
                      ),
                    ),
                    IconButtonRound(
                      icon: Icons.tune,
                      size: 36,
                      variant: IconButtonVariant.tonal,
                      onPressed: () => TtsSettingsSheet.show(
                        context,
                        provider,
                        startOnClose: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class TtsSettingsSheet extends StatefulWidget {
  final TtsProvider provider;
  final bool startOnClose;

  const TtsSettingsSheet({
    super.key,
    required this.provider,
    this.startOnClose = false,
  });

  /// Returns `true` when [startOnClose] is set and the sheet was dismissed
  /// (user should begin TTS). Returns `false` if the sheet is cancelled in a
  /// way that should not start (currently always dismissed → start when true).
  static Future<bool> show(
    BuildContext context,
    TtsProvider provider, {
    bool startOnClose = false,
  }) async {
    await provider.loadPrefs();
    if (!context.mounted) return false;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TtsSettingsSheet(
        provider: provider,
        startOnClose: startOnClose,
      ),
    );
    if (startOnClose) {
      await provider.persistSelection();
      return true;
    }
    return false;
  }

  @override
  State<TtsSettingsSheet> createState() => _TtsSettingsSheetState();
}

class _TtsSettingsSheetState extends State<TtsSettingsSheet> {
  late double _rate;
  late double _pitch;
  late TtsEngineType _engineType;
  late bool _remember;
  late bool _optimistic;

  @override
  void initState() {
    super.initState();
    final p = widget.provider;
    _engineType = p.engineType;
    _rate = p.rate;
    _pitch = p.pitch;
    _remember = p.rememberSelection;
    _optimistic = p.optimistic;
  }

  Future<void> _onEngineChanged(TtsEngineType type) async {
    setState(() {
      _engineType = type;
      _rate = switch (type) {
        TtsEngineType.device => 0.5,
        TtsEngineType.edge => 0.88,
        TtsEngineType.piper => 1.0,
      };
      _pitch = switch (type) {
        TtsEngineType.device => 1.0,
        TtsEngineType.edge => -0.02,
        TtsEngineType.piper => 0.0,
      };
    });
    await widget.provider.setEngineType(
      type,
      restartIfPlaying: !widget.startOnClose && widget.provider.isActive,
    );
    widget.provider.setRate(_rate);
    widget.provider.setPitch(_pitch);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Material (not Container+DecoratedBox) so Switch/Checkbox ListTiles
    // can paint ink splashes on a real Material ancestor.
    return Material(
      color: c.bgElevated,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
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
                  Text(
                    'Engine',
                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<TtsEngineType>(
                    segments: [
                      const ButtonSegment(
                        value: TtsEngineType.device,
                        label: Text('Device'),
                      ),
                      const ButtonSegment(
                        value: TtsEngineType.edge,
                        label: Text('Edge'),
                      ),
                      if (PiperPlatform.isSupported)
                        const ButtonSegment(
                          value: TtsEngineType.piper,
                          label: Text('Piper'),
                        ),
                    ],
                    selected: {_engineType},
                    onSelectionChanged: (selected) =>
                        _onEngineChanged(selected.first),
                  ),
                ],
              ),
            ),

            if (_engineType == TtsEngineType.piper) ...[
              const SizedBox(height: 12),
              PiperVoiceSettingsSection(
                onCatalogChanged: () async {
                  await widget.provider.setEngineType(
                    TtsEngineType.piper,
                    restartIfPlaying: false,
                  );
                  if (mounted) setState(() {});
                },
              ),
            ],

            if (widget.provider.voices.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voice',
                      style: TextStyle(color: c.textSecondary, fontSize: 13),
                    ),
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
                          items: List.generate(widget.provider.voices.length, (
                            i,
                          ) {
                            final v = widget.provider.voices[i];
                            return DropdownMenuItem(
                              value: i,
                              child: Text(
                                v.displayName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                          onChanged: (idx) {
                            if (idx == null) return;
                            widget.provider.setVoice(
                              widget.provider.voices[idx],
                            );
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
                  Text(
                    'Speed',
                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                  ),
                  Slider(
                    value: _rate,
                    min: switch (_engineType) {
                      TtsEngineType.device => 0.0,
                      TtsEngineType.edge => 0.25,
                      TtsEngineType.piper => 0.25,
                    },
                    max: switch (_engineType) {
                      TtsEngineType.device => 1.0,
                      TtsEngineType.edge => 2.0,
                      TtsEngineType.piper => 2.0,
                    },
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
                  Text(
                    'Pitch',
                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                  ),
                  Slider(
                    value: _pitch.clamp(
                      switch (_engineType) {
                        TtsEngineType.device => 0.5,
                        TtsEngineType.edge => -0.5,
                        TtsEngineType.piper => -0.5,
                      },
                      switch (_engineType) {
                        TtsEngineType.device => 2.0,
                        TtsEngineType.edge => 0.5,
                        TtsEngineType.piper => 0.5,
                      },
                    ),
                    min: switch (_engineType) {
                      TtsEngineType.device => 0.5,
                      TtsEngineType.edge => -0.5,
                      TtsEngineType.piper => -0.5,
                    },
                    max: switch (_engineType) {
                      TtsEngineType.device => 2.0,
                      TtsEngineType.edge => 0.5,
                      TtsEngineType.piper => 0.5,
                    },
                    divisions: _engineType == TtsEngineType.device ? 15 : 20,
                    activeColor: c.accent,
                    onChanged: (v) => setState(() => _pitch = v),
                    onChangeEnd: (v) => widget.provider.setPitch(v),
                  ),
                ],
              ),
            ),

            if (_engineType == TtsEngineType.edge)
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: Text(
                  'Optimistic TTS',
                  style: TextStyle(color: c.textPrimary, fontSize: 14),
                ),
                subtitle: Text(
                  'Preload the whole chapter (and the next) so playback starts faster',
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
                value: _optimistic,
                activeThumbColor: c.accent,
                onChanged: (v) async {
                  setState(() => _optimistic = v);
                  await widget.provider.setOptimistic(v);
                },
              ),

            CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'Remember selection',
                style: TextStyle(color: c.textPrimary, fontSize: 14),
              ),
              subtitle: Text(
                'Skip this sheet next time and start with these settings',
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              ),
              value: _remember,
              activeColor: c.accent,
              onChanged: (v) async {
                final value = v ?? false;
                setState(() => _remember = value);
                await widget.provider.setRememberSelection(value);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

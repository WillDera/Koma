import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/reader/tts/tts_engine.dart';
import '../features/reader/tts_controls_prefs.dart';
import '../features/reader/tts_provider.dart';
import '../theme/app_theme.dart';
import 'icon_button_round.dart';
import 'segmented_control.dart';

/// Floating TTS transport — discrete circular pills like [ReaderBottomBar],
/// no connecting strip behind them.
class TtsControls extends StatelessWidget {
  final TtsProvider provider;

  /// When false, skip bottom [SafeArea] padding — use when this panel sits
  /// above another chrome bar that already clears the home indicator.
  final bool padBottomSafeArea;

  /// Horizontal row (bottom) or vertical stack (left / right edge).
  final Axis axis;

  const TtsControls({
    super.key,
    required this.provider,
    this.padBottomSafeArea = true,
    this.axis = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final chromeBg = c.surface;
    final vertical = axis == Axis.vertical;
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final canPrev = provider.currentIndex > 0;
        final canNext = provider.currentIndex < provider.totalSentences - 1;

        Widget gap() => vertical
            ? const SizedBox(height: 10)
            : const SizedBox(width: 10);

        final play = provider.isBuffering
            ? SizedBox(
                width: 48,
                height: 48,
                child: Material(
                  color: chromeBg,
                  shape: const CircleBorder(),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: c.accent,
                      ),
                    ),
                  ),
                ),
              )
            : _TtsCircle(
                icon: provider.isPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                chromeBg: chromeBg,
                filled: true,
                onTap: () {
                  if (provider.isPaused) {
                    provider.playFromCurrent();
                  } else {
                    provider.pause();
                  }
                },
              );

        final transport = <Widget>[
          _TtsCircle(
            icon: Icons.close,
            chromeBg: chromeBg,
            onTap: () => provider.stop(),
          ),
          gap(),
          _TtsCircle(
            icon: Icons.skip_previous_rounded,
            chromeBg: chromeBg,
            enabled: canPrev,
            onTap: () => provider.previousSentence(),
          ),
          gap(),
          play,
          gap(),
          _TtsCircle(
            icon: Icons.skip_next_rounded,
            chromeBg: chromeBg,
            enabled: canNext,
            onTap: () => provider.nextSentence(),
          ),
        ];

        final tune = _TtsCircle(
          icon: Icons.tune_rounded,
          chromeBg: chromeBg,
          onTap: () => TtsSettingsSheet.show(
            context,
            provider,
            startOnClose: false,
          ),
        );

        final body = vertical
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [...transport, gap(), tune],
              )
            : Row(
                children: [...transport, const Spacer(), tune],
              );

        return SafeArea(
          top: false,
          bottom: padBottomSafeArea,
          child: Padding(
            padding: vertical
                ? const EdgeInsets.symmetric(vertical: 8)
                : const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: body,
          ),
        );
      },
    );
  }
}

/// Same silhouette as [ReaderBottomBar]'s circular nav buttons.
class _TtsCircle extends StatelessWidget {
  const _TtsCircle({
    required this.icon,
    required this.chromeBg,
    required this.onTap,
    this.enabled = true,
    this.filled = false,
  });

  final IconData icon;
  final Color chromeBg;
  final VoidCallback onTap;
  final bool enabled;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = filled && enabled ? c.accent : chromeBg;
    final fg = filled && enabled
        ? c.onAccent
        : (enabled ? c.textPrimary : c.textTertiary.withValues(alpha: 0.45));
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: fg, size: 26),
        ),
      ),
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
      useRootNavigator: true,
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
      };
      _pitch = switch (type) {
        TtsEngineType.device => 1.0,
        TtsEngineType.edge => -0.02,
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
                    'Controls placement',
                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Consumer(
                    builder: (context, ref, _) {
                      final media = ref.watch(ttsControlsPrefsProvider);
                      return SegmentedControl<TtsControlsPlacement>(
                        value: media.placement,
                        onChanged: (v) => ref
                            .read(ttsControlsPrefsProvider.notifier)
                            .setPlacement(v),
                        segments: const {
                          TtsControlsPlacement.left: 'Left',
                          TtsControlsPlacement.bottom: 'Bottom',
                          TtsControlsPlacement.right: 'Right',
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

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
                    segments: const [
                      ButtonSegment(
                        value: TtsEngineType.device,
                        label: Text('Device'),
                      ),
                      ButtonSegment(
                        value: TtsEngineType.edge,
                        label: Text('Edge'),
                      ),
                    ],
                    selected: {_engineType},
                    onSelectionChanged: (selected) =>
                        _onEngineChanged(selected.first),
                  ),
                ],
              ),
            ),

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
                    value: _rate.clamp(
                      switch (_engineType) {
                        TtsEngineType.device => 0.0,
                        TtsEngineType.edge => 0.25,
                      },
                      switch (_engineType) {
                        TtsEngineType.device => 1.0,
                        TtsEngineType.edge => 2.0,
                      },
                    ),
                    min: switch (_engineType) {
                      TtsEngineType.device => 0.0,
                      TtsEngineType.edge => 0.25,
                    },
                    max: switch (_engineType) {
                      TtsEngineType.device => 1.0,
                      TtsEngineType.edge => 2.0,
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
                      },
                      switch (_engineType) {
                        TtsEngineType.device => 2.0,
                        TtsEngineType.edge => 0.5,
                      },
                    ),
                    min: switch (_engineType) {
                      TtsEngineType.device => 0.5,
                      TtsEngineType.edge => -0.5,
                    },
                    max: switch (_engineType) {
                      TtsEngineType.device => 2.0,
                      TtsEngineType.edge => 0.5,
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
                'Keep engine, voice, speed, and pitch',
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

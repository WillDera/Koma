import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'tts_engine.dart';

class DeviceTtsEngine implements TtsEngine {
  final FlutterTts _tts = FlutterTts();

  List<TtsVoice> _voices = [];
  TtsVoice? _selectedVoice;
  bool _isPlaying = false;
  bool _isPaused = false;
  @override
  bool get isBuffering => false;
  double _rate = 0.5;
  double _pitch = 1.0;
  int _startOffset = 0;
  String _fullText = '';

  Timer? _fallbackTimer;
  Timer? _progressTimer;
  DateTime? _playStartTime;

  void Function(int)? _onProgress;
  void Function()? _onComplete;

  @override
  List<TtsVoice> get voices => _voices;

  @override
  TtsVoice? get selectedVoice => _selectedVoice;

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get isPaused => _isPaused;

  @override
  Future<void> init() async {
    try {
      final raw = await _tts.getVoices;
      _voices = raw
          .whereType<Map>()
          .map((v) {
            final m = Map<String, String>.from(v);
            final name = m['name'] ?? '';
            return TtsVoice(
              id: name,
              name: _friendlyName(m),
              gender: _genderFromName(name),
              isNeural: name.contains('wavenet') || name.contains('neural'),
              locale: m['locale'] ?? '',
              engineType: TtsEngineType.device,
            );
          })
          .toList();
    } catch (_) {
      _voices = [];
    }
    await _tts.setSpeechRate(_rate);
    await _tts.setPitch(_pitch);
  }

  @override
  Future<void> speak(
    String text, {
    int startOffset = 0,
    required void Function(int charOffset) onProgress,
    required void Function() onComplete,
  }) async {
    _fullText = text;
    _startOffset = startOffset;
    _onProgress = onProgress;
    _onComplete = onComplete;

    _tts.setProgressHandler(_onTtsProgress);
    _tts.setCompletionHandler(_onTtsComplete);
    _tts.setErrorHandler((_) {
      stop();
      onComplete();
    });

    final remaining = text.substring(startOffset);
    if (remaining.isEmpty) {
      onComplete();
      return;
    }
    _tts.speak(remaining);
    _isPlaying = true;
    _isPaused = false;
    _playStartTime = DateTime.now();
    _scheduleFallback(remaining);
    _startProgressTimer();
  }

  void _onTtsProgress(String text, int start, int end, String word) {
    _onProgress?.call(_startOffset + start);
  }

  void _onTtsComplete() {
    _cleanup();
    _isPlaying = false;
    _isPaused = false;
    _onComplete?.call();
  }

  void _scheduleFallback(String text) {
    _fallbackTimer?.cancel();
    final estimatedMs = (text.length / (15 * _rate.clamp(0.1, 1.0)) * 1000)
        .clamp(3000, 60000)
        .toInt();
    _fallbackTimer = Timer(Duration(milliseconds: estimatedMs), () {
      _cleanup();
      _isPlaying = false;
      _isPaused = false;
      _onComplete?.call();
    });
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!_isPlaying || _playStartTime == null) return;
      final elapsed =
          DateTime.now().difference(_playStartTime!).inMilliseconds / 1000.0;
      final estimatedOffset =
          _startOffset + (elapsed * 15 * _rate.clamp(0.1, 1.0)).round();
      _onProgress?.call(estimatedOffset);
    });
  }

  @override
  void pause() {
    _cleanup();
    _tts.stop();
    _isPaused = true;
    _isPlaying = false;
  }

  @override
  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    _isPlaying = true;
    final remaining = _fullText.substring(_startOffset);
    if (remaining.isNotEmpty) {
      _tts.speak(remaining);
      _playStartTime = DateTime.now();
      _scheduleFallback(remaining);
      _startProgressTimer();
    }
  }

  @override
  void stop() {
    _cleanup();
    _tts.stop();
    _isPlaying = false;
    _isPaused = false;
  }

  void _cleanup() {
    _fallbackTimer?.cancel();
    _progressTimer?.cancel();
  }

  @override
  Future<void> setVoice(TtsVoice voice) async {
    _selectedVoice = voice;
    final voiceMap = await _findNativeVoice(voice.id);
    if (voiceMap != null) await _tts.setVoice(voiceMap);
  }

  Future<Map<String, String>?> _findNativeVoice(String id) async {
    try {
      final raw = await _tts.getVoices;
      return raw.whereType<Map>().firstWhere(
        (v) => (v['name'] ?? '') == id,
      ) as Map<String, String>?;
    } catch (_) {
      return null;
    }
  }

  @override
  void setRate(double rate) {
    _rate = rate;
    _tts.setSpeechRate(rate);
  }

  @override
  void setPitch(double pitch) {
    _pitch = pitch;
    _tts.setPitch(pitch);
  }

  @override
  void dispose() {
    _cleanup();
    _tts.stop();
    _tts.setProgressHandler((_, __, ___, ____) {});
    _tts.setCompletionHandler(() {});
    _tts.setErrorHandler((_) {});
  }

  static String _friendlyName(Map<String, String> v) {
    final name = v['name'] ?? '';
    final localeLabel = _localeLabel(v);
    final tag = _voiceTag(name);
    return tag != null ? '$localeLabel · $tag' : localeLabel;
  }

  static String _localeLabel(Map<String, String> v) {
    final locale = (v['locale'] ?? v['name'] ?? '').replaceAll('_', '-');
    final parts = locale.split('-');
    if (parts.length >= 2 && parts[0].length == 2) {
      const langs = {
        'en': 'English', 'es': 'Spanish', 'fr': 'French',
        'de': 'German', 'it': 'Italian', 'pt': 'Portuguese',
        'ru': 'Russian', 'ja': 'Japanese', 'ko': 'Korean',
      };
      return '${langs[parts[0]] ?? parts[0].toUpperCase()} (${parts[1].toUpperCase()})';
    }
    return locale;
  }

  static String? _voiceTag(String name) {
    final m = RegExp(r'x-([a-z]+)-local').firstMatch(name);
    if (m == null) return null;
    const labels = <String, String>{
      'sfb': 'Default', 'sfd': 'Default 2', 'sfg': 'Default 3',
      'tpd': 'Variant B', 'wavenet': 'Wavenet',
      'standard': 'Standard', 'network': 'Network',
    };
    return labels[m.group(1)!] ?? m.group(1)!.toUpperCase();
  }

  static String? _genderFromName(String name) {
    final n = name.toLowerCase();
    if (n.contains('male')) return 'Male';
    if (n.contains('female')) return 'Female';
    return null;
  }
}

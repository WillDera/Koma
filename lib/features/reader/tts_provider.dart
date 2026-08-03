import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tts/tts_engine.dart';
import 'tts/device_tts.dart';
import 'tts/edge_tts.dart';

class TtsProvider extends ChangeNotifier {
  static const prefsRemember = 'tts_remember_selection';
  static const prefsEngine = 'tts_engine';
  static const prefsVoice = 'tts_voice_id';
  static const prefsRate = 'tts_rate';
  static const prefsPitch = 'tts_pitch';
  static const prefsOptimistic = 'tts_optimistic';

  TtsEngineType _engineType = TtsEngineType.device;
  TtsEngine _engine = DeviceTtsEngine();

  String _fullText = '';
  String? _chapterId;
  List<String> _sentences = [];
  List<int> _sentenceOffsets = [];
  int _currentIndex = 0;
  int _progressOffset = 0;

  bool _rememberSelection = false;
  bool _optimistic = false;
  bool _prefsLoaded = false;
  double _rate = 0.5;
  double _pitch = 1.0;

  TtsEngine get engine => _engine;
  TtsEngineType get engineType => _engineType;

  bool get isPlaying => _engine.isPlaying;
  bool get isPaused => _engine.isPaused;
  bool get isActive =>
      _engine.isPlaying || _engine.isPaused || _engine.isBuffering;
  bool get isBuffering => _engine.isBuffering;
  int get currentIndex => _currentIndex;
  int get totalSentences => _sentences.length;
  int get currentSentenceOffset => _currentIndex < _sentenceOffsets.length
      ? _sentenceOffsets[_currentIndex]
      : 0;
  int get currentSentenceEnd {
    if (_currentIndex + 1 < _sentenceOffsets.length) {
      return _sentenceOffsets[_currentIndex + 1];
    }
    return _currentIndex < _sentences.length
        ? _sentenceOffsets[_currentIndex] + _sentences[_currentIndex].length
        : 0;
  }

  bool get rememberSelection => _rememberSelection;
  bool get optimistic => _optimistic;
  bool get prefsLoaded => _prefsLoaded;
  double get rate => _rate;
  double get pitch => _pitch;
  String? get chapterId => _chapterId;

  List<TtsVoice> get voices {
    if (_engineType == TtsEngineType.device) {
      final deviceVoices = (_engine as DeviceTtsEngine).voices.where((v) {
        final l = (v.locale ?? v.id).toLowerCase();
        return l.startsWith('en');
      }).toList();
      if (deviceVoices.isEmpty) {
        return [
          const TtsVoice(
            id: 'default',
            name: 'System Default',
            engineType: TtsEngineType.device,
          ),
        ];
      }
      return deviceVoices;
    }
    return _engine.voices;
  }

  TtsVoice? get selectedVoice => _engine.selectedVoice;
  String get selectedVoiceName =>
      _engine.selectedVoice?.displayName ?? 'Default';
  int get selectedVoiceIndex =>
      voices.indexWhere((v) => v.id == _engine.selectedVoice?.id);

  Future<void> loadPrefs() async {
    if (_prefsLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _rememberSelection = prefs.getBool(prefsRemember) ?? false;
    _optimistic = prefs.getBool(prefsOptimistic) ?? false;
    final engineName = prefs.getString(prefsEngine);
    final type = switch (engineName) {
      'edge' => TtsEngineType.edge,
      // Migrate removed Google Cloud preference to device.
      'googleCloud' => TtsEngineType.device,
      _ => TtsEngineType.device,
    };
    await _switchEngine(type);
    await _engine.init();

    final savedRate = prefs.getDouble(prefsRate);
    final savedPitch = prefs.getDouble(prefsPitch);
    _rate = savedRate ?? _defaultRate(type);
    _pitch = savedPitch ?? _defaultPitch(type);
    _engine.setRate(_rate);
    _engine.setPitch(_pitch);

    final voiceId = prefs.getString(prefsVoice);
    if (voiceId != null && voiceId.isNotEmpty) {
      final match = voices.cast<TtsVoice?>().firstWhere(
        (v) => v!.id == voiceId,
        orElse: () => null,
      );
      if (match != null) await _engine.setVoice(match);
    }

    _configureEdge();
    _prefsLoaded = true;
    notifyListeners();
  }

  Future<void> persistSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsRemember, _rememberSelection);
    await prefs.setBool(prefsOptimistic, _optimistic);
    await prefs.setString(
      prefsEngine,
      _engineType == TtsEngineType.edge ? 'edge' : 'device',
    );
    await prefs.setDouble(prefsRate, _rate);
    await prefs.setDouble(prefsPitch, _pitch);
    final voiceId = _engine.selectedVoice?.id;
    if (voiceId != null) await prefs.setString(prefsVoice, voiceId);
  }

  Future<void> setRememberSelection(bool value) async {
    _rememberSelection = value;
    await persistSelection();
    notifyListeners();
  }

  Future<void> setOptimistic(bool value) async {
    _optimistic = value;
    _configureEdge();
    await persistSelection();
    notifyListeners();
  }

  static double _defaultRate(TtsEngineType type) =>
      type == TtsEngineType.device ? 0.5 : 0.88;

  static double _defaultPitch(TtsEngineType type) =>
      type == TtsEngineType.device ? 1.0 : -0.02;

  void _configureEdge() {
    if (_engine is EdgeTtsEngine) {
      final edge = _engine as EdgeTtsEngine;
      edge.configure(
        optimistic: _optimistic,
        chapterId: _chapterId,
      );
      edge.onStateChanged = () {
        if (hasListeners) notifyListeners();
      };
    }
  }

  Future<void> init(
    String text, {
    TtsEngineType? engineType,
    String? chapterId,
  }) async {
    if (!_prefsLoaded) await loadPrefs();
    if (engineType != null) {
      await _switchEngine(engineType);
    }
    _fullText = text;
    _chapterId = chapterId;
    _splitSentences(text);
    await _engine.init();
    _configureEdge();
    _currentIndex = 0;
    _progressOffset = 0;
    notifyListeners();
  }

  Future<void> _switchEngine(TtsEngineType type) async {
    _engine.dispose();
    _engineType = type;
    _engine = switch (type) {
      TtsEngineType.device => DeviceTtsEngine(),
      TtsEngineType.edge => EdgeTtsEngine(),
    };
    _rate = _defaultRate(type);
    _pitch = _defaultPitch(type);
    _configureEdge();
  }

  void _splitSentences(String text) {
    _sentences = [];
    _sentenceOffsets = [];
    int start = 0;
    for (int i = 0; i < text.length; i++) {
      if ('.!?\n'.contains(text[i])) {
        final s = text.substring(start, i + 1).trim();
        if (s.isNotEmpty) {
          _sentences.add(s);
          _sentenceOffsets.add(start);
        }
        start = i + 1;
        while (start < text.length && text[start] == ' ') {
          start++;
        }
      }
    }
    if (start < text.length) {
      final remaining = text.substring(start).trim();
      if (remaining.isNotEmpty) {
        _sentences.add(remaining);
        _sentenceOffsets.add(start);
      }
    }
    if (_sentences.isEmpty && text.isNotEmpty) {
      _sentences.add(text);
      _sentenceOffsets.add(0);
    }
  }

  /// Restart from the beginning of the loaded text.
  void play() {
    if (_engine.isPaused) {
      _engine.resume();
      notifyListeners();
      return;
    }
    _currentIndex = 0;
    _progressOffset = 0;
    _speakFromCurrent();
    notifyListeners();
  }

  /// Resume if paused, otherwise speak from the current sentence index.
  void playFromCurrent() {
    if (_engine.isPaused) {
      _engine.resume();
      notifyListeners();
      return;
    }
    _speakFromCurrent();
    notifyListeners();
  }

  void pause() {
    _engine.pause();
    notifyListeners();
  }

  void stop() {
    _engine.stop();
    _currentIndex = 0;
    _progressOffset = 0;
    notifyListeners();
  }

  void nextSentence() {
    final wasActive = isActive;
    _engine.stop();
    if (_currentIndex < _sentences.length - 1) {
      _currentIndex++;
    }
    if (wasActive) {
      _speakFromCurrent();
    }
    notifyListeners();
  }

  void previousSentence() {
    final wasActive = isActive;
    _engine.stop();
    if (_currentIndex > 0) {
      _currentIndex--;
    }
    if (wasActive) {
      _speakFromCurrent();
    }
    notifyListeners();
  }

  void seekToSentence(int index) {
    if (index < 0 || index >= _sentences.length) return;
    final wasActive = isActive;
    _engine.stop();
    _currentIndex = index;
    if (wasActive) _speakFromCurrent();
    notifyListeners();
  }

  void _speakFromCurrent() {
    if (_currentIndex >= _sentences.length) return;
    _progressOffset = _sentenceOffsets[_currentIndex];
    _configureEdge();
    _engine.speak(
      _fullText,
      startOffset: _progressOffset,
      onProgress: _onProgress,
      onComplete: _onComplete,
    );
  }

  void _onProgress(int charOffset) {
    final idx = _sentenceIndexAtOffset(charOffset);
    if (idx != _currentIndex && idx < _sentences.length) {
      _currentIndex = idx;
      notifyListeners();
    }
  }

  void _onComplete() {
    notifyListeners();
  }

  int _sentenceIndexAtOffset(int offset) {
    for (int i = _sentenceOffsets.length - 1; i >= 0; i--) {
      if (_sentenceOffsets[i] <= offset) return i;
    }
    return 0;
  }

  Future<void> setVoice(TtsVoice voice) async {
    await _engine.setVoice(voice);
    if (_rememberSelection) await persistSelection();
    final wasPlaying = isPlaying;
    if (wasPlaying) {
      _engine.stop();
      _speakFromCurrent();
    }
    notifyListeners();
  }

  void setRate(double rate) {
    _rate = rate;
    _engine.setRate(rate);
    if (_rememberSelection) persistSelection();
    if (_engine.isPlaying) {
      _engine.stop();
      _speakFromCurrent();
    }
    notifyListeners();
  }

  void setPitch(double pitch) {
    _pitch = pitch;
    _engine.setPitch(pitch);
    if (_rememberSelection) persistSelection();
    if (_engine.isPlaying) {
      _engine.stop();
      _speakFromCurrent();
    }
    notifyListeners();
  }

  Future<void> setEngineType(
    TtsEngineType type, {
    bool restartIfPlaying = true,
  }) async {
    if (type == _engineType) return;
    final wasPlaying = isPlaying || isPaused;
    _engine.stop();
    await _switchEngine(type);
    await _engine.init();
    _engine.setRate(_rate);
    _engine.setPitch(_pitch);
    if (_rememberSelection) await persistSelection();
    if (restartIfPlaying && wasPlaying && _sentences.isNotEmpty) {
      _speakFromCurrent();
    }
    notifyListeners();
  }

  /// Prefetch Edge audio for [chapterId]/[text] when optimistic Edge is on.
  void prefetchChapter(String chapterId, String text) {
    if (!_optimistic || _engineType != TtsEngineType.edge) return;
    if (_engine is! EdgeTtsEngine) return;
    (_engine as EdgeTtsEngine).prefetchChapter(chapterId, text);
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }
}

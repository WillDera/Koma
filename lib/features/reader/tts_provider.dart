import 'package:flutter/material.dart';
import 'tts/tts_engine.dart';
import 'tts/device_tts.dart';
import 'tts/google_cloud_tts.dart';
import 'tts/edge_tts.dart';

class TtsProvider extends ChangeNotifier {
  TtsEngineType _engineType = TtsEngineType.device;
  TtsEngine _engine = DeviceTtsEngine();

  String _fullText = '';
  List<String> _sentences = [];
  List<int> _sentenceOffsets = [];
  int _currentIndex = 0;
  int _progressOffset = 0;

  TtsEngine get engine => _engine;
  TtsEngineType get engineType => _engineType;

  bool get isPlaying => _engine.isPlaying;
  bool get isPaused => _engine.isPaused;
  bool get isActive => _engine.isPlaying || _engine.isPaused;
  int get currentIndex => _currentIndex;
  int get totalSentences => _sentences.length;
  int get currentSentenceOffset =>
      _currentIndex < _sentenceOffsets.length ? _sentenceOffsets[_currentIndex] : 0;
  int get currentSentenceEnd {
    if (_currentIndex + 1 < _sentenceOffsets.length) {
      return _sentenceOffsets[_currentIndex + 1];
    }
    return _currentIndex < _sentences.length
        ? _sentenceOffsets[_currentIndex] + _sentences[_currentIndex].length
        : 0;
  }

  List<TtsVoice> get voices {
    if (_engineType == TtsEngineType.device) {
      final deviceVoices = (_engine as DeviceTtsEngine).voices.where((v) {
        final l = (v.locale ?? v.id).toLowerCase();
        return l.startsWith('en');
      }).toList();
      if (deviceVoices.isEmpty) {
        return [
          const TtsVoice(id: 'default', name: 'System Default',
              engineType: TtsEngineType.device),
        ];
      }
      return deviceVoices;
    }
    return _engine.voices;
  }

  TtsVoice? get selectedVoice => _engine.selectedVoice;
  String get selectedVoiceName => _engine.selectedVoice?.displayName ?? 'Default';
  int get selectedVoiceIndex => voices
      .indexWhere((v) => v.id == _engine.selectedVoice?.id);

  Future<void> init(String text, {TtsEngineType? engineType}) async {
    if (engineType != null) {
      await _switchEngine(engineType);
    }
    _fullText = text;
    _splitSentences(text);
    await _engine.init();
    _currentIndex = 0;
    _progressOffset = 0;
    notifyListeners();
  }

  Future<void> _switchEngine(TtsEngineType type) async {
    _engine.dispose();
    _engineType = type;
    _engine = switch (type) {
      TtsEngineType.device => DeviceTtsEngine(),
      TtsEngineType.googleCloud => GoogleCloudTtsEngine(),
      TtsEngineType.edge => EdgeTtsEngine(),
    };
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
        while (start < text.length && text[start] == ' ') start++;
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

  void play() {
    if (_engine.isPaused) {
      _engine.resume();
      notifyListeners();
      return;
    }
    _currentIndex = 0;
    _progressOffset = 0;
    _engine.speak(
      _fullText,
      startOffset: 0,
      onProgress: _onProgress,
      onComplete: _onComplete,
    );
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
    _engine.stop();
    if (_currentIndex < _sentences.length - 1) {
      _currentIndex++;
    }
    if (_engine.isPlaying) {
      _speakFromCurrent();
    }
    notifyListeners();
  }

  void previousSentence() {
    _engine.stop();
    if (_currentIndex > 0) {
      _currentIndex--;
    }
    if (_engine.isPlaying) {
      _speakFromCurrent();
    }
    notifyListeners();
  }

  void seekToSentence(int index) {
    if (index < 0 || index >= _sentences.length) return;
    _engine.stop();
    _currentIndex = index;
    if (_engine.isPlaying) _speakFromCurrent();
    notifyListeners();
  }

  void _speakFromCurrent() {
    if (_currentIndex >= _sentences.length) return;
    _progressOffset = _sentenceOffsets[_currentIndex];
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
    notifyListeners();
  }

  void setRate(double rate) {
    _engine.setRate(rate);
    if (_engine.isPlaying) {
      _engine.stop();
      _speakFromCurrent();
    }
    notifyListeners();
  }

  void setPitch(double pitch) {
    _engine.setPitch(pitch);
    if (_engine.isPlaying) {
      _engine.stop();
      _speakFromCurrent();
    }
    notifyListeners();
  }

  Future<void> setEngineType(TtsEngineType type) async {
    if (type == _engineType) return;
    _engine.stop();
    await _switchEngine(type);
    await _engine.init();
    if (_sentences.isNotEmpty && isActive) _speakFromCurrent();
    notifyListeners();
  }

  Future<void> setGoogleApiKey(String key) async {
    if (_engine is GoogleCloudTtsEngine) {
      await (_engine as GoogleCloudTtsEngine).saveApiKey(key);
    }
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsProvider extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();

  String _fullText = '';
  List<String> _sentences = [];
  List<int> _sentenceOffsets = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isPaused = false;
  double _rate = 0.5;
  double _pitch = 1.0;
  List<Map<String, String>> _voices = [];
  Map<String, String>? _selectedVoice;

  Timer? _fallbackTimer;
  Timer? _progressTimer;
  DateTime? _playStartTime;
  int _playStartOffset = 0;

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  bool get isActive => _isPlaying || _isPaused;
  int get currentIndex => _currentIndex;
  int get totalSentences => _sentences.length;
  double get rate => _rate;
  double get pitch => _pitch;
  List<Map<String, String>> get voices => _voices;
  Map<String, String>? get selectedVoice => _selectedVoice;
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

  String get selectedVoiceName {
    if (_selectedVoice == null) return 'Default';
    return friendlyVoiceName(_selectedVoice!);
  }

  int get selectedVoiceIndex {
    if (_selectedVoice == null) return -1;
    return _voices.indexWhere((v) =>
        v['name'] == _selectedVoice!['name']);
  }

  Future<void> init(String text) async {
    _fullText = text;
    _splitSentences(text);
    await _initTts();

    _tts.setProgressHandler(_onProgress);
    _tts.setErrorHandler((msg) {
      stop();
      notifyListeners();
    });
    notifyListeners();
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

  Future<void> _initTts() async {
    try {
      final raw = await _tts.getVoices;
      _voices = raw
          .map<Map<String, String>>((v) =>
              Map<String, String>.from(v as Map))
          .toList();
    } catch (_) {
      _voices = [];
    }
    if (_voices.isNotEmpty && _selectedVoice == null) {
      _selectedVoice = _voices.firstWhere(
        (v) => (v['name'] ?? '').contains('en-us'),
        orElse: () => _voices.first,
      );
      if (_selectedVoice != null) await _tts.setVoice(_selectedVoice!);
    }
    await _tts.setSpeechRate(_rate);
    await _tts.setPitch(_pitch);

    _tts.setCompletionHandler(() {
      _fallbackTimer?.cancel();
      _progressTimer?.cancel();
      _isPlaying = false;
      _isPaused = false;
      _currentIndex = _sentences.length;
      notifyListeners();
    });
  }

  void _onProgress(String text, int start, int end, String word) {
    final idx = _sentenceIndexAtOffset(start);
    if (idx != _currentIndex && idx < _sentences.length) {
      _currentIndex = idx;
      notifyListeners();
    }
  }

  int _sentenceIndexAtOffset(int offset) {
    for (int i = _sentenceOffsets.length - 1; i >= 0; i--) {
      if (_sentenceOffsets[i] <= offset) return i;
    }
    return 0;
  }

  void play() {
    _fallbackTimer?.cancel();
    _progressTimer?.cancel();
    if (_isPaused) {
      _playStartOffset = _sentenceOffsets[_currentIndex];
      _tts.speak(_fullText.substring(_playStartOffset));
      _isPaused = false;
    } else {
      _currentIndex = 0;
      _playStartOffset = 0;
      _tts.speak(_fullText);
    }
    _isPlaying = true;
    _playStartTime = DateTime.now();
    _scheduleFallback();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      estimateProgress();
    });
    notifyListeners();
  }

  void pause() {
    _fallbackTimer?.cancel();
    _progressTimer?.cancel();
    _tts.stop();
    _isPaused = true;
    _isPlaying = false;
    notifyListeners();
  }

  void stop() {
    _fallbackTimer?.cancel();
    _progressTimer?.cancel();
    _tts.stop();
    _currentIndex = 0;
    _isPlaying = false;
    _isPaused = false;
    notifyListeners();
  }

  void nextSentence() {
    _fallbackTimer?.cancel();
    _tts.stop();
    if (_currentIndex < _sentences.length - 1) {
      _currentIndex++;
      if (_isPlaying) _speakFromCurrent();
      notifyListeners();
    }
  }

  void previousSentence() {
    _fallbackTimer?.cancel();
    _tts.stop();
    if (_currentIndex > 0) {
      _currentIndex--;
      if (_isPlaying) _speakFromCurrent();
      notifyListeners();
    }
  }

  void seekToSentence(int index) {
    if (index < 0 || index >= _sentences.length) return;
    _fallbackTimer?.cancel();
    _tts.stop();
    _currentIndex = index;
    if (_isPlaying) _speakFromCurrent();
    notifyListeners();
  }

  void _speakFromCurrent() {
    if (_currentIndex >= _sentences.length) return;
    _playStartOffset = _sentenceOffsets[_currentIndex];
    try {
      _tts.speak(_fullText.substring(_playStartOffset));
      _playStartTime = DateTime.now();
      _scheduleFallback();
      _progressTimer?.cancel();
      _progressTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
        estimateProgress();
      });
    } catch (_) {
      stop();
    }
  }

  void _scheduleFallback() {
    _fallbackTimer?.cancel();
    final remaining = _fullText.length - _playStartOffset;
    // ponytail: fallback for TTS engines missing progress/completion callbacks
    final estimatedMs = (remaining / (15 * max(_rate, 0.1)) * 1000)
        .clamp(3000, 60000)
        .toInt();
    _fallbackTimer = Timer(Duration(milliseconds: estimatedMs), () {
      _fallbackTimer = null;
      _progressTimer?.cancel();
      _isPlaying = false;
      _isPaused = false;
      _currentIndex = _sentences.length;
      notifyListeners();
    });
  }

  // ponytail: approximate progress for engines without progress handler
  void estimateProgress() {
    if (!_isPlaying || _playStartTime == null) return;
    final elapsed = DateTime.now().difference(_playStartTime!).inMilliseconds / 1000.0;
    final estimatedOffset = _playStartOffset +
        (elapsed * 15 * max(_rate, 0.1)).round();
    final idx = _sentenceIndexAtOffset(estimatedOffset);
    if (idx != _currentIndex && idx < _sentences.length) {
      _currentIndex = idx;
      notifyListeners();
    }
  }

  void setRate(double rate) {
    _rate = rate;
    _tts.setSpeechRate(rate);
    if (_isPlaying && _currentIndex < _sentences.length) {
      _tts.stop();
      _speakFromCurrent();
    }
    notifyListeners();
  }

  void setPitch(double pitch) {
    _pitch = pitch;
    _tts.setPitch(pitch);
    if (_isPlaying && _currentIndex < _sentences.length) {
      _tts.stop();
      _speakFromCurrent();
    }
    notifyListeners();
  }

  Future<void> setVoice(Map<String, String> voice) async {
    _selectedVoice = voice;
    await _tts.setVoice(voice);
    if (_isPlaying && _currentIndex < _sentences.length) {
      _tts.stop();
      _speakFromCurrent();
    }
    notifyListeners();
  }

  static String friendlyVoiceName(Map<String, String> voice) {
    final name = voice['name'] ?? '';
    final locale = voice['locale'] ?? '';
    if (locale.isNotEmpty) {
      final parts = locale.split('-');
      if (parts.length >= 2) {
        final lang = _languageName(parts[0]);
        final region = parts[1].toUpperCase();
        return '$lang ($region)';
      }
      return _languageName(parts[0]);
    }
    if (name.isNotEmpty) {
      final parts = name.split('-');
      if (parts.length >= 2) {
        final lang = _languageName(parts[0]);
        final region = parts[1].toUpperCase();
        return '$lang ($region)';
      }
    }
    return locale.isNotEmpty ? locale : name;
  }

  static String _languageName(String code) {
    const names = <String, String>{
      'en': 'English', 'es': 'Spanish', 'fr': 'French',
      'de': 'German', 'it': 'Italian', 'pt': 'Portuguese',
      'ru': 'Russian', 'ja': 'Japanese', 'ko': 'Korean',
      'zh': 'Chinese', 'ar': 'Arabic', 'hi': 'Hindi',
      'bn': 'Bengali', 'ur': 'Urdu', 'nl': 'Dutch',
      'sv': 'Swedish', 'da': 'Danish', 'fi': 'Finnish',
      'no': 'Norwegian', 'pl': 'Polish', 'tr': 'Turkish',
      'th': 'Thai', 'vi': 'Vietnamese', 'cs': 'Czech',
      'ro': 'Romanian', 'hu': 'Hungarian', 'el': 'Greek',
      'he': 'Hebrew', 'id': 'Indonesian', 'ms': 'Malay',
    };
    return names[code] ?? code.toUpperCase();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _progressTimer?.cancel();
    _tts.stop();
    _tts.setProgressHandler((_, __, ___, ____) {});
    _tts.setCompletionHandler(() {});
    _tts.setErrorHandler((_) {});
    super.dispose();
  }
}

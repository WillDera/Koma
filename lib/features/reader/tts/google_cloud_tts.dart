import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tts_engine.dart';

class GoogleCloudTtsEngine implements TtsEngine {
  final AudioPlayer _player = AudioPlayer();

  String _apiKey = '';
  String _voiceName = 'en-US-Chirp3-HD-Iapetus';
  String _languageCode = 'en-US';
  double _rate = 1.0;
  double _pitch = 0.0;
  bool _isPlaying = false;
  bool _isPaused = false;
  @override
  bool get isBuffering => false;

  Timer? _progressTimer;
  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;
  void Function()? _onComplete;
  void Function(int)? _onProgress;

  List<WordTimestamp> _allTimestamps = [];
  String _lastProgressWord = '';

  static const _apiUrl = 'https://texttospeech.googleapis.com/v1/text:synthesize';

  @override
  List<TtsVoice> get voices => _curatedVoices;

  @override
  TtsVoice? get selectedVoice => _curatedVoices.cast<TtsVoice?>().firstWhere(
        (v) => v!.id == _voiceName,
        orElse: () => _curatedVoices.first,
      );

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get isPaused => _isPaused;

  Future<String?> get savedApiKey async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('google_tts_api_key');
  }

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('google_tts_api_key', key);
    _apiKey = key;
  }

  Future<void> loadApiKey() async {
    _apiKey = (await savedApiKey) ?? '';
  }

  @override
  Future<void> init() async {
    await loadApiKey();
  }

  @override
  Future<void> speak(
    String text, {
    int startOffset = 0,
    required void Function(int charOffset) onProgress,
    required void Function() onComplete,
  }) async {
    if (_apiKey.isEmpty) {
      onComplete();
      return;
    }

    _onProgress = onProgress;
    _onComplete = onComplete;
    _allTimestamps = [];
    _lastProgressWord = '';

    final adjusted = text.substring(startOffset);
    if (adjusted.isEmpty) {
      onComplete();
      return;
    }

    _isPlaying = true;
    _isPaused = false;

    try {
      final chunks = _splitChunks(adjusted, startOffset);
      final audioSources = <AudioSource>[];

      for (final chunk in chunks) {
        final result = await _synthesize(chunk);
        if (result == null) continue;
        audioSources.add(AudioSource.uri(
          Uri.parse('data:audio/mpeg;base64,${base64Encode(result.audioBytes)}'),
        ));
        _allTimestamps.addAll(result.timestamps);
      }

      if (audioSources.isEmpty) {
        onComplete();
        return;
      }

      _stateSub?.cancel();
      _stateSub = _player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) _onTtsComplete();
      });

      _posSub?.cancel();
      _posSub = _player.positionStream.listen(_onPosition);

      final concat = audioSources.length == 1
          ? audioSources.first
          : ConcatenatingAudioSource(children: audioSources);

      await _player.setAudioSource(concat);
      _player.play();
    } catch (_) {
      _isPlaying = false;
      onComplete();
    }
  }

  List<_Chunk> _splitChunks(String text, int baseOffset) {
    final chunks = <_Chunk>[];
    final sentences = text.split(RegExp(r'(?<=[.!?\n])\s*'));
    final buf = StringBuffer();
    int charsInBuf = 0;

    for (final s in sentences) {
      if (s.isEmpty) continue;
      if (buf.length + s.length > 4000 && buf.isNotEmpty) {
        chunks.add(_Chunk(buf.toString(), baseOffset + charsInBuf - buf.length));
        buf.clear();
      }
      buf.write(s);
      charsInBuf += s.length;
    }
    if (buf.isNotEmpty) {
      chunks.add(_Chunk(buf.toString(), baseOffset + charsInBuf - buf.length));
    }
    return chunks;
  }

  Future<_SynthesizeResult?> _synthesize(_Chunk chunk) async {
    final body = jsonEncode({
      'input': {'text': chunk.text},
      'voice': {
        'languageCode': _languageCode,
        'name': _voiceName,
      },
      'audioConfig': {
        'audioEncoding': 'MP3',
        'speakingRate': _rate,
        'pitch': _pitch,
      },
      'enableTimePointing': ['WORD'],
    });

    final resp = await http.post(
      Uri.parse('$_apiUrl?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (resp.statusCode != 200) return null;

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final audioB64 = data['audioContent'] as String?;
    if (audioB64 == null || audioB64.isEmpty) return null;

    final audioBytes = base64Decode(audioB64);
    final timestamps = <WordTimestamp>[];

    final rawTimepoints = data['timepoints'] as List<dynamic>? ?? [];
    final textWords = _splitWords(chunk.text);
    int charsConsumed = 0;

    for (final tp in rawTimepoints) {
      final word = tp['markName'] as String? ?? '';
      final secs = (tp['timeSeconds'] as num?)?.toDouble() ?? 0;
      final charOff = chunk.baseOffset + _findWordOffset(textWords, charsConsumed, word);
      timestamps.add(WordTimestamp(word, Duration(milliseconds: (secs * 1000).round()), charOff));
      charsConsumed = min(charsConsumed + word.length + 1, chunk.text.length);
    }

    return _SynthesizeResult(audioBytes, timestamps);
  }

  int _findWordOffset(List<String> words, int from, String word) {
    for (int i = 0; i < words.length; i++) {
      if (words[i] == word) {
        final offset = words.take(i).fold<int>(0, (sum, w) => sum + w.length + 1);
        return from + max(offset - 1, 0);
      }
    }
    return from;
  }

  List<String> _splitWords(String text) {
    final words = <String>[];
    final buf = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (text[i] == ' ') {
        if (buf.isNotEmpty) { words.add(buf.toString()); buf.clear(); }
      } else {
        buf.write(text[i]);
      }
    }
    if (buf.isNotEmpty) words.add(buf.toString());
    return words;
  }

  void _onPosition(Duration position) {
    WordTimestamp? best;
    for (final ts in _allTimestamps) {
      if (ts.time <= position) best = ts;
    }
    if (best != null && best.word != _lastProgressWord) {
      _lastProgressWord = best.word;
      _onProgress?.call(best.charOffset);
    }
  }

  void _onTtsComplete() {
    _cleanup();
    _isPlaying = false;
    _isPaused = false;
    _onComplete?.call();
  }

  @override
  void pause() {
    _player.pause();
    _isPaused = true;
    _isPlaying = false;
  }

  @override
  void resume() {
    if (!_isPaused) return;
    _player.play();
    _isPaused = false;
    _isPlaying = true;
  }

  @override
  void stop() {
    _cleanup();
    _player.stop();
    _isPlaying = false;
    _isPaused = false;
  }

  void _cleanup() {
    _progressTimer?.cancel();
    _posSub?.cancel();
    _stateSub?.cancel();
  }

  @override
  Future<void> setVoice(TtsVoice voice) async {
    _voiceName = voice.id;
    _languageCode = voice.locale ?? 'en-US';
  }

  @override
  void setRate(double rate) { _rate = rate; }

  @override
  void setPitch(double pitch) { _pitch = pitch; }

  @override
  void dispose() {
    _cleanup();
    _player.dispose();
  }

  static final List<TtsVoice> _curatedVoices = [
    const TtsVoice(id: 'en-US-Chirp3-HD-Iapetus', name: 'Iapetus', gender: 'Male', isNeural: true, locale: 'en-US'),
    const TtsVoice(id: 'en-US-Chirp3-HD-Orus', name: 'Orus', gender: 'Male', isNeural: true, locale: 'en-US'),
    const TtsVoice(id: 'en-US-Chirp3-HD-Rasalgethi', name: 'Rasalgethi', gender: 'Male', isNeural: true, locale: 'en-US'),
    const TtsVoice(id: 'en-US-Chirp3-HD-Fenrir', name: 'Fenrir', gender: 'Male', isNeural: true, locale: 'en-US'),
    const TtsVoice(id: 'en-US-Chirp3-HD-Algieba', name: 'Algieba', gender: 'Male', isNeural: true, locale: 'en-US'),
    const TtsVoice(id: 'en-US-Chirp3-HD-Athena', name: 'Athena', gender: 'Female', isNeural: true, locale: 'en-US'),
    const TtsVoice(id: 'en-US-Chirp3-HD-Pixel', name: 'Pixel', gender: 'Female', isNeural: true, locale: 'en-US'),
    const TtsVoice(id: 'en-US-Neural2-J', name: 'Neural2 J', gender: 'Male', isNeural: true, locale: 'en-US'),
    const TtsVoice(id: 'en-US-Neural2-I', name: 'Neural2 I', gender: 'Male', isNeural: true, locale: 'en-US'),
    const TtsVoice(id: 'en-US-Neural2-F', name: 'Neural2 F', gender: 'Female', isNeural: true, locale: 'en-US'),
    const TtsVoice(id: 'en-GB-Neural2-B', name: 'Neural2 B', gender: 'Male', isNeural: true, locale: 'en-GB'),
    const TtsVoice(id: 'en-GB-Neural2-A', name: 'Neural2 A', gender: 'Female', isNeural: true, locale: 'en-GB'),
    const TtsVoice(id: 'en-US-Studio-M', name: 'Studio M', gender: 'Male', isNeural: true, locale: 'en-US'),
    const TtsVoice(id: 'en-US-Studio-O', name: 'Studio O', gender: 'Male', isNeural: true, locale: 'en-US'),
    const TtsVoice(id: 'en-GB-Studio-B', name: 'Studio B', gender: 'Male', isNeural: true, locale: 'en-GB'),
  ];
}

class _Chunk {
  final String text;
  final int baseOffset;
  const _Chunk(this.text, this.baseOffset);
}

class _SynthesizeResult {
  final Uint8List audioBytes;
  final List<WordTimestamp> timestamps;
  const _SynthesizeResult(this.audioBytes, this.timestamps);
}

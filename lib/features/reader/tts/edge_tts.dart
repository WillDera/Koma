import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:just_audio/just_audio.dart';
import 'tts_engine.dart';

class EdgeTtsEngine implements TtsEngine {
  final AudioPlayer _player = AudioPlayer();

  String _voiceName = 'en-US-AndrewMultilingualNeural';
  double _rate = 0.88;
  double _pitch = -0.02;
  bool _isPlaying = false;
  bool _isPaused = false;

  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;
  void Function()? _onComplete;
  void Function(int)? _onProgress;

  List<WordTimestamp> _allTimestamps = [];
  String _lastProgressWord = '';

  static const _wssBaseUrl =
      'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1';
  static const _trustedClientToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
  static const _chromiumMajor = '143';

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

  String get _ratePercent {
    final p = (_rate - 1.0) * 100;
    return '${p >= 0 ? "+" : ""}${p.toStringAsFixed(1)}%';
  }

  String get _pitchPercent {
    final p = _pitch * 100;
    return '${p >= 0 ? "+" : ""}${p.round()}%';
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> speak(
    String text, {
    int startOffset = 0,
    required void Function(int charOffset) onProgress,
    required void Function() onComplete,
  }) async {
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
      final audioBytes = await _synthesize(adjusted, startOffset);
      if (audioBytes.isEmpty) {
        _isPlaying = false;
        onComplete();
        return;
      }

      _stateSub?.cancel();
      _stateSub = _player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) _onTtsComplete();
      });

      _posSub?.cancel();
      _posSub = _player.positionStream.listen(_onPosition);

      await _player.setAudioSource(
        AudioSource.uri(
            Uri.parse('data:audio/mpeg;base64,${base64Encode(audioBytes)}')),
      );
      _player.play();
    } catch (_) {
      _isPlaying = false;
      onComplete();
    }
  }

  Future<Uint8List> _synthesize(String text, int baseOffset) async {
    final connectId = _uuid();
    final secMsGec = _generateSecMsGec();
    final muid = _generateMuid();
    final url = '$_wssBaseUrl?TrustedClientToken=$_trustedClientToken'
        '&ConnectionId=$connectId'
        '&Sec-MS-GEC=$secMsGec'
        '&Sec-MS-GEC-Version=1-$_chromiumMajor.0.3650.75';

    final ws = await WebSocket.connect(url, headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
          ' (KHTML, like Gecko) Chrome/$_chromiumMajor.0.0.0 Safari/537.36'
          ' Edg/$_chromiumMajor.0.0.0',
      'Pragma': 'no-cache',
      'Cache-Control': 'no-cache',
      'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
      'Sec-WebSocket-Version': '13',
      'Cookie': 'muid=$muid;',
    });

    final chunks = _splitChunks(text, baseOffset);
    final allAudio = <int>[];
    final completer = Completer<Uint8List>();

    ws.listen(
      (message) {
        if (message is String) {
          _handleTextMessage(message, ws);
        } else if (message is List<int>) {
          _handleBinaryMessage(message, allAudio);
        }
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete(Uint8List.fromList(allAudio));
      },
      onDone: () {
        _resolveCharOffsets(text, baseOffset);
        if (!completer.isCompleted) {
          completer.complete(Uint8List.fromList(allAudio));
        }
      },
    );

    // send speech.config
    ws.add(_buildConfigMessage());

    // send each chunk as a separate SSML request
    for (final chunk in chunks) {
      ws.add(_buildSsmlMessage(chunk.text));
    }

    Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        ws.close();
        completer.complete(Uint8List.fromList(allAudio));
      }
    });

    return completer.future;
  }

  String _buildConfigMessage() {
    return 'X-Timestamp:${_dateToString()}\r\n'
        'Content-Type:application/json; charset=utf-8\r\n'
        'Path:speech.config\r\n\r\n'
        '{"context":{"synthesis":{"audio":{"metadataoptions":{'
        '"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"true"'
        '},"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}';
  }

  String _buildSsmlMessage(String text) {
    final requestId = _uuid();
    final ssml = _buildSsml(text);
    return 'X-RequestId:$requestId\r\n'
        'Content-Type:application/ssml+xml\r\n'
        'X-Timestamp:${_dateToString()}Z\r\n'
        'Path:ssml\r\n\r\n'
        '$ssml';
  }

  void _handleTextMessage(String msg, WebSocket ws) {
    final headerEnd = msg.indexOf('\r\n\r\n');
    if (headerEnd < 0) return;
    final headerBlock = msg.substring(0, headerEnd);
    final body = msg.substring(headerEnd + 4);

    if (headerBlock.contains('Path:turn.end')) return;

    if (headerBlock.contains('Path:WordBoundary') ||
        headerBlock.contains('Path:SentenceBoundary')) {
      try {
        final data = jsonDecode(body) as Map<String, dynamic>;
        final metadata = data['Metadata'] as List<dynamic>? ?? [];
        for (final m in metadata) {
          final mData = m['Data'] as Map<String, dynamic>? ?? {};
          final textObj = mData['text'] as Map<String, dynamic>? ?? {};
          final word = textObj['Text'] as String? ?? '';
          final offset = (mData['Offset'] as num?)?.toInt() ?? 0;
          if (word.isNotEmpty) {
            _allTimestamps.add(WordTimestamp(
              word,
              Duration(microseconds: (offset / 10).round()),
              0,
            ));
          }
        }
      } catch (_) {}
    }
  }

  void _handleBinaryMessage(List<int> data, List<int> allAudio) {
    if (data.length < 4) return;
    final headerLength = (data[0] << 8) | data[1];
    final bodyStart = 2 + headerLength + 2; // 2 len prefix + headers + \r\n
    if (bodyStart > data.length) return;

    final headerBytes = data.sublist(2, 2 + headerLength);
    final headersStr = utf8.decode(headerBytes);
    if (!headersStr.contains('Path:audio')) return;

    allAudio.addAll(data.sublist(bodyStart));
  }

  void _onPosition(Duration position) {
    WordTimestamp? best;
    for (final ts in _allTimestamps) {
      if (ts.time <= position) best = ts;
    }
    if (best != null && best.word != _lastProgressWord && best.charOffset > 0) {
      _lastProgressWord = best.word;
      _onProgress?.call(best.charOffset);
    }
  }

  void _resolveCharOffsets(String text, int baseOffset) {
    final words = text.split(RegExp(r'\s+'));
    int charsConsumed = 0;
    int tsIndex = 0;
    for (int i = 0; i < words.length && tsIndex < _allTimestamps.length; i++) {
      if (words[i] == _allTimestamps[tsIndex].word) {
        _allTimestamps[tsIndex] = WordTimestamp(
          _allTimestamps[tsIndex].word,
          _allTimestamps[tsIndex].time,
          baseOffset + charsConsumed,
        );
        tsIndex++;
      }
      charsConsumed += words[i].length + 1;
    }
  }

  String _buildSsml(String text) {
    final escaped = _escapeXml(text);
    return "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'>"
        "<voice name='$_voiceName'>"
        "<prosody pitch='$_pitchPercent' rate='$_ratePercent'>"
        "$escaped"
        "</prosody>"
        "</voice>"
        "</speak>";
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
    _posSub?.cancel();
    _stateSub?.cancel();
  }

  @override
  Future<void> setVoice(TtsVoice voice) async {
    _voiceName = voice.id;
  }

  @override
  void setRate(double rate) {
    _rate = rate;
  }

  @override
  void setPitch(double pitch) {
    _pitch = pitch;
  }

  @override
  void dispose() {
    _cleanup();
    _player.dispose();
  }

  List<_Chunk> _splitChunks(String text, int baseOffset) {
    final chunks = <_Chunk>[];
    final sentences = text.split(RegExp(r'(?<=[.!?\n])\s*'));
    final buf = StringBuffer();
    int totalChars = 0;

    for (final s in sentences) {
      if (s.isEmpty) continue;
      if (buf.length + s.length > 4000 && buf.isNotEmpty) {
        chunks.add(_Chunk(buf.toString(), baseOffset + totalChars - buf.length));
        buf.clear();
      }
      buf.write(s);
      totalChars += s.length;
    }
    if (buf.isNotEmpty) {
      chunks.add(_Chunk(buf.toString(), baseOffset + totalChars - buf.length));
    }
    return chunks;
  }

  static String _generateSecMsGec() {
    final now = DateTime.now().toUtc();
    final ticks = (now.millisecondsSinceEpoch / 1000) + 11644473600;
    final rounded = ticks - (ticks % 300);
    final ticks100ns = (rounded * 10000000).round();
    final toHash = '$ticks100ns$_trustedClientToken';
    final bytes = utf8.encode(toHash);
    final digest = sha256.convert(bytes);
    return digest.toString().toUpperCase();
  }

  static String _generateMuid() {
    final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  static String _uuid() {
    final rand = Random.secure();
    final b = List.generate(16, (_) => rand.nextInt(256));
    b[6] = (b[6] & 0x0F) | 0x40;
    b[8] = (b[8] & 0x3F) | 0x80;
    final hex = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}'
        '-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static String _dateToString() {
    final now = DateTime.now().toUtc();
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${days[now.weekday % 7]} ${months[now.month - 1]} '
        '${now.day.toString().padLeft(2, '0')} ${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} '
        'GMT+0000 (Coordinated Universal Time)';
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static final List<TtsVoice> _curatedVoices = [
    const TtsVoice(id: 'en-US-AndrewMultilingualNeural', name: 'Andrew', gender: 'Male', isNeural: true, locale: 'en-US', engineType: TtsEngineType.edge),
    const TtsVoice(id: 'en-US-BrianMultilingualNeural', name: 'Brian', gender: 'Male', isNeural: true, locale: 'en-US', engineType: TtsEngineType.edge),
    const TtsVoice(id: 'en-US-ChristopherNeural', name: 'Christopher', gender: 'Male', isNeural: true, locale: 'en-US', engineType: TtsEngineType.edge),
    const TtsVoice(id: 'en-GB-RyanNeural', name: 'Ryan', gender: 'Male', isNeural: true, locale: 'en-GB', engineType: TtsEngineType.edge),
    const TtsVoice(id: 'en-US-GuyNeural', name: 'Guy', gender: 'Male', isNeural: true, locale: 'en-US', engineType: TtsEngineType.edge),
    const TtsVoice(id: 'en-US-JennyNeural', name: 'Jenny', gender: 'Female', isNeural: true, locale: 'en-US', engineType: TtsEngineType.edge),
    const TtsVoice(id: 'en-US-AriaNeural', name: 'Aria', gender: 'Female', isNeural: true, locale: 'en-US', engineType: TtsEngineType.edge),
    const TtsVoice(id: 'en-GB-SoniaNeural', name: 'Sonia', gender: 'Female', isNeural: true, locale: 'en-GB', engineType: TtsEngineType.edge),
    const TtsVoice(id: 'en-GB-AdrianMultilingualNeural', name: 'Adrian', gender: 'Male', isNeural: true, locale: 'en-GB', engineType: TtsEngineType.edge),
  ];
}

class _Chunk {
  final String text;
  final int baseOffset;
  const _Chunk(this.text, this.baseOffset);
}

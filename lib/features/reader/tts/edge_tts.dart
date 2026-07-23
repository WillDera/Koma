import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
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

  static const _trustedClientToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
  static const _chromiumMajor = '143';
  static const _chromiumFull = '143.0.3650.96';

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
      final chunks = _splitChunks(adjusted, startOffset);
      if (chunks.isEmpty) {
        _isPlaying = false;
        onComplete();
        return;
      }

      final playlist = ConcatenatingAudioSource(children: []);
      await _player.setAudioSource(playlist);

      _stateSub?.cancel();
      _stateSub = _player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) _onTtsComplete();
      });

      _posSub?.cancel();
      _posSub = _player.positionStream.listen(_onPosition);

      final audioList = await _synthesizeAll(chunks.map((c) => c.text).toList());
      bool started = false;
      for (final audio in audioList) {
        if (audio.isNotEmpty) {
          await playlist.add(_BytesAudioSource(audio));
          if (!started) {
            started = true;
            unawaited(_player.play());
          }
        }
      }

      if (!started) {
        _isPlaying = false;
        onComplete();
        return;
      }

      _resolveCharOffsets(adjusted, startOffset);
    } catch (e) {
      debugPrint('edge-tts speak error: $e');
      _isPlaying = false;
      onComplete();
    }
  }

  Future<WebSocket> _connect() async {
    final wsUrl = _buildWsUrl();
    final uri = Uri.parse(wsUrl).replace(scheme: 'https');
    final client = HttpClient();
    final request = await client.getUrl(uri);
    request.headers.set('Upgrade', 'websocket');
    request.headers.set('Connection', 'Upgrade');
    request.headers.set('Sec-WebSocket-Version', '13');
    request.headers.set(
      'Sec-WebSocket-Key',
      base64Encode(List.generate(16, (_) => Random.secure().nextInt(256))),
    );
    request.headers.set(
      'User-Agent',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
          ' (KHTML, like Gecko) Chrome/$_chromiumMajor.0.0.0 Safari/537.36'
          ' Edg/$_chromiumMajor.0.0.0',
    );
    request.headers.set(
      'Origin',
      'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
    );
    final response = await request.close();
    if (response.statusCode != HttpStatus.switchingProtocols) {
      final body = await response.transform(utf8.decoder).join();
      throw WebSocketException(
        "Connection to '$wsUrl' was not upgraded to websocket, "
        'HTTP status code: ${response.statusCode} ($body)',
      );
    }
    final socket = await response.detachSocket();
    return WebSocket.fromUpgradedSocket(
      socket,
      serverSide: false,
      protocol: null,
    );
  }

  String _buildWsUrl() {
    final connectId = _connectId();
    final secMsGec = _generateSecMsGec();
    return 'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1'
        '?TrustedClientToken=$_trustedClientToken'
        '&Sec-MS-GEC=$secMsGec'
        '&Sec-MS-GEC-Version=1-$_chromiumFull'
        '&ConnectionId=$connectId';
  }

  Future<List<Uint8List>> _synthesizeAll(List<String> texts) async {
    if (texts.isEmpty) return [];
    if (texts.length == 1) return [await _synthesizeChunk(texts.first)];

    final ws = await _connect();
    ws.add(_buildConfigMessage());

    final results = <Uint8List>[];
    final turnAudio = <int>[];
    Completer<void>? turnDone;

    final sub = ws.listen(
      (message) {
        if (message is String) {
          if (message.contains('\r\nPath:turn.end') && turnDone != null) {
            turnDone!.complete();
            turnDone = null;
          }
          _handleTextMessage(message);
        } else if (message is List<int>) {
          final audio = _extractAudio(message);
          if (audio != null) turnAudio.addAll(audio);
        }
      },
      onError: (e) {
        debugPrint('edge-tts stream error: $e');
        turnDone?.complete();
      },
    );

    for (final text in texts) {
      turnAudio.clear();
      turnDone = Completer<void>();
      ws.add(_buildSsmlMessage(text));
      await turnDone!.future;
      results.add(Uint8List.fromList(List.from(turnAudio)));
    }

    await sub.cancel();
    await ws.close();
    return results;
  }

  Future<Uint8List> _synthesizeChunk(String text) async {
    final ws = await _connect();
    final allAudio = <int>[];
    final completer = Completer<Uint8List>();

    ws.listen(
      (message) {
        if (message is String) {
          _handleTextMessage(message);
        } else if (message is List<int>) {
          final audio = _extractAudio(message);
          if (audio != null) allAudio.addAll(audio);
        }
      },
      onError: (e) {
        debugPrint('edge-tts stream error: $e');
        if (!completer.isCompleted) completer.complete(Uint8List.fromList(allAudio));
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(Uint8List.fromList(allAudio));
        }
      },
    );

    ws.add(_buildConfigMessage());
    ws.add(_buildSsmlMessage(text));

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
    final requestId = _connectId();
    final ssml = _buildSsml(text);
    return 'X-RequestId:$requestId\r\n'
        'Content-Type:application/ssml+xml\r\n'
        'X-Timestamp:${_dateToString()}Z\r\n'
        'Path:ssml\r\n\r\n'
        '$ssml';
  }

  void _handleTextMessage(String msg) {
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

  Uint8List? _extractAudio(List<int> data) {
    final start = _indexOf(data, _pathAudioNeedle);
    if (start < 0) return null;
    return Uint8List.fromList(data.sublist(start + _pathAudioNeedle.length));
  }

  static const _pathAudioNeedle = <int>[
    80, 97, 116, 104, 58, 97, 117, 100, 105, 111, 13, 10,
  ]; // "Path:audio\r\n"

  static int _indexOf(List<int> haystack, List<int> needle) {
    for (int i = 0; i <= haystack.length - needle.length; i++) {
      var match = true;
      for (int j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
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
    final paragraphs = text.split(RegExp(r'\n\n+'));
    int totalChars = 0;

    for (final p in paragraphs) {
      if (p.trim().isEmpty) continue;
      if (p.length <= 1500) {
        chunks.add(_Chunk(p, baseOffset + totalChars));
        totalChars += p.length;
      } else {
        final sentences = p.split(RegExp(r'(?<=[.!?])\s+'));
        final buf = StringBuffer();
        for (final s in sentences) {
          if (s.isEmpty) continue;
          if (buf.length + s.length > 1500 && buf.isNotEmpty) {
            chunks.add(_Chunk(
                buf.toString(), baseOffset + totalChars - buf.length));
            buf.clear();
          }
          buf.write(s);
        }
        if (buf.isNotEmpty) {
          chunks.add(_Chunk(
              buf.toString(), baseOffset + totalChars - buf.length));
        }
        totalChars += p.length;
      }
    }
    return chunks;
  }

  static String _generateSecMsGec() {
    // Match TypeScript msedge-tts: integer arithmetic, no floats.
    final ticks = (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) + 11644473600;
    final rounded = ticks - (ticks % 300);
    final windowsTicks = rounded * 10000000;
    final toHash = '$windowsTicks$_trustedClientToken';
    final bytes = utf8.encode(toHash);
    final digest = sha256.convert(bytes);
    return digest.toString().toUpperCase();
  }

  static String _connectId() {
    // Match TypeScript msedge-tts: standard UUID with dashes.
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

class _BytesAudioSource extends StreamAudioSource {
  final Uint8List _bytes;
  _BytesAudioSource(this._bytes) : super(tag: 'edge_tts_chunk');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}

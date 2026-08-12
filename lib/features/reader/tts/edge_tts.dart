import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'tts_engine.dart';

class _PrefetchedChapter {
  final List<Uint8List> audioChunks;
  final List<WordTimestamp> timestamps;
  final String voiceName;
  final double rate;
  final double pitch;

  const _PrefetchedChapter({
    required this.audioChunks,
    required this.timestamps,
    required this.voiceName,
    required this.rate,
    required this.pitch,
  });
}

class _SynthTurn {
  final Uint8List audio;
  final List<WordTimestamp> timestamps;
  const _SynthTurn(this.audio, this.timestamps);
}

class EdgeTtsEngine implements TtsEngine {
  final AudioPlayer _player = AudioPlayer();

  String _voiceName = 'en-US-AndrewMultilingualNeural';
  double _rate = 0.88;
  double _pitch = -0.02;
  bool _isPlaying = false;
  bool _isPaused = false;
  bool _isBuffering = false;
  bool _optimistic = false;
  String? _chapterId;
  int _speakGeneration = 0;
  void Function()? onStateChanged;

  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;
  void Function()? _onComplete;
  void Function(int)? _onProgress;

  List<WordTimestamp> _allTimestamps = [];
  String _lastProgressWord = '';

  static final Map<String, _PrefetchedChapter> _prefetchCache = {};
  static final Set<String> _prefetchInFlight = {};

  static const _trustedClientToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
  static const _chromiumMajor = '143';
  static const _chromiumFull = '143.0.3650.96';
  // Edge outputFormat: audio-24khz-48kbitrate-mono-mp3
  static const _mp3BytesPerSecond = 6000.0;

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
  @override
  bool get isBuffering => _isBuffering;

  void configure({required bool optimistic, String? chapterId}) {
    _optimistic = optimistic;
    _chapterId = chapterId;
  }

  void _emitState() {
    onStateChanged?.call();
  }

  String _cacheKey(String chapterId) =>
      '$chapterId|$_voiceName|$_rate|$_pitch';

  String get _ratePercent {
    final p = (_rate - 1.0) * 100;
    return '${p >= 0 ? "+" : ""}${p.toStringAsFixed(1)}%';
  }

  String get _pitchPercent {
    final p = _pitch * 100;
    return '${p >= 0 ? "+" : ""}${p.round()}%';
  }

  static Duration _estimateMp3Duration(Uint8List bytes) {
    if (bytes.isEmpty) return Duration.zero;
    final ms = (bytes.length / _mp3BytesPerSecond * 1000).round();
    return Duration(milliseconds: ms.clamp(1, 3600000));
  }

  @override
  Future<void> init() async {}

  /// Background-synthesize a chapter for optimistic playback.
  Future<void> prefetchChapter(String chapterId, String text) async {
    if (!_optimistic || text.trim().isEmpty) return;
    final key = _cacheKey(chapterId);
    if (_prefetchCache.containsKey(key) || _prefetchInFlight.contains(key)) {
      return;
    }
    _prefetchInFlight.add(key);
    try {
      final chunks = _splitChunks(text, 0);
      if (chunks.isEmpty) return;
      final turns = await _synthesizeTurns(chunks.map((c) => c.text).toList());
      final timestamps = <WordTimestamp>[];
      final audioChunks = <Uint8List>[];
      var cumulative = Duration.zero;
      for (var i = 0; i < turns.length && i < chunks.length; i++) {
        final turn = turns[i];
        if (turn.audio.isEmpty) continue;
        final shifted = turn.timestamps
            .map((t) => WordTimestamp(t.word, t.time + cumulative, 0))
            .toList();
        timestamps.addAll(shifted);
        audioChunks.add(turn.audio);
        cumulative += _estimateMp3Duration(turn.audio);
      }
      _resolveCharOffsetsOnto(timestamps, text, 0);
      _prefetchCache[key] = _PrefetchedChapter(
        audioChunks: audioChunks,
        timestamps: timestamps,
        voiceName: _voiceName,
        rate: _rate,
        pitch: _pitch,
      );
      // Bound cache size: keep at most 2 chapters.
      while (_prefetchCache.length > 2) {
        _prefetchCache.remove(_prefetchCache.keys.first);
      }
    } catch (e) {
      debugPrint('edge-tts prefetch error: $e');
    } finally {
      _prefetchInFlight.remove(key);
    }
  }

  @override
  Future<void> speak(
    String text, {
    int startOffset = 0,
    required void Function(int charOffset) onProgress,
    required void Function() onComplete,
  }) async {
    final gen = ++_speakGeneration;
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
    _isBuffering = true;
    _emitState();

    try {
      final chunks = _splitChunks(adjusted, startOffset);
      if (chunks.isEmpty) {
        _isPlaying = false;
        _isBuffering = false;
        _emitState();
        onComplete();
        return;
      }

      if (_optimistic) {
        await _speakOptimistic(text, startOffset, adjusted, chunks, gen);
      } else {
        await _speakChunkByChunk(chunks, gen);
      }
    } catch (e) {
      debugPrint('edge-tts speak error: $e');
      if (gen == _speakGeneration) {
        _isPlaying = false;
        _isBuffering = false;
        _emitState();
        onComplete();
      }
    }
  }

  Future<void> _speakOptimistic(
    String fullText,
    int startOffset,
    String adjusted,
    List<_Chunk> chunks,
    int gen,
  ) async {
    // Try prefetch cache for current chapter when starting from offset 0.
    final chapterId = _chapterId;
    if (chapterId != null && startOffset == 0) {
      final key = _cacheKey(chapterId);
      final cached = _prefetchCache.remove(key);
      if (cached != null &&
          cached.voiceName == _voiceName &&
          cached.rate == _rate &&
          cached.pitch == _pitch &&
          cached.audioChunks.isNotEmpty) {
        if (gen != _speakGeneration) return;
        _allTimestamps = List.of(cached.timestamps);
        await _playAudioChunks(cached.audioChunks, gen);
        return;
      }
    }

    final turns = await _synthesizeTurns(chunks.map((c) => c.text).toList());
    if (gen != _speakGeneration) return;

    final audioChunks = <Uint8List>[];
    final timestamps = <WordTimestamp>[];
    var cumulative = Duration.zero;
    for (final turn in turns) {
      if (turn.audio.isEmpty) continue;
      for (final t in turn.timestamps) {
        timestamps.add(WordTimestamp(t.word, t.time + cumulative, 0));
      }
      audioChunks.add(turn.audio);
      cumulative += _estimateMp3Duration(turn.audio);
    }

    if (audioChunks.isEmpty) {
      _isBuffering = false;
      _isPlaying = false;
      _emitState();
      _onComplete?.call();
      return;
    }

    _allTimestamps = timestamps;
    _resolveCharOffsets(adjusted, startOffset);
    await _playAudioChunks(audioChunks, gen);
  }

  Future<void> _speakChunkByChunk(List<_Chunk> chunks, int gen) async {
    for (var i = 0; i < chunks.length; i++) {
      if (gen != _speakGeneration) return;
      final chunk = chunks[i];
      _allTimestamps = [];
      _lastProgressWord = '';
      _isBuffering = true;

      final turns = await _synthesizeTurns([chunk.text]);
      if (gen != _speakGeneration) return;

      final turn = turns.isNotEmpty ? turns.first : null;
      if (turn == null || turn.audio.isEmpty) continue;

      _allTimestamps = List.of(turn.timestamps);
      _resolveCharOffsets(chunk.text, chunk.baseOffset);

      final completed = Completer<void>();
      await _playAudioChunks(
        [turn.audio],
        gen,
        onChunkComplete: () {
          if (!completed.isCompleted) completed.complete();
        },
        notifyCompleteOnEnd: false,
      );
      await completed.future;
      if (gen != _speakGeneration) return;
    }

    if (gen == _speakGeneration) {
      _isPlaying = false;
      _isPaused = false;
      _isBuffering = false;
      _emitState();
      _onComplete?.call();
    }
  }

  Future<void> _playAudioChunks(
    List<Uint8List> audioChunks,
    int gen, {
    void Function()? onChunkComplete,
    bool notifyCompleteOnEnd = true,
  }) async {
    final sources = audioChunks
        .where((a) => a.isNotEmpty)
        .map(_BytesAudioSource.new)
        .toList();
    if (sources.isEmpty) {
      _isBuffering = false;
      _isPlaying = false;
      _emitState();
      if (notifyCompleteOnEnd) _onComplete?.call();
      onChunkComplete?.call();
      return;
    }

    await _player.setAudioSource(
      ConcatenatingAudioSource(children: sources),
    );
    if (gen != _speakGeneration) return;

    _stateSub?.cancel();
    _stateSub = _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if (notifyCompleteOnEnd) {
          _onTtsComplete();
        } else {
          _cleanup();
          onChunkComplete?.call();
        }
      }
    });

    _posSub?.cancel();
    _posSub = _player.positionStream.listen(_onPosition);

    _isBuffering = false;
    _isPlaying = true;
    _isPaused = false;
    _emitState();
    await _player.play();
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

  Future<List<_SynthTurn>> _synthesizeTurns(List<String> texts) async {
    if (texts.isEmpty) return [];
    if (texts.length == 1) {
      return [await _synthesizeOneTurn(texts.first)];
    }

    final ws = await _connect();
    ws.add(_buildConfigMessage());

    final results = <_SynthTurn>[];
    final turnAudio = <int>[];
    var turnTimestamps = <WordTimestamp>[];
    Completer<void>? turnDone;

    final sub = ws.listen(
      (message) {
        if (message is String) {
          if (message.contains('\r\nPath:turn.end') && turnDone != null) {
            if (!turnDone!.isCompleted) turnDone!.complete();
            turnDone = null;
          }
          _collectWordBoundaries(message, turnTimestamps);
        } else if (message is List<int>) {
          final audio = _extractAudio(message);
          if (audio != null) turnAudio.addAll(audio);
        }
      },
      onError: (e) {
        debugPrint('edge-tts stream error: $e');
        if (turnDone != null && !turnDone!.isCompleted) turnDone!.complete();
      },
    );

    for (final text in texts) {
      turnAudio.clear();
      turnTimestamps = <WordTimestamp>[];
      turnDone = Completer<void>();
      ws.add(_buildSsmlMessage(text));
      await turnDone!.future.timeout(const Duration(seconds: 30));
      results.add(
        _SynthTurn(
          Uint8List.fromList(List.from(turnAudio)),
          List.of(turnTimestamps),
        ),
      );
    }

    await sub.cancel();
    await ws.close();
    return results;
  }

  Future<_SynthTurn> _synthesizeOneTurn(String text) async {
    final ws = await _connect();
    final allAudio = <int>[];
    final timestamps = <WordTimestamp>[];
    final completer = Completer<_SynthTurn>();

    ws.listen(
      (message) {
        if (message is String) {
          if (message.contains('\r\nPath:turn.end') &&
              !completer.isCompleted) {
            completer.complete(
              _SynthTurn(Uint8List.fromList(List.from(allAudio)), timestamps),
            );
            ws.close();
            return;
          }
          _collectWordBoundaries(message, timestamps);
        } else if (message is List<int>) {
          final audio = _extractAudio(message);
          if (audio != null) allAudio.addAll(audio);
        }
      },
      onError: (e) {
        debugPrint('edge-tts stream error: $e');
        if (!completer.isCompleted) {
          completer.complete(
            _SynthTurn(Uint8List.fromList(List.from(allAudio)), timestamps),
          );
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(
            _SynthTurn(Uint8List.fromList(List.from(allAudio)), timestamps),
          );
        }
      },
    );

    ws.add(_buildConfigMessage());
    ws.add(_buildSsmlMessage(text));

    Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        ws.close();
        completer.complete(
          _SynthTurn(Uint8List.fromList(List.from(allAudio)), timestamps),
        );
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

  void _collectWordBoundaries(String msg, List<WordTimestamp> into) {
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
            into.add(
              WordTimestamp(
                word,
                Duration(microseconds: (offset / 10).round()),
                0,
              ),
            );
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
    80,
    97,
    116,
    104,
    58,
    97,
    117,
    100,
    105,
    111,
    13,
    10,
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
    if (best != null &&
        best.word != _lastProgressWord &&
        best.charOffset >= 0) {
      _lastProgressWord = best.word;
      _onProgress?.call(best.charOffset);
    }
  }

  void _resolveCharOffsets(String text, int baseOffset) {
    _resolveCharOffsetsOnto(_allTimestamps, text, baseOffset);
  }

  static void _resolveCharOffsetsOnto(
    List<WordTimestamp> timestamps,
    String text,
    int baseOffset,
  ) {
    final words = text.split(RegExp(r'\s+'));
    int charsConsumed = 0;
    int tsIndex = 0;
    for (int i = 0; i < words.length && tsIndex < timestamps.length; i++) {
      if (words[i] == timestamps[tsIndex].word) {
        timestamps[tsIndex] = WordTimestamp(
          timestamps[tsIndex].word,
          timestamps[tsIndex].time,
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
    _isBuffering = false;
    _emitState();
    _onComplete?.call();
  }

  @override
  void pause() {
    _player.pause();
    _isPaused = true;
    _isPlaying = false;
    _emitState();
  }

  @override
  void resume() {
    if (!_isPaused) return;
    _player.play();
    _isPaused = false;
    _isPlaying = true;
    _emitState();
  }

  @override
  void stop() {
    _speakGeneration++;
    _cleanup();
    _player.stop();
    _isPlaying = false;
    _isPaused = false;
    _isBuffering = false;
    _emitState();
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
    int offset = baseOffset;

    for (final p in paragraphs) {
      if (p.trim().isEmpty) {
        offset += p.length;
        // Account for the split delimiter roughly — paragraphs from split
        // lose separators; keep absolute offsets best-effort via running total.
        continue;
      }
      if (p.length <= 1500) {
        chunks.add(_Chunk(p, offset));
        offset += p.length;
      } else {
        final sentences = p.split(RegExp(r'(?<=[.!?])\s+'));
        final buf = StringBuffer();
        var chunkStart = offset;
        for (final s in sentences) {
          if (s.isEmpty) continue;
          if (buf.length + s.length > 1500 && buf.isNotEmpty) {
            chunks.add(_Chunk(buf.toString(), chunkStart));
            chunkStart += buf.length;
            buf.clear();
          }
          if (buf.isNotEmpty) buf.write(' ');
          buf.write(s);
        }
        if (buf.isNotEmpty) {
          chunks.add(_Chunk(buf.toString(), chunkStart));
        }
        offset += p.length;
      }
    }
    return chunks;
  }

  static String _generateSecMsGec() {
    final ticks =
        (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) + 11644473600;
    final rounded = ticks - (ticks % 300);
    final windowsTicks = rounded * 10000000;
    final toHash = '$windowsTicks$_trustedClientToken';
    final bytes = utf8.encode(toHash);
    final digest = sha256.convert(bytes);
    return digest.toString().toUpperCase();
  }

  static String _connectId() {
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
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
    const TtsVoice(
      id: 'en-US-AndrewMultilingualNeural',
      name: 'Andrew',
      gender: 'Male',
      isNeural: true,
      locale: 'en-US',
      engineType: TtsEngineType.edge,
    ),
    const TtsVoice(
      id: 'en-US-BrianMultilingualNeural',
      name: 'Brian',
      gender: 'Male',
      isNeural: true,
      locale: 'en-US',
      engineType: TtsEngineType.edge,
    ),
    const TtsVoice(
      id: 'en-US-ChristopherNeural',
      name: 'Christopher',
      gender: 'Male',
      isNeural: true,
      locale: 'en-US',
      engineType: TtsEngineType.edge,
    ),
    const TtsVoice(
      id: 'en-GB-RyanNeural',
      name: 'Ryan',
      gender: 'Male',
      isNeural: true,
      locale: 'en-GB',
      engineType: TtsEngineType.edge,
    ),
    const TtsVoice(
      id: 'en-US-GuyNeural',
      name: 'Guy',
      gender: 'Male',
      isNeural: true,
      locale: 'en-US',
      engineType: TtsEngineType.edge,
    ),
    const TtsVoice(
      id: 'en-US-JennyNeural',
      name: 'Jenny',
      gender: 'Female',
      isNeural: true,
      locale: 'en-US',
      engineType: TtsEngineType.edge,
    ),
    const TtsVoice(
      id: 'en-US-AriaNeural',
      name: 'Aria',
      gender: 'Female',
      isNeural: true,
      locale: 'en-US',
      engineType: TtsEngineType.edge,
    ),
    const TtsVoice(
      id: 'en-GB-SoniaNeural',
      name: 'Sonia',
      gender: 'Female',
      isNeural: true,
      locale: 'en-GB',
      engineType: TtsEngineType.edge,
    ),
    const TtsVoice(
      id: 'en-GB-AdrianMultilingualNeural',
      name: 'Adrian',
      gender: 'Male',
      isNeural: true,
      locale: 'en-GB',
      engineType: TtsEngineType.edge,
    ),
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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_edge_tts/flutter_edge_tts.dart';
import 'package:just_audio/just_audio.dart';

import 'tts_engine.dart';

class _PrefetchedChapter {
  /// One synth turn per paragraph/chunk, in speak order.
  final List<_SynthTurn> turns;
  final String voiceName;
  final double rate;
  final double pitch;

  const _PrefetchedChapter({
    required this.turns,
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

/// Edge online TTS. Synthesis goes through [FlutterEdgeTts]; playback,
/// pipelined chunk prefetch, and word→char progress stay in-engine.
class EdgeTtsEngine implements TtsEngine {
  final AudioPlayer _player = AudioPlayer();
  FlutterEdgeTts? _client;

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
  int _lastProgressOffset = -1;

  /// Fallback when Edge returns no word boundaries: map position → chars.
  int _progressBaseOffset = 0;
  int _progressTextLength = 0;
  Duration _progressAudioDuration = Duration.zero;

  static final Map<String, _PrefetchedChapter> _prefetchCache = {};
  static final Set<String> _prefetchInFlight = {};

  // Matches audio-24khz-48kbitrate-mono-mp3.
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

  EdgeTtsProsody get _prosody => EdgeTtsProsody(
    rate: _ratePercent,
    pitch: _pitchPercent,
  );

  static Duration _estimateMp3Duration(Uint8List bytes) {
    if (bytes.isEmpty) return Duration.zero;
    final ms = (bytes.length / _mp3BytesPerSecond * 1000).round();
    return Duration(milliseconds: ms.clamp(1, 3600000));
  }

  FlutterEdgeTts _ensureClient() {
    final locale =
        selectedVoice?.locale ?? _localeFromVoiceId(_voiceName) ?? 'en-US';
    final config = EdgeTtsConfig(
      voice: _voiceName,
      voiceLocale: locale,
      outputFormat: EdgeTtsOutputFormat.audio24Khz48KbitrateMonoMp3,
      enableWordBoundary: true,
    );
    final existing = _client;
    if (existing == null) {
      final created = FlutterEdgeTts(
        voice: config.voice,
        voiceLocale: config.voiceLocale,
        outputFormat: config.outputFormat,
        enableWordBoundary: true,
      );
      _client = created;
      return created;
    }
    existing.updateConfig(config);
    return existing;
  }

  static String? _localeFromVoiceId(String id) {
    final parts = id.split('-');
    if (parts.length < 2) return null;
    return '${parts[0]}-${parts[1]}';
  }

  @override
  Future<void> init() async {
    _ensureClient();
  }

  /// Background-synthesize a chapter for optimistic / cache hits.
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
      final turns = <_SynthTurn>[];
      for (final chunk in chunks) {
        final turn = await _synthesizeOneTurn(chunk.text);
        if (turn.audio.isEmpty) continue;
        final stamped = List<WordTimestamp>.of(turn.timestamps);
        _resolveCharOffsetsOnto(stamped, chunk.text, chunk.baseOffset);
        turns.add(_SynthTurn(turn.audio, stamped));
      }
      if (turns.isEmpty) return;
      _prefetchCache[key] = _PrefetchedChapter(
        turns: turns,
        voiceName: _voiceName,
        rate: _rate,
        pitch: _pitch,
      );
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
    _lastProgressOffset = -1;

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

      // Prefer pipelined paragraph playback so the next chunk is synthesizing
      // while the current one plays (avoids multi-second gaps).
      await _speakPipelined(chunks, gen);
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

  /// Play chunks one-by-one, always synthesizing chunk i+1 while i plays.
  Future<void> _speakPipelined(List<_Chunk> chunks, int gen) async {
    // Warm start from full-chapter prefetch when available (offset 0 only).
    List<_SynthTurn?>? cachedTurns;
    final chapterId = _chapterId;
    if (chapterId != null &&
        chunks.isNotEmpty &&
        chunks.first.baseOffset == 0) {
      final key = _cacheKey(chapterId);
      final cached = _prefetchCache[key];
      if (cached != null &&
          cached.voiceName == _voiceName &&
          cached.rate == _rate &&
          cached.pitch == _pitch &&
          cached.turns.isNotEmpty) {
        cachedTurns = List<_SynthTurn?>.of(cached.turns);
      }
    }

    Future<_SynthTurn?> synthAt(int index) async {
      if (index < 0 || index >= chunks.length) return null;
      if (cachedTurns != null && index < cachedTurns.length) {
        final hit = cachedTurns[index];
        if (hit != null && hit.audio.isNotEmpty) return hit;
      }
      final chunk = chunks[index];
      final turn = await _synthesizeOneTurn(chunk.text);
      if (turn.audio.isEmpty) return null;
      final stamped = List<WordTimestamp>.of(turn.timestamps);
      _resolveCharOffsetsOnto(stamped, chunk.text, chunk.baseOffset);
      return _SynthTurn(turn.audio, stamped);
    }

    // Kick off first (and second) synthesis immediately.
    var pending = synthAt(0);
    Future<_SynthTurn?>? lookahead =
        chunks.length > 1 ? synthAt(1) : null;

    for (var i = 0; i < chunks.length; i++) {
      if (gen != _speakGeneration) return;

      _isBuffering = true;
      _emitState();
      final turn = await pending;
      if (gen != _speakGeneration) return;

      // Start synthesizing the chunk after next while we play this one.
      pending = lookahead ?? Future<_SynthTurn?>.value(null);
      lookahead = (i + 2 < chunks.length) ? synthAt(i + 2) : null;

      if (turn == null || turn.audio.isEmpty) continue;

      _allTimestamps = List.of(turn.timestamps);
      _lastProgressOffset = -1;
      _progressBaseOffset = chunks[i].baseOffset;
      _progressTextLength = chunks[i].text.length;
      _progressAudioDuration = _estimateMp3Duration(turn.audio);

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

    // Prefer real duration for position→char fallback when available.
    final known = _player.duration;
    if (known != null && known > Duration.zero) {
      _progressAudioDuration = known;
    }

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

  Future<_SynthTurn> _synthesizeOneTurn(String text) async {
    if (text.trim().isEmpty) {
      return _SynthTurn(Uint8List(0), const []);
    }
    final client = _ensureClient();
    final result = await client.synthesize(text, prosody: _prosody);
    return _SynthTurn(
      result.audioBytes,
      _timestampsFromMetadata(result.metadata),
    );
  }

  static List<WordTimestamp> _timestampsFromMetadata(
    List<EdgeTtsMetadataItem> metadata,
  ) {
    final out = <WordTimestamp>[];
    for (final item in metadata) {
      final type = item.type.toLowerCase();
      if (type != 'wordboundary' && !type.contains('word')) continue;
      final word = item.data.text?.text ?? '';
      if (word.isEmpty) continue;
      // Edge offsets are in 100-nanosecond units.
      out.add(
        WordTimestamp(
          word,
          Duration(microseconds: (item.data.offset / 10).round()),
          0,
        ),
      );
    }
    return out;
  }

  void _onPosition(Duration position) {
    if (_allTimestamps.isNotEmpty) {
      WordTimestamp? best;
      for (final ts in _allTimestamps) {
        if (ts.time <= position) best = ts;
      }
      if (best != null && best.charOffset != _lastProgressOffset) {
        _lastProgressOffset = best.charOffset;
        _onProgress?.call(best.charOffset);
      }
      return;
    }

    // No word boundaries — approximate from audio position.
    if (_progressAudioDuration <= Duration.zero || _progressTextLength <= 0) {
      return;
    }
    final t = (position.inMilliseconds / _progressAudioDuration.inMilliseconds)
        .clamp(0.0, 1.0);
    final offset =
        _progressBaseOffset + (t * _progressTextLength).floor();
    if (offset != _lastProgressOffset) {
      _lastProgressOffset = offset;
      _onProgress?.call(offset);
    }
  }

  /// Map Edge word timestamps onto character offsets in [text].
  ///
  /// Uses punctuation-stripped sequential matching so "Hello," in the chapter
  /// still aligns with Edge's "Hello" boundary events.
  static void _resolveCharOffsetsOnto(
    List<WordTimestamp> timestamps,
    String text,
    int baseOffset,
  ) {
    if (timestamps.isEmpty) return;

    final tokens = <({int start, String norm})>[];
    for (final m in RegExp(r'\S+').allMatches(text)) {
      final raw = m.group(0)!;
      final norm = _normalizeWord(raw);
      if (norm.isEmpty) continue;
      tokens.add((start: m.start, norm: norm));
    }
    if (tokens.isEmpty) {
      for (var i = 0; i < timestamps.length; i++) {
        timestamps[i] = WordTimestamp(
          timestamps[i].word,
          timestamps[i].time,
          baseOffset,
        );
      }
      return;
    }

    var tokenIndex = 0;
    for (var wi = 0; wi < timestamps.length; wi++) {
      final want = _normalizeWord(timestamps[wi].word);
      var found = -1;
      if (want.isNotEmpty) {
        for (var j = tokenIndex; j < tokens.length; j++) {
          final have = tokens[j].norm;
          if (have == want ||
              have.startsWith(want) ||
              want.startsWith(have)) {
            found = j;
            break;
          }
        }
      }
      if (found < 0) {
        // Keep monotonic progress even when a boundary word is missing.
        final approx = (wi * tokens.length / timestamps.length)
            .floor()
            .clamp(0, tokens.length - 1);
        found = approx < tokenIndex ? tokenIndex.clamp(0, tokens.length - 1) : approx;
      }
      timestamps[wi] = WordTimestamp(
        timestamps[wi].word,
        timestamps[wi].time,
        baseOffset + tokens[found].start,
      );
      tokenIndex = (found + 1).clamp(0, tokens.length);
    }
  }

  static String _normalizeWord(String word) {
    return word
        .toLowerCase()
        .replaceAll(RegExp(r"[^\p{L}\p{N}']+", unicode: true), '');
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
    _ensureClient();
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
    final client = _client;
    _client = null;
    if (client != null) {
      unawaited(client.close());
    }
  }

  List<_Chunk> _splitChunks(String text, int baseOffset) {
    final chunks = <_Chunk>[];
    // Non-empty paragraphs with offsets preserved in [text].
    for (final match in RegExp(r'(?:[^\n]|\n(?!\n))+').allMatches(text)) {
      final p = match.group(0)!;
      if (p.trim().isEmpty) continue;
      final paraStart = baseOffset + match.start;

      if (p.length <= 1500) {
        chunks.add(_Chunk(p, paraStart));
        continue;
      }

      // Long paragraph: pack sentences into ≤1500-char chunks.
      final buf = StringBuffer();
      var chunkStart = paraStart;
      var from = 0;
      while (from < p.length) {
        final end = _nextSentenceEnd(p, from);
        final sentence = p.substring(from, end).trim();
        if (sentence.isEmpty) {
          from = end;
          continue;
        }
        if (buf.isNotEmpty && buf.length + 1 + sentence.length > 1500) {
          chunks.add(_Chunk(buf.toString(), chunkStart));
          buf.clear();
        }
        if (buf.isEmpty) {
          chunkStart = paraStart + from;
        } else {
          buf.write(' ');
        }
        buf.write(sentence);
        from = end;
      }
      if (buf.isNotEmpty) {
        chunks.add(_Chunk(buf.toString(), chunkStart));
      }
    }
    return chunks;
  }

  /// Index after the next sentence ending at/after [from], or [text.length].
  static int _nextSentenceEnd(String text, int from) {
    final found = RegExp(r'[.!?]+(?:\s+|$)').firstMatch(text.substring(from));
    if (found == null) return text.length;
    return from + found.end;
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

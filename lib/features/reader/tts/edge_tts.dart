import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_edge_tts/flutter_edge_tts.dart';
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

/// Edge online TTS. Synthesis goes through [FlutterEdgeTts]; playback,
/// prefetch, chunking, and word→char progress stay in-engine.
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
  String _lastProgressWord = '';

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

  /// SSML relative rate (package passes this straight into `<prosody rate>`).
  String get _ratePercent {
    final p = (_rate - 1.0) * 100;
    return '${p >= 0 ? "+" : ""}${p.toStringAsFixed(1)}%';
  }

  /// SSML relative pitch (keeps prior Koma semantics: `_pitch` × 100 as %).
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

  Future<List<_SynthTurn>> _synthesizeTurns(List<String> texts) async {
    if (texts.isEmpty) return const [];
    final out = <_SynthTurn>[];
    for (final text in texts) {
      out.add(await _synthesizeOneTurn(text));
    }
    return out;
  }

  Future<_SynthTurn> _synthesizeOneTurn(String text) async {
    if (text.trim().isEmpty) {
      return _SynthTurn(Uint8List(0), const []);
    }
    final client = _ensureClient();
    final result = await client.synthesize(text, prosody: _prosody);
    return _SynthTurn(result.audioBytes, _timestampsFromMetadata(result.metadata));
  }

  static List<WordTimestamp> _timestampsFromMetadata(
    List<EdgeTtsMetadataItem> metadata,
  ) {
    final out = <WordTimestamp>[];
    for (final item in metadata) {
      if (item.type != 'WordBoundary') continue;
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
    var charsConsumed = 0;
    var tsIndex = 0;
    for (var i = 0; i < words.length && tsIndex < timestamps.length; i++) {
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
    final paragraphs = text.split(RegExp(r'\n\n+'));
    var offset = baseOffset;

    for (final p in paragraphs) {
      if (p.trim().isEmpty) {
        offset += p.length;
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

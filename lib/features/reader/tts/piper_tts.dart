import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/models/piper_voice.dart';
import '../../../core/services/piper_voice_service.dart';
import 'tts_engine.dart';

class PiperTtsEngine implements TtsEngine {
  final AudioPlayer _player = AudioPlayer();
  final PiperVoiceService _voiceService = PiperVoiceService.instance;

  List<TtsVoice> _voices = [];
  PiperVoice? _selectedPiperVoice;
  TtsVoice? _selectedVoice;

  bool _isPlaying = false;
  bool _isPaused = false;
  bool _isBuffering = false;
  int _speakGeneration = 0;

  double _speed = 1.0;
  double _lengthScale = 1.0;
  double _noiseScale = 0.667;
  double _noiseWScale = 0.8;

  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;
  void Function()? _onComplete;
  void Function(int)? _onProgress;
  Timer? _progressTimer;
  int _chunkCharStart = 0;
  int _chunkCharEnd = 0;

  @override
  List<TtsVoice> get voices => _voices;

  @override
  TtsVoice? get selectedVoice => _selectedVoice;

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get isPaused => _isPaused;

  @override
  bool get isBuffering => _isBuffering;

  @override
  Future<void> init() async {
    if (!PiperPlatform.isSupported) {
      _voices = [];
      return;
    }
    await _voiceService.ensureEspeakPath();
    final catalog = await _voiceService.listVoices();
    _voices = catalog
        .map(
          (v) => TtsVoice(
            id: v.id,
            name: v.displayName,
            locale: v.locale,
            isNeural: true,
            engineType: TtsEngineType.piper,
          ),
        )
        .toList();
    if (_selectedPiperVoice != null) {
      final still = catalog.where((v) => v.id == _selectedPiperVoice!.id);
      if (still.isEmpty) {
        _selectedPiperVoice = null;
        _selectedVoice = null;
      }
    }
    if (_selectedPiperVoice == null && catalog.isNotEmpty) {
      await _loadNativeVoice(catalog.first);
    }
  }

  Future<void> _loadNativeVoice(PiperVoice voice) async {
    final espeak = await _voiceService.ensureEspeakPath();
    final model = await _voiceService.resolveModelPath(voice);
    final config = await _voiceService.resolveConfigPath(voice);
    await PiperPlatform.loadVoice(
      modelPath: model,
      configPath: config,
      espeakPath: espeak,
    );
    _selectedPiperVoice = voice;
    _selectedVoice = TtsVoice(
      id: voice.id,
      name: voice.displayName,
      locale: voice.locale,
      isNeural: true,
      engineType: TtsEngineType.piper,
    );
  }

  @override
  Future<void> speak(
    String text, {
    int startOffset = 0,
    required void Function(int charOffset) onProgress,
    required void Function() onComplete,
  }) async {
    if (!PiperPlatform.isSupported) {
      onComplete();
      return;
    }
    _onProgress = onProgress;
    _onComplete = onComplete;
    _speakGeneration++;
    final gen = _speakGeneration;
    _player.stop();
    _cleanupSubscriptions();

    final remaining = text.substring(startOffset);
    if (remaining.trim().isEmpty) {
      onComplete();
      return;
    }

    final chunks = _splitChunks(remaining, startOffset);
    if (chunks.isEmpty) {
      onComplete();
      return;
    }

    _isBuffering = true;
    _isPlaying = false;
    _isPaused = false;

    try {
      await _speakChunks(chunks, gen);
    } catch (e) {
      debugPrint('piper-tts speak error: $e');
      if (gen == _speakGeneration) {
        _isPlaying = false;
        _isPaused = false;
        _isBuffering = false;
        onComplete();
      }
    }
  }

  Future<void> _speakChunks(List<_Chunk> chunks, int gen) async {
    for (final chunk in chunks) {
      if (gen != _speakGeneration) return;
      _isBuffering = true;
      _chunkCharStart = chunk.baseOffset;
      _chunkCharEnd = chunk.baseOffset + chunk.text.length;

      final wav = await PiperPlatform.synthesize(
        text: chunk.text,
        lengthScale: _lengthScale,
        noiseScale: _noiseScale,
        noiseWScale: _noiseWScale,
      );
      if (gen != _speakGeneration) return;

      await _playWav(wav, gen);
      if (gen != _speakGeneration) return;
    }

    if (gen == _speakGeneration) {
      _isPlaying = false;
      _isPaused = false;
      _isBuffering = false;
      _onComplete?.call();
    }
  }

  Future<void> _playWav(Uint8List wav, int gen) async {
    if (wav.isEmpty) return;

    await _player.setAudioSource(_WavBytesAudioSource(wav));
    if (gen != _speakGeneration) return;

    _stateSub?.cancel();
    _stateSub = _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _stopProgressTimer();
        if (gen == _speakGeneration) {
          _onProgress?.call(_chunkCharEnd);
        }
      }
    });

    _posSub?.cancel();
    _posSub = _player.positionStream.listen((pos) {
      _onDurationProgress(pos);
    });

    _isBuffering = false;
    _isPlaying = true;
    _isPaused = false;
    _startProgressTimer();
    await _player.play();
  }

  void _onDurationProgress(Duration pos) {
    final duration = _player.duration;
    if (duration == null || duration.inMilliseconds <= 0) return;
    final fraction = pos.inMilliseconds / duration.inMilliseconds;
    final charOffset =
        _chunkCharStart + (fraction * (_chunkCharEnd - _chunkCharStart)).round();
    _onProgress?.call(charOffset.clamp(_chunkCharStart, _chunkCharEnd));
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _onDurationProgress(_player.position);
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  @override
  void pause() {
    if (!_isPlaying || _isPaused) return;
    _player.pause();
    _isPaused = true;
    _isPlaying = false;
    _stopProgressTimer();
  }

  @override
  void resume() {
    if (!_isPaused) return;
    _player.play();
    _isPaused = false;
    _isPlaying = true;
    _startProgressTimer();
  }

  @override
  void stop() {
    _speakGeneration++;
    _player.stop();
    _cleanupSubscriptions();
    _isPlaying = false;
    _isPaused = false;
    _isBuffering = false;
    _stopProgressTimer();
  }

  @override
  Future<void> setVoice(TtsVoice voice) async {
    final catalog = await _voiceService.listVoices();
    PiperVoice? match;
    for (final v in catalog) {
      if (v.id == voice.id) {
        match = v;
        break;
      }
    }
    if (match == null) return;
    await _loadNativeVoice(match);
  }

  @override
  void setRate(double rate) {
    _speed = rate.clamp(0.25, 2.0);
    _lengthScale = 1.0 / _speed;
  }

  @override
  void setPitch(double pitch) {
    // Piper has no pitch control; map slightly to noise variation.
    final normalized = ((pitch + 0.5) / 2.5).clamp(0.25, 1.0);
    _noiseScale = 0.333 + normalized * 0.5;
    _noiseWScale = 0.333 + normalized * 0.5;
  }

  @override
  void dispose() {
    stop();
    _player.dispose();
    if (PiperPlatform.isSupported) {
      unawaited(PiperPlatform.freeVoice());
    }
  }

  void _cleanupSubscriptions() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _posSub = null;
    _stateSub = null;
  }

  List<_Chunk> _splitChunks(String text, int baseOffset) {
    final chunks = <_Chunk>[];
    if (text.length <= 800) {
      chunks.add(_Chunk(text, baseOffset));
      return chunks;
    }
    final paragraphs = text.split(RegExp(r'\n\n+'));
    int offset = baseOffset;
    for (final p in paragraphs) {
      if (p.trim().isEmpty) {
        offset += p.length;
        continue;
      }
      if (p.length <= 800) {
        chunks.add(_Chunk(p, offset));
        offset += p.length;
      } else {
        final sentences = p.split(RegExp(r'(?<=[.!?])\s+'));
        final buf = StringBuffer();
        var chunkStart = offset;
        for (final s in sentences) {
          if (s.isEmpty) continue;
          if (buf.length + s.length > 800 && buf.isNotEmpty) {
            chunks.add(_Chunk(buf.toString(), chunkStart));
            chunkStart += buf.length;
            buf.clear();
          }
          buf.write(s);
          buf.write(' ');
        }
        if (buf.isNotEmpty) {
          chunks.add(_Chunk(buf.toString().trim(), chunkStart));
        }
        offset += p.length;
      }
    }
    return chunks;
  }
}

class _Chunk {
  final String text;
  final int baseOffset;
  const _Chunk(this.text, this.baseOffset);
}

class _WavBytesAudioSource extends StreamAudioSource {
  final Uint8List _bytes;
  _WavBytesAudioSource(this._bytes) : super(tag: 'piper_wav');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}

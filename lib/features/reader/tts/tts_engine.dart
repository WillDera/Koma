import 'dart:typed_data';

enum TtsEngineType { device, googleCloud, edge }

class TtsVoice {
  final String id;
  final String name;
  final String? gender;
  final bool isNeural;
  final String? locale;
  final TtsEngineType engineType;

  const TtsVoice({
    required this.id,
    required this.name,
    this.gender,
    this.isNeural = false,
    this.locale,
    this.engineType = TtsEngineType.googleCloud,
  });

  String get displayName {
    final buf = StringBuffer(name);
    if (gender != null) buf.write(' · $gender');
    if (isNeural) buf.write(' · Neural');
    return buf.toString();
  }
}

class WordTimestamp {
  final String word;
  final Duration time;
  final int charOffset;

  const WordTimestamp(this.word, this.time, this.charOffset);
}

class TtsChunk {
  final Uint8List audioBytes;
  final List<WordTimestamp> timestamps;

  const TtsChunk(this.audioBytes, this.timestamps);
}

abstract class TtsEngine {
  List<TtsVoice> get voices;
  TtsVoice? get selectedVoice;
  bool get isPlaying;
  bool get isPaused;
  bool get isBuffering => false;

  Future<void> init();
  Future<void> speak(
    String text, {
    int startOffset = 0,
    required void Function(int charOffset) onProgress,
    required void Function() onComplete,
  });
  void pause();
  void resume();
  void stop();
  Future<void> setVoice(TtsVoice voice);
  void setRate(double rate);
  void setPitch(double pitch);
  void dispose();
}

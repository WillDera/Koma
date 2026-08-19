import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'app_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/piper_voice.dart';

/// Native Piper bridge (Android only).
class PiperPlatform {
  PiperPlatform._();
  static const _channel = MethodChannel('com.koma.koma/piper');

  static bool get isSupported =>
      !kIsWeb && Platform.isAndroid;

  static Future<String> initEspeak() async {
    final path = await _channel.invokeMethod<String>('initEspeak');
    if (path == null || path.isEmpty) {
      throw StateError('initEspeak returned empty path');
    }
    return path;
  }

  static Future<void> loadVoice({
    required String modelPath,
    required String configPath,
    required String espeakPath,
  }) async {
    await _channel.invokeMethod<void>('loadVoice', {
      'modelPath': modelPath,
      'configPath': configPath,
      'espeakPath': espeakPath,
    });
  }

  static Future<void> freeVoice() async {
    await _channel.invokeMethod<void>('freeVoice');
  }

  static Future<Uint8List> synthesize({
    required String text,
    double lengthScale = 1.0,
    double noiseScale = 0.667,
    double noiseWScale = 0.8,
    int speakerId = 0,
  }) async {
    final bytes = await _channel.invokeMethod<Uint8List>('synthesize', {
      'text': text,
      'lengthScale': lengthScale,
      'noiseScale': noiseScale,
      'noiseWScale': noiseWScale,
      'speakerId': speakerId,
    });
    if (bytes == null || bytes.isEmpty) {
      throw StateError('synthesis returned empty audio');
    }
    return bytes;
  }

  static Future<String> version() async {
    return await _channel.invokeMethod<String>('version') ?? 'unknown';
  }
}

/// Stores user-imported Piper voice models on disk.
class PiperVoiceService {
  PiperVoiceService._();
  static final PiperVoiceService instance = PiperVoiceService._();

  static const _manifestName = 'voices.json';
  static const _uuid = Uuid();

  String? _espeakPath;

  Future<Directory> _voicesRoot() async {
    final docs = await AppStorage.documents();
    final dir = Directory(p.join(docs.path, 'piper_voices'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _manifestFile() async {
    final root = await _voicesRoot();
    return File(p.join(root.path, _manifestName));
  }

  Future<String> ensureEspeakPath() async {
    if (_espeakPath != null) return _espeakPath!;
    if (!PiperPlatform.isSupported) {
      throw UnsupportedError('Piper is only available on Android');
    }
    _espeakPath = await PiperPlatform.initEspeak();
    return _espeakPath!;
  }

  Future<List<PiperVoice>> listVoices() async {
    final file = await _manifestFile();
    if (!file.existsSync()) return [];
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final raw = json['voices'] as List<dynamic>? ?? [];
      return raw
          .map((e) => PiperVoice.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((v) => v.id.isNotEmpty && v.onnxFile.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeManifest(List<PiperVoice> voices) async {
    final file = await _manifestFile();
    await file.writeAsString(
      jsonEncode({'voices': voices.map((v) => v.toJson()).toList()}),
    );
  }

  Future<String> resolveModelPath(PiperVoice voice) async {
    final root = await _voicesRoot();
    return p.join(root.path, voice.id, voice.onnxFile);
  }

  Future<String> resolveConfigPath(PiperVoice voice) async {
    final root = await _voicesRoot();
    return p.join(root.path, voice.id, voice.configFile);
  }

  /// Import `.onnx` plus matching `.onnx.json` (or explicit json pick).
  Future<PiperVoice?> importFiles(List<File> sources) async {
    File? onnx;
    File? json;
    for (final f in sources) {
      final ext = p.extension(f.path).toLowerCase();
      if (ext == '.onnx') onnx = f;
      if (ext == '.json') json = f;
    }
    if (onnx == null || !onnx.existsSync()) return null;

    final config = json ?? File('${onnx.path}.json');
    if (!config.existsSync()) return null;

    final id = _uuid.v4();
    final root = await _voicesRoot();
    final voiceDir = Directory(p.join(root.path, id));
    await voiceDir.create(recursive: true);

    final onnxName = p.basename(onnx.path);
    final configName = p.basename(config.path);
    await onnx.copy(p.join(voiceDir.path, onnxName));
    await config.copy(p.join(voiceDir.path, configName));

    String? locale;
    try {
      final cfgJson =
          jsonDecode(await File(p.join(voiceDir.path, configName)).readAsString())
              as Map<String, dynamic>;
      final lang = cfgJson['language'] as Map<String, dynamic>?;
      locale = lang?['code_1'] as String? ?? lang?['family'] as String?;
    } catch (_) {}

    final displayName = _displayNameFromOnnx(onnxName);
    final voice = PiperVoice(
      id: id,
      displayName: displayName,
      onnxFile: onnxName,
      configFile: configName,
      locale: locale,
    );

    final catalog = await listVoices();
    catalog.add(voice);
    await _writeManifest(catalog);

  // Optional smoke test — voice loads in native runtime.
    try {
      final espeak = await ensureEspeakPath();
      await PiperPlatform.loadVoice(
        modelPath: p.join(voiceDir.path, onnxName),
        configPath: p.join(voiceDir.path, configName),
        espeakPath: espeak,
      );
      await PiperPlatform.freeVoice();
    } catch (e) {
      debugPrint('Piper voice validation failed: $e');
      await voiceDir.delete(recursive: true);
      catalog.removeWhere((v) => v.id == id);
      await _writeManifest(catalog);
      return null;
    }

    return voice;
  }

  Future<void> deleteVoice(String id) async {
    final catalog = await listVoices();
    final root = await _voicesRoot();
    final voiceDir = Directory(p.join(root.path, id));
    if (voiceDir.existsSync()) {
      await voiceDir.delete(recursive: true);
    }
    catalog.removeWhere((v) => v.id == id);
    await _writeManifest(catalog);
  }

  static String _displayNameFromOnnx(String onnxName) {
    var name = p.basenameWithoutExtension(onnxName);
    if (name.endsWith('.onnx')) {
      name = p.basenameWithoutExtension(name);
    }
    name = name.replaceAll(RegExp(r'[-_]+'), ' ').trim();
    return name.isEmpty ? 'Piper voice' : name;
  }
}

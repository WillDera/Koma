import 'dart:convert';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'bridges/utils_bridge.dart';
import 'bridges/m_provider_bridge.dart';

class JsRuntime {
  QuickJsRuntime2? _engine;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    _engine = QuickJsRuntime2();
    await _injectBridges();
    _initialized = true;
  }

  Future<void> _injectBridges() async {
    await injectAllBridges(_engine!);
    await injectMProvider(_engine!);
  }

  dynamic evaluate(String code) {
    if (_engine == null) return null;
    final result = _engine!.evaluate(code);
    if (result.isError) {
      throw JSError(result.stringResult);
    }
    return result.rawResult;
  }

  String? evaluateString(String code) {
    if (_engine == null) return null;
    final result = _engine!.evaluate(code);
    if (result.isError) return null;
    return result.stringResult;
  }

  Future<dynamic> evaluateJson(String code) async {
    final result = evaluate(code);
    if (result == null) return null;
    if (result is String && result.isNotEmpty) {
      try {
        return jsonDecode(result);
      } catch (_) {
        return result;
      }
    }
    return result;
  }

  void injectCode(String code) {
    evaluate(code);
  }

  List<Map<String, dynamic>> evaluateMangaList(
    String sourceCode,
    String functionCall,
  ) {
    final wrapped = '''
$sourceCode
var __result = $functionCall;
JSON.stringify(__result);
''';

    final result = evaluateString(wrapped);
    if (result == null || result.isEmpty) return [];

    try {
      final decoded = jsonDecode(result);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      if (decoded is Map && decoded.containsKey('mangas')) {
        return (decoded['mangas'] as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  Map<String, dynamic>? evaluateDetail(
    String sourceCode,
    String functionCall,
  ) {
    final wrapped = '''
$sourceCode
var __result = $functionCall;
JSON.stringify(__result);
''';

    final result = evaluateString(wrapped);
    if (result == null || result.isEmpty) return null;
    try {
      return jsonDecode(result) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  List<dynamic> evaluateList(
    String sourceCode,
    String functionCall,
  ) {
    final wrapped = '''
$sourceCode
var __result = $functionCall;
JSON.stringify(__result);
''';

    final result = evaluateString(wrapped);
    if (result == null || result.isEmpty) return [];
    try {
      final decoded = jsonDecode(result);
      if (decoded is List) return decoded;
    } catch (_) {}
    return [];
  }

  void dispose() {
    _engine?.dispose();
    _engine = null;
    _initialized = false;
  }
}

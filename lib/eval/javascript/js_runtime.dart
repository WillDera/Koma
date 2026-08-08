import 'dart:convert';

import 'package:flutter_qjs/flutter_qjs.dart';

import 'bridges/utils_bridge.dart';
import 'bridges/m_provider_bridge.dart';

class JsRuntime {
  QuickJsRuntime2? _engine;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  QuickJsRuntime2? get engine => _engine;

  Future<void> init() async {
    if (_initialized) return;
    _engine = QuickJsRuntime2(stackSize: 1024 * 1024 * 4);
    _engine!.enableHandlePromises();
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

  JsEvalResult evaluateRaw(String code) {
    final engine = _engine;
    if (engine == null) {
      throw StateError('JsRuntime not initialized');
    }
    return engine.evaluate(code);
  }

  Future<JsEvalResult> evaluateAsync(String code) async {
    final engine = _engine;
    if (engine == null) {
      throw StateError('JsRuntime not initialized');
    }
    return engine.evaluateAsync(code);
  }

  Future<JsEvalResult> handlePromise(JsEvalResult value) async {
    final engine = _engine;
    if (engine == null) {
      throw StateError('JsRuntime not initialized');
    }
    return engine.handlePromise(value);
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

  void dispose() {
    _engine?.dispose();
    _engine = null;
    _initialized = false;
  }
}

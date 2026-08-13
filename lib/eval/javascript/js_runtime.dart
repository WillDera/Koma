import 'package:flutter_qjs/flutter_qjs.dart';

/// Thin re-export / legacy helper. Prefer [getJavascriptRuntime] in
/// [JsExtensionService] (mangayomi pattern).
class JsRuntime {
  JavascriptRuntime? _engine;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  JavascriptRuntime? get engine => _engine;

  Future<void> init() async {
    if (_initialized) return;
    _engine = getJavascriptRuntime();
    _initialized = true;
  }

  void dispose() {
    try {
      _engine?.dispose();
    } catch (_) {}
    _engine = null;
    _initialized = false;
  }
}

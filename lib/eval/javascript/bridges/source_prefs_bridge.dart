import 'dart:convert';
import 'dart:async';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:shared_preferences/shared_preferences.dart';

const sourcePrefsBridgeCode = '''
var __sourcePrefsCallbacks = {};
var __sourcePrefsCallbackId = 0;

globalThis.SourcePreferences = {
  getInstance: function(sourceId) {
    var id = __sourcePrefsCallbackId++;
    return new Promise(function(resolve, reject) {
      __sourcePrefsCallbacks[id] = { resolve: resolve, reject: reject };
      sendMessage('SourcePrefsGetInstance', JSON.stringify({ sourceId: sourceId, callbackId: id }));
    });
  }
};

function _sourcePrefsWrap(prefs) {
  return {
    getString: function(key) {
      var id = __sourcePrefsCallbackId++;
      return new Promise(function(resolve, reject) {
        __sourcePrefsCallbacks[id] = { resolve: resolve, reject: reject };
        sendMessage('SourcePrefsGetString', JSON.stringify({ key: key, callbackId: id }));
      });
    },
    putString: function(key, value) {
      var id = __sourcePrefsCallbackId++;
      return new Promise(function(resolve, reject) {
        __sourcePrefsCallbacks[id] = { resolve: resolve, reject: reject };
        sendMessage('SourcePrefsPutString', JSON.stringify({ key: key, value: value, callbackId: id }));
      });
    },
    remove: function(key) {
      var id = __sourcePrefsCallbackId++;
      return new Promise(function(resolve, reject) {
        __sourcePrefsCallbacks[id] = { resolve: resolve, reject: reject };
        sendMessage('SourcePrefsRemove', JSON.stringify({ key: key, callbackId: id }));
      });
    }
  };
}
''';

Future<void> injectSourcePrefsBridge(QuickJsRuntime2 engine) async {
  engine.setupBridge('SourcePrefsGetInstance', (args) {
    final sourceId = args['sourceId'] as String? ?? '';
    final callbackId = args['callbackId'] as int? ?? 0;
    unawaited(_sourcePrefsGetInstance(engine, sourceId, callbackId));
  });

  engine.setupBridge('SourcePrefsGetString', (args) {
    final key = args['key'] as String? ?? '';
    final callbackId = args['callbackId'] as int? ?? 0;
    unawaited(_sourcePrefsGetString(engine, key, callbackId));
  });

  engine.setupBridge('SourcePrefsPutString', (args) {
    final key = args['key'] as String? ?? '';
    final value = args['value'] as String? ?? '';
    final callbackId = args['callbackId'] as int? ?? 0;
    unawaited(_sourcePrefsPutString(engine, key, value, callbackId));
  });

  engine.setupBridge('SourcePrefsRemove', (args) {
    final key = args['key'] as String? ?? '';
    final callbackId = args['callbackId'] as int? ?? 0;
    unawaited(_sourcePrefsRemove(engine, key, callbackId));
  });

  engine.evaluate(sourcePrefsBridgeCode);
}

Future<void> _sourcePrefsGetInstance(QuickJsRuntime2 engine, String sourceId, int callbackId) async {
  final prefs = await SharedPreferences.getInstance();
  final sourceKey = 'source_prefs_$sourceId';
  final map = <String, String>{};
  final raw = prefs.getString(sourceKey);
  if (raw != null) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final e in decoded.entries) {
        map[e.key] = e.value as String;
      }
    } catch (_) {}
  }
  engine.evaluate('__sourcePrefsCallbacks[$callbackId].resolve(_sourcePrefsWrap(${jsonEncode(map)}))');
}

Future<void> _sourcePrefsGetString(QuickJsRuntime2 engine, String key, int callbackId) async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString('source_prefs_$key');
  final result = jsonEncode(value);
  engine.evaluate('__sourcePrefsCallbacks[$callbackId].resolve($result)');
}

Future<void> _sourcePrefsPutString(QuickJsRuntime2 engine, String key, String value, int callbackId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('source_prefs_$key', value);
  engine.evaluate('__sourcePrefsCallbacks[$callbackId].resolve(null)');
}

Future<void> _sourcePrefsRemove(QuickJsRuntime2 engine, String key, int callbackId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('source_prefs_$key');
  engine.evaluate('__sourcePrefsCallbacks[$callbackId].resolve(null)');
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:shared_preferences/shared_preferences.dart';

const prefsBridgeCode = '''
var __prefsCallbacks = {};
var __prefsCallbackId = 0;

globalThis.SharedPreferences = {
  getInstance: function() {
    var id = __prefsCallbackId++;
    return new Promise(function(resolve, reject) {
      __prefsCallbacks[id] = { resolve: resolve, reject: reject };
      sendMessage('PrefsGetInstance', JSON.stringify({ callbackId: id }));
    });
  }
};

function _prefsWrap(prefs) {
  return {
    getString: function(key) {
      var id = __prefsCallbackId++;
      return new Promise(function(resolve, reject) {
        __prefsCallbacks[id] = { resolve: resolve, reject: reject };
        sendMessage('PrefsGetString', JSON.stringify({ key: key, callbackId: id }));
      });
    },
    putString: function(key, value) {
      var id = __prefsCallbackId++;
      return new Promise(function(resolve, reject) {
        __prefsCallbacks[id] = { resolve: resolve, reject: reject };
        sendMessage('PrefsPutString', JSON.stringify({ key: key, value: value, callbackId: id }));
      });
    },
    remove: function(key) {
      var id = __prefsCallbackId++;
      return new Promise(function(resolve, reject) {
        __prefsCallbacks[id] = { resolve: resolve, reject: reject };
        sendMessage('PrefsRemove', JSON.stringify({ key: key, callbackId: id }));
      });
    }
  };
}
''';

Future<void> injectPrefsBridge(QuickJsRuntime2 engine) async {
  engine.setupBridge('PrefsGetInstance', (args) {
    final callbackId = args['callbackId'] as int? ?? 0;
    unawaited(_prefsGetInstance(engine, callbackId));
  });

  engine.setupBridge('PrefsGetString', (args) {
    final key = args['key'] as String? ?? '';
    final callbackId = args['callbackId'] as int? ?? 0;
    unawaited(_prefsGetString(engine, key, callbackId));
  });

  engine.setupBridge('PrefsPutString', (args) {
    final key = args['key'] as String? ?? '';
    final value = args['value'] as String? ?? '';
    final callbackId = args['callbackId'] as int? ?? 0;
    unawaited(_prefsPutString(engine, key, value, callbackId));
  });

  engine.setupBridge('PrefsRemove', (args) {
    final key = args['key'] as String? ?? '';
    final callbackId = args['callbackId'] as int? ?? 0;
    unawaited(_prefsRemove(engine, key, callbackId));
  });

  engine.evaluate(prefsBridgeCode);
}

Future<void> _prefsGetInstance(QuickJsRuntime2 engine, int callbackId) async {
  engine.evaluate('__prefsCallbacks[$callbackId].resolve(__prefsWrap({}))');
}

Future<void> _prefsGetString(
  QuickJsRuntime2 engine,
  String key,
  int callbackId,
) async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString(key);
  final result = jsonEncode(value);
  engine.evaluate('__prefsCallbacks[$callbackId].resolve($result)');
}

Future<void> _prefsPutString(
  QuickJsRuntime2 engine,
  String key,
  String value,
  int callbackId,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, value);
  engine.evaluate('__prefsCallbacks[$callbackId].resolve(null)');
}

Future<void> _prefsRemove(
  QuickJsRuntime2 engine,
  String key,
  int callbackId,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(key);
  engine.evaluate('__prefsCallbacks[$callbackId].resolve(null)');
}

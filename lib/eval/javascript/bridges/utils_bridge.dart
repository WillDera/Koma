import 'dart:convert';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'http_bridge.dart';
import 'dom_bridge.dart';
import 'prefs_bridge.dart';
import 'crypto_bridge.dart';
import 'source_prefs_bridge.dart';

final utilsBridgeCode = '''
globalThis.console = {
  log: function() {
    var args = Array.prototype.slice.call(arguments);
    sendMessage('ConsoleLog', JSON.stringify({ level: "log", args: args }));
  },
  warn: function() {
    var args = Array.prototype.slice.call(arguments);
    sendMessage('ConsoleLog', JSON.stringify({ level: "warn", args: args }));
  },
  error: function() {
    var args = Array.prototype.slice.call(arguments);
    sendMessage('ConsoleLog', JSON.stringify({ level: "error", args: args }));
  }
};

String.prototype.startsWith = function(search) {
  return this.indexOf(search) === 0;
};

String.prototype.endsWith = function(search) {
  return this.length >= search.length && this.substring(this.length - search.length) === search;
};

String.prototype.includes = function(search) {
  return this.indexOf(search) !== -1;
};

String.prototype.trim = function() {
  return this.replace(/^\\s+|\\s+\$/g, "");
};

String.prototype.substringAfter = function(pattern) {
  var startIndex = this.indexOf(pattern);
  if (startIndex === -1) return this.substring(0);
  return this.substring(startIndex + pattern.length);
};

String.prototype.substringAfterLast = function(pattern) {
  return this.split(pattern).pop();
};

String.prototype.substringBefore = function(pattern) {
  var endIndex = this.indexOf(pattern);
  if (endIndex === -1) return this.substring(0);
  return this.substring(0, endIndex);
};

String.prototype.substringBeforeLast = function(pattern) {
  var endIndex = this.lastIndexOf(pattern);
  if (endIndex === -1) return this.substring(0);
  return this.substring(0, endIndex);
};

String.prototype.substringBetween = function(left, right) {
  var index = this.indexOf(left);
  if (index === -1) return "";
  var leftIndex = index + left.length;
  var rightIndex = this.indexOf(right, leftIndex);
  if (rightIndex === -1) return "";
  return this.substring(leftIndex, rightIndex);
};

var __base64Callbacks = {};
var __base64CallbackId = 0;

if (!globalThis.btoa) {
  globalThis.btoa = function(str) {
    var id = __base64CallbackId++;
    return new Promise(function(resolve, reject) {
      __base64Callbacks[id] = { resolve: resolve, reject: reject };
      sendMessage('Base64Encode', JSON.stringify({ str: str, callbackId: id }));
    });
  };
}

if (!globalThis.atob) {
  globalThis.atob = function(str) {
    var id = __base64CallbackId++;
    return new Promise(function(resolve, reject) {
      __base64Callbacks[id] = { resolve: resolve, reject: reject };
      sendMessage('Base64Decode', JSON.stringify({ str: str, callbackId: id }));
    });
  };
}
''';

Future<void> injectUtilsBridge(QuickJsRuntime2 engine) async {
  engine.setupBridge('ConsoleLog', (args) {
    // ignore log output in production
  });

  engine.setupBridge('Base64Encode', (args) {
    final str = args['str'] as String? ?? '';
    final callbackId = args['callbackId'] as int? ?? 0;
    final result = base64Encode(utf8.encode(str));
    engine.evaluate('__base64Callbacks[$callbackId].resolve("$result")');
  });

  engine.setupBridge('Base64Decode', (args) {
    final str = args['str'] as String? ?? '';
    final callbackId = args['callbackId'] as int? ?? 0;
    final result = utf8.decode(base64Decode(str));
    final escaped = result.replaceAll('"', '\\"').replaceAll('\n', '\\n');
    engine.evaluate('__base64Callbacks[$callbackId].resolve("$escaped")');
  });

  engine.evaluate(utilsBridgeCode);
}

Future<void> injectAllBridges(QuickJsRuntime2 engine) async {
  injectUtilsBridge(engine);
  injectHttpBridge(engine);
  injectDomBridge(engine);
  injectPrefsBridge(engine);
  injectCryptoBridge(engine);
  injectSourcePrefsBridge(engine);
}

import 'dart:convert';

import 'package:flutter_qjs/flutter_qjs.dart';

/// Light utilities. Do **not** redefine `console` — QuickJsRuntime2.init()
/// already registered ConsoleLog with List-args; overwriting console to send
/// Maps crashed the channel mid-getPopular (silent hang).
Future<void> injectUtilsBridge(JavascriptRuntime runtime) async {
  runtime.onMessage('btoa', (dynamic args) {
    final list = args is List ? args : <dynamic>[];
    final str = list.isNotEmpty ? list[0].toString() : '';
    return base64Encode(utf8.encode(str));
  });
  runtime.onMessage('atob', (dynamic args) {
    final list = args is List ? args : <dynamic>[];
    final str = list.isNotEmpty ? list[0].toString() : '';
    return utf8.decode(base64Decode(str));
  });

  runtime.evaluate(r'''
if (typeof btoa !== 'function') {
  function btoa(str) {
    return sendMessage('btoa', JSON.stringify([str]));
  }
  globalThis.btoa = btoa;
}
if (typeof atob !== 'function') {
  function atob(str) {
    return sendMessage('atob', JSON.stringify([str]));
  }
  globalThis.atob = atob;
}

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
''');
}

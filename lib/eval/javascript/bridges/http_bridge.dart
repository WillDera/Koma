import 'dart:async';
import 'dart:convert';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:http/http.dart' as http;

const httpBridgeCode = '''
var __httpCallbacks = {};
var __httpCallbackId = 0;

globalThis.MClient = {
  init: function() {
    return {
      fetch: function(url, options) {
        var id = __httpCallbackId++;
        return new Promise(function(resolve, reject) {
          __httpCallbacks[id] = { resolve: resolve, reject: reject };
          sendMessage('HttpFetch', JSON.stringify({
            url: url,
            options: options || {},
            callbackId: id
          }));
        });
      },
      close: function() {}
    };
  }
};
''';

Future<void> injectHttpBridge(QuickJsRuntime2 engine) async {
  engine.setupBridge('HttpFetch', (args) {
    final url = args['url'] as String? ?? '';
    final callbackId = args['callbackId'] as int? ?? 0;
    final options = args['options'] as Map? ?? {};
    final headers = Map<String, String>.from(
        (options['headers'] as Map?)?.cast<String, String>() ?? {});
    final method = (options['method'] as String? ?? 'GET').toUpperCase();
    final body = options['body'] as String?;

    unawaited(_doHttpFetch(engine, url, method, headers, body, callbackId));
  });

  engine.evaluate(httpBridgeCode);
}

Future<void> _doHttpFetch(
  QuickJsRuntime2 engine,
  String url,
  String method,
  Map<String, String> headers,
  String? body,
  int callbackId,
) async {
  try {
    http.Response response;
    final client = http.Client();
    try {
      final uri = Uri.parse(url);
      switch (method) {
        case 'POST':
          response = await client.post(uri, headers: headers, body: body);
          break;
        case 'PUT':
          response = await client.put(uri, headers: headers, body: body);
          break;
        case 'PATCH':
          response = await client.patch(uri, headers: headers, body: body);
          break;
        case 'DELETE':
          response = await client.delete(uri, headers: headers);
          break;
        case 'HEAD':
          response = await client.head(uri, headers: headers);
          break;
        default:
          response = await client.get(uri, headers: headers);
      }
    } finally {
      client.close();
    }

    final result = jsonEncode({
      'status': response.statusCode,
      'headers': response.headers,
      'body': response.body,
    });

    engine.evaluate('__httpCallbacks[$callbackId].resolve($result)');
  } catch (e) {
    final errMsg = e.toString().replaceAll('"', '\\"').replaceAll("'", "\\'");
    engine.evaluate('__httpCallbacks[$callbackId].reject("$errMsg")');
  }
}

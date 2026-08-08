import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:http/http.dart' as http;
import 'package:http_interceptor/http_interceptor.dart';

import '../../../../core/services/http/m_client.dart';

/// Legacy JS-facing MClient.init().fetch callback bridge (status field).
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

/// Mangayomi-compatible Client used by DefaultExtension sources
/// (`new Client().get(url)` → `{body, statusCode, headers}`).
const mangayomiClientCode = '''
class Client {
    constructor(reqcopyWith) {
        this.reqcopyWith = reqcopyWith;
    }
    async head(url, headers) {
        const result = await sendMessage(
            "http_head",
            JSON.stringify([null, this.reqcopyWith, url, headers])
        );
        return JSON.parse(result);
    }
    async get(url, headers) {
        const result = await sendMessage(
            "http_get",
            JSON.stringify([null, this.reqcopyWith, url, headers])
        );
        return JSON.parse(result);
    }
    async post(url, headers, body) {
        const result = await sendMessage(
            "http_post",
            JSON.stringify([null, this.reqcopyWith, url, headers, body])
        );
        return JSON.parse(result);
    }
    async put(url, headers, body) {
        const result = await sendMessage(
            "http_put",
            JSON.stringify([null, this.reqcopyWith, url, headers, body])
        );
        return JSON.parse(result);
    }
    async delete(url, headers, body) {
        const result = await sendMessage(
            "http_delete",
            JSON.stringify([null, this.reqcopyWith, url, headers, body])
        );
        return JSON.parse(result);
    }
    async patch(url, headers, body) {
        const result = await sendMessage(
            "http_patch",
            JSON.stringify([null, this.reqcopyWith, url, headers, body])
        );
        return JSON.parse(result);
    }
}
''';

Future<void> injectHttpBridge(QuickJsRuntime2 engine) async {
  engine.setupBridge('HttpFetch', (args) {
    final url = args['url'] as String? ?? '';
    final callbackId = args['callbackId'] as int? ?? 0;
    final options = args['options'] as Map? ?? {};
    final headers = Map<String, String>.from(
      (options['headers'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          {},
    );
    final method = (options['method'] as String? ?? 'GET').toUpperCase();
    final body = options['body'] as String?;

    unawaited(_doHttpFetch(engine, url, method, headers, body, callbackId));
  });

  engine.onMessage('http_head', (dynamic args) async {
    return await _toHttpResponse(_client(args), 'HEAD', args as List);
  });
  engine.onMessage('http_get', (dynamic args) async {
    return await _toHttpResponse(_client(args), 'GET', args as List);
  });
  engine.onMessage('http_post', (dynamic args) async {
    return await _toHttpResponse(_client(args), 'POST', args as List);
  });
  engine.onMessage('http_put', (dynamic args) async {
    return await _toHttpResponse(_client(args), 'PUT', args as List);
  });
  engine.onMessage('http_delete', (dynamic args) async {
    return await _toHttpResponse(_client(args), 'DELETE', args as List);
  });
  engine.onMessage('http_patch', (dynamic args) async {
    return await _toHttpResponse(_client(args), 'PATCH', args as List);
  });

  engine.evaluate(httpBridgeCode);
  engine.evaluate(mangayomiClientCode);
}

InterceptedClient _client(dynamic args) {
  final list = args is List ? args : <dynamic>[];
  final reqcopyWith = list.length > 1 ? list[1] as Map? : null;
  return MClient.init(
    reqcopyWith: reqcopyWith?.map((k, v) => MapEntry(k.toString(), v)),
  );
}

Future<String> _toHttpResponse(
  InterceptedClient client,
  String method,
  List args,
) async {
  final url = args[2] as String;
  final headers = (args[3] as Map?)?.map(
    (k, v) => MapEntry(k.toString(), v.toString()),
  );
  final body = args.length >= 5
      ? args[4] is List
            ? args[4] as List
            : args[4] is String
            ? args[4] as String
            : (args[4] as Map?)?.map((k, v) => MapEntry(k.toString(), v))
      : null;

  if ((headers?[HttpHeaders.contentTypeHeader]?.contains('application/json') ??
      false)) {
    final request = http.Request(method, Uri.parse(url));
    request.headers.addAll(headers ?? {});
    request.body = json.encode(body);
    final streamed = await client.send(request);
    final bodyStr = await streamed.stream.bytesToString();
    return jsonEncode({
      'body': bodyStr,
      'headers': streamed.headers,
      'isRedirect': streamed.isRedirect,
      'persistentConnection': streamed.persistentConnection,
      'reasonPhrase': streamed.reasonPhrase,
      'statusCode': streamed.statusCode,
      'request': {
        'method': streamed.request?.method,
        'url': streamed.request?.url.toString(),
      },
    });
  }

  final future = switch (method) {
    'HEAD' => client.head(Uri.parse(url), headers: headers),
    'GET' => client.get(Uri.parse(url), headers: headers),
    'POST' => client.post(Uri.parse(url), headers: headers, body: body),
    'PUT' => client.put(Uri.parse(url), headers: headers, body: body),
    'DELETE' => client.delete(Uri.parse(url), headers: headers, body: body),
    _ => client.patch(Uri.parse(url), headers: headers, body: body),
  };
  final response = await future;
  return jsonEncode({
    'body': response.body,
    'headers': response.headers,
    'isRedirect': response.isRedirect,
    'persistentConnection': response.persistentConnection,
    'reasonPhrase': response.reasonPhrase,
    'statusCode': response.statusCode,
    'request': {
      'method': response.request?.method,
      'url': response.request?.url.toString(),
    },
  });
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
    final client = MClient.init();
    http.Response response;
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

    final result = jsonEncode({
      'status': response.statusCode,
      'statusCode': response.statusCode,
      'headers': response.headers,
      'body': response.body,
    });

    engine.evaluate('__httpCallbacks[$callbackId].resolve($result)');
  } catch (e) {
    final errMsg = e.toString().replaceAll('"', '\\"').replaceAll("'", "\\'");
    engine.evaluate('__httpCallbacks[$callbackId].reject("$errMsg")');
  }
}

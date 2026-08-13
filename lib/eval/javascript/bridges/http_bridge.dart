import 'dart:convert';
import 'dart:io';

import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:http/http.dart' as http;
import 'package:http_interceptor/http_interceptor.dart';

import '../../../../core/services/http/m_client.dart';

/// Mangayomi-faithful `Client` used by DefaultExtension sources
/// (`new Client().get(url)` → `{body, statusCode, headers}`).
///
/// Must use `sendMessage` / `onMessage` (mangayomi `eval/javascript/http.dart`).
/// Bridging through MClient.fetch + `evaluate(resolve(...))` hangs getPopular
/// for large HTML bodies and leaves the browse screen loading forever.
const mangayomiClientCode = '''
class Client {
    constructor(reqcopyWith) {
        this.reqcopyWith = reqcopyWith;
    }
    async head(url, headers) {
        headers = headers;
        const result = await sendMessage(
            "http_head",
            JSON.stringify([null, this.reqcopyWith, url, headers])
        );
        return JSON.parse(result);
    }
    async get(url, headers) {
        headers = headers;
        const result = await sendMessage(
            "http_get",
            JSON.stringify([null, this.reqcopyWith, url, headers])
        );
        return JSON.parse(result);
    }
    async post(url, headers, body) {
        headers = headers;
        const result = await sendMessage(
            "http_post",
            JSON.stringify([null, this.reqcopyWith, url, headers, body])
        );
        return JSON.parse(result);
    }
    async put(url, headers, body) {
        headers = headers;
        const result = await sendMessage(
            "http_put",
            JSON.stringify([null, this.reqcopyWith, url, headers, body])
        );
        return JSON.parse(result);
    }
    async delete(url, headers, body) {
        headers = headers;
        const result = await sendMessage(
            "http_delete",
            JSON.stringify([null, this.reqcopyWith, url, headers, body])
        );
        return JSON.parse(result);
    }
    async patch(url, headers, body) {
        headers = headers;
        const result = await sendMessage(
            "http_patch",
            JSON.stringify([null, this.reqcopyWith, url, headers, body])
        );
        return JSON.parse(result);
    }
}
''';

Future<void> injectHttpBridge(JavascriptRuntime runtime) async {
  List<dynamic> asList(dynamic args) {
    if (args is List) return args;
    if (args is String) {
      try {
        final decoded = jsonDecode(args);
        if (decoded is List) return decoded;
      } catch (_) {}
    }
    return <dynamic>[];
  }

  runtime.onMessage('http_head', (dynamic args) async {
    final list = asList(args);
    return await _toHttpResponse(_client(list), 'HEAD', list);
  });
  runtime.onMessage('http_get', (dynamic args) async {
    final list = asList(args);
    return await _toHttpResponse(_client(list), 'GET', list);
  });
  runtime.onMessage('http_post', (dynamic args) async {
    final list = asList(args);
    return await _toHttpResponse(_client(list), 'POST', list);
  });
  runtime.onMessage('http_put', (dynamic args) async {
    final list = asList(args);
    return await _toHttpResponse(_client(list), 'PUT', list);
  });
  runtime.onMessage('http_delete', (dynamic args) async {
    final list = asList(args);
    return await _toHttpResponse(_client(list), 'DELETE', list);
  });
  runtime.onMessage('http_patch', (dynamic args) async {
    final list = asList(args);
    return await _toHttpResponse(_client(list), 'PATCH', list);
  });

  runtime.evaluate(mangayomiClientCode);
}

InterceptedClient _client(List args) {
  final reqcopyWith = args.length > 1 ? args[1] as Map? : null;
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

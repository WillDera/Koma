import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http_interceptor/http_interceptor.dart';

import '../../repositories/cookie_repository.dart';
import '../extension_client_settings.dart';
import 'cf_proxy_client.dart';
import 'doh_resolver.dart';

/// Browser-like User-Agent applied to image requests and (as a fallback) by
/// [MCookieManager]. Mirrors mangayomi's default UA for Mihon-style requests.
const kBrowserUserAgent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Koma/1.0';

/// Shared [webview.WebViewEnvironment] for [webview.HeadlessInAppWebView]s.
///
/// Only Windows needs an explicit environment (WebView2). On Android — the
/// primary platform — this stays `null` and the platform default is used,
/// exactly like mangayomi.
webview.WebViewEnvironment? webViewEnvironment;

/// Port of the local loopback "Cloudflare Resolution Webview Server". The
/// [ResolveCloudFlareChallenge] retry policy POSTs the failing URL here and
/// this handler drives a headless WebView until the challenge clears.
int cfPort = 0;
HttpServer? _cfServer;

/// Faithful port of mangayomi's [MClient](lib/services/http/m_client.dart).
///
/// Builds an [InterceptedClient] whose request interceptor ([MCookieManager])
/// injects host-matched cookies stored in the [CookieRepository], and whose
/// retry policy ([ResolveCloudFlareChallenge]) detects Cloudflare 403/503
/// responses and solves them with a headless WebView before retrying.
class MClient {
  MClient._();

  /// Set at app startup from the [CookieRepository] so non-widget code (image
  /// provider, webview server) can read/write cookies. Mirrors mangayomi's
  /// global `isar` reference.
  static CookieRepository? cookies;

  /// Per-host User-Agent resolved by a Cloudflare bypass WebView, keyed by
  /// host. `cf_clearance` cookies are bound to the exact UA that solved the
  /// challenge, so the retried request must reuse it (mangayomi stores the same
  /// value in its settings singleton). Cleared together with [deleteAllCookies].
  static final Map<String, String> _solvedUserAgents = {};

  /// Returns the WebView-resolved User-Agent for [url]'s host, or null.
  static String? getSolvedUserAgent(String url) {
    return _solvedUserAgents[Uri.parse(url).host];
  }

  /// Shared plain HTTP client used as the inner transport for intercepted
  /// clients. Mirrors mangayomi's `MClient.defaultClient`.
  static http.Client defaultClient = _buildTransport();

  /// Per-source [InterceptedClient] cache (connection reuse / pool).
  static final Map<String, InterceptedClient> _clientPool = {};

  static String? _resolveSourceId(Object? source) {
    if (source == null) return null;
    try {
      final dynamic s = source;
      final sid = s.sourceId as String?;
      if (sid != null && sid.isNotEmpty) return sid;
      final id = s.id;
      if (id != null) return id.toString();
    } catch (_) {}
    return null;
  }

  static Future<String> extensionUserAgent(String sourceId) async {
    final settings = await ExtensionClientSettings.load(sourceId);
    return settings.userAgent.isNotEmpty
        ? settings.userAgent
        : kBrowserUserAgent;
  }

  static http.Client _buildTransport() {
    final raw = HttpClient();
    raw.connectionFactory =
        (Uri url, String? proxyHost, int? proxyPort) async {
          final host = url.host;
          final address = await DohResolver.resolve(host);
          return Socket.startConnect(address, url.port);
        };
    return IOClient(raw);
  }

  /// Rebuild the shared transport after DoH / network pref changes.
  static Future<void> refreshTransport() async {
    DohResolver.clearCache();
    try {
      defaultClient.close();
    } catch (_) {}
    defaultClient = _buildTransport();
    for (final client in _clientPool.values) {
      try {
        client.close();
      } catch (_) {}
    }
    _clientPool.clear();
  }

  /// Builds an [InterceptedClient] with the Cloudflare retry policy and the
  /// cookie/logging interceptors.
  /// [source] is accepted for Dart-extension / mangayomi ABI parity
  /// (`Client(source)`); cookie/CF behaviour is host-based and does not
  /// currently branch on the extension source object.
  static InterceptedClient init({
    Object? source,
    String? sourceId,
    Map<String, dynamic>? reqcopyWith,
    bool showCloudFlareError = true,
  }) {
    final sid = sourceId ?? _resolveSourceId(source);
    final poolKey = sid ?? '_default';
    return _clientPool.putIfAbsent(
      poolKey,
      () => InterceptedClient.build(
        client: defaultClient,
        retryPolicy: ResolveCloudFlareChallenge(showCloudFlareError),
        interceptors: [
          MCookieManager(sourceId: sid, reqcopyWith: reqcopyWith),
          LoggerInterceptor(showCloudFlareError),
        ],
      ),
    );
  }

  static void rememberSolvedUserAgent(String url, String ua) {
    if (ua.isEmpty) return;
    _solvedUserAgents[Uri.parse(url).host] = ua;
  }

  /// Returns the `Cookie` header for [url]'s host if a stored cookie matches.
  /// Host matching mirrors mangayomi: exact host OR the request host contains
  /// the stored host as a substring.
  ///
  /// Cookies are read from two stores and merged:
  /// 1. The [CookieRepository] (Isar) — written by this Dart-side resolver.
  /// 2. The platform WebKit [CookieManager] — the same store the Kotlin Dalvik
  ///    server's [AndroidCookieJar] writes to when its `CloudflareInterceptor`
  ///    solves a challenge. Without this fallback a `cf_clearance` obtained by
  ///    the Kotlin source-request path never reaches Dart image requests.
  static Future<Map<String, String>> getCookiesPref(String url) async {
    final repo = cookies;
    String cookie = '';
    if (repo != null) {
      final stored = await repo.getAll();
      if (stored.isNotEmpty) {
        final host = Uri.parse(url).host;
        for (final element in stored) {
          if (element.host == host || host.contains(element.host)) {
            cookie = element.cookie;
            break;
          }
        }
      }
    }
    if (!Platform.isLinux) {
      try {
        final webCookies = await webview.CookieManager.instance().getCookies(
          url: webview.WebUri(url),
        );
        if (webCookies.isNotEmpty) {
          final webCookie = webCookies
              .map((e) => '${e.name}=${e.value}')
              .join('; ');
          cookie = cookie.isNotEmpty ? '$cookie; $webCookie' : webCookie;
        }
      } catch (_) {}
    }
    if (cookie.isEmpty) return {};
    return {HttpHeaders.cookieHeader: cookie};
  }

  /// Persists cookies for [url]'s host to the [CookieRepository].
  ///
  /// Either the caller supplies [cookie] directly (joined `name=value; ...`
  /// string), or the cookies are read from the platform [CookieManager] for
  /// the given [webViewController]. Both paths match mangayomi's `setCookie`.
  ///
  /// The resolved webview User-Agent [ua] is stored per-host alongside the
  /// cookies: Cloudflare's `cf_clearance` is bound to the exact UA that solved
  /// the challenge, so the retried request must reuse it. Mirrors mangayomi,
  /// which persists the resolved UA into the settings singleton.
  static Future<void> setCookie(
    String url,
    String ua,
    webview.InAppWebViewController? webViewController, {
    String? cookie,
  }) async {
    final repo = cookies;
    if (repo == null) return;
    final host = Uri.parse(url).host;
    List<String> cookieList = [];
    if (cookie != null && cookie.isNotEmpty) {
      cookieList = cookie
          .split(RegExp('(?<=)(,)(?=[^;]+?=)'))
          .where((cookie) => cookie.isNotEmpty)
          .toList();
    } else if (!Platform.isLinux) {
      cookieList = (await webview.CookieManager.instance().getCookies(
        url: webview.WebUri(url),
        webViewController: webViewController,
      )).map((e) => '${e.name}=${e.value}').toList();
    }
    if (cookieList.isNotEmpty) {
      await repo.setCookie(host, cookieList.join('; '));
    }
    if (ua.isNotEmpty) {
      _solvedUserAgents[host] = ua;
    }
  }

  /// Removes the stored cookie entry for [host] (used by the manual webview
  /// "clear cookie" action).
  static Future<void> deleteAllCookies(String url) async {
    final repo = cookies;
    if (repo == null) return;
    final host = Uri.parse(url).host;
    _solvedUserAgents.remove(host);
    await repo.deleteCookie(host);
  }
}

/// Injects stored cookies into outgoing requests. Port of mangayomi's
/// [MCookieManager].
class MCookieManager extends InterceptorContract {
  MCookieManager({this.sourceId, this.reqcopyWith});

  final String? sourceId;
  Map<String, dynamic>? reqcopyWith;

  @override
  Future<http.BaseRequest> interceptRequest({
    required http.BaseRequest request,
  }) async {
    final cookie = await MClient.getCookiesPref(request.url.toString());
    if (cookie.isNotEmpty &&
        request.headers[HttpHeaders.cookieHeader] == null) {
      request.headers.addAll(cookie);
    }
    final solved = MClient.getSolvedUserAgent(request.url.toString());
    if (solved != null && solved.isNotEmpty) {
      request.headers[HttpHeaders.userAgentHeader] = solved;
    } else {
      final sid = sourceId;
      if (sid != null && sid.isNotEmpty) {
        request.headers[HttpHeaders.userAgentHeader] =
            await MClient.extensionUserAgent(sid);
      } else if (request.headers[HttpHeaders.userAgentHeader] == null) {
        request.headers[HttpHeaders.userAgentHeader] = kBrowserUserAgent;
      }
    }
    try {
      if (reqcopyWith != null) {
        if (reqcopyWith!['followRedirects'] != null) {
          request.followRedirects = reqcopyWith!['followRedirects'];
        }
        if (reqcopyWith!['maxRedirects'] != null) {
          request.maxRedirects = reqcopyWith!['maxRedirects'];
        }
        if (reqcopyWith!['contentLength'] != null) {
          request.contentLength = reqcopyWith!['contentLength'];
        }
        if (reqcopyWith!['persistentConnection'] != null) {
          request.persistentConnection = reqcopyWith!['persistentConnection'];
        }
      }
    } catch (_) {}
    return request;
  }

  @override
  Future<http.BaseResponse> interceptResponse({
    required http.BaseResponse response,
  }) async {
    return response;
  }
}

/// Logs requests/responses and surfaces a message when a Cloudflare challenge
/// could not be bypassed. Port of mangayomi's [LoggerInterceptor] (toasts
/// replaced with debug output — LNStash has no bot_toast).
class LoggerInterceptor extends InterceptorContract {
  LoggerInterceptor(this.showCloudFlareError);

  final bool showCloudFlareError;

  @override
  Future<http.BaseRequest> interceptRequest({
    required http.BaseRequest request,
  }) async {
    if (kDebugMode) {
      debugPrint(
        '----- Request -----\n${request.method}: ${request.url}\n'
        'headers: ${request.headers.toString()}',
      );
    }
    return request;
  }

  @override
  Future<http.BaseResponse> interceptResponse({
    required http.BaseResponse response,
  }) async {
    if (showCloudFlareError) {
      final cloudflare = isCloudflare(response);
      if (kDebugMode) {
        debugPrint(
          '----- Response -----\n${response.statusCode}: '
          '${response.request?.url} '
          '${cloudflare ? 'Failed to bypass Cloudflare' : ''}',
        );
      }
      if (cloudflare) {
        debugPrint(
          '${response.statusCode} Failed to bypass Cloudflare\n'
          'You can try to bypass it manually in the webview\n\n'
          'statusCode: ${response.statusCode}',
        );
      }
    }
    return response;
  }
}

/// True when [response] looks like a Cloudflare challenge: 403/503 with a
/// `cloudflare` / `cloudflare-nginx` server header.
bool isCloudflare(http.BaseResponse response) {
  return [403, 503].contains(response.statusCode) &&
      ['cloudflare-nginx', 'cloudflare'].contains(response.headers['server']);
}

/// Retry policy that detects Cloudflare challenges and drives a headless
/// WebView (via the loopback server) to obtain a `cf_clearance` cookie before
/// the request is re-issued. Port of mangayomi's [ResolveCloudFlareChallenge].
class ResolveCloudFlareChallenge extends RetryPolicy {
  ResolveCloudFlareChallenge(this.showCloudFlareError);

  final bool showCloudFlareError;

  @override
  int get maxRetryAttempts => 2;

  @override
  Future<bool> shouldAttemptRetryOnResponse(http.BaseResponse response) async {
    if (!showCloudFlareError) return false;
    if (!isCloudflare(response)) return false;
    final url = response.request!.url.toString();

    final proxy = await CfProxyClient.solve(url);
    if (proxy != null) {
      if (proxy.cookie.isNotEmpty) {
        await MClient.setCookie(url, proxy.userAgent, null, cookie: proxy.cookie);
      } else if (proxy.userAgent.isNotEmpty) {
        MClient.rememberSolvedUserAgent(url, proxy.userAgent);
      }
      return true;
    }

    if (Platform.isLinux) return false;
    try {
      return http
          .post(
            Uri.parse('http://localhost:$cfPort/resolve_cf'),
            headers: {HttpHeaders.contentTypeHeader: 'application/json'},
            body: jsonEncode({'url': url}),
          )
          .then((res) {
            if (res.statusCode == 200) {
              final data = jsonDecode(res.body) as Map<String, dynamic>;
              return data['result'] as bool;
            }
            return false;
          });
    } catch (e) {
      return false;
    }
  }
}

/// Starts the local Cloudflare Resolution Webview Server on a loopback port.
/// Ported from mangayomi's [webviewServer].
Future<void> webviewServer() async {
  try {
    _cfServer = await HttpServer.bind(InternetAddress.loopbackIPv4, cfPort);
    cfPort = _cfServer!.port;
    _cfServer!.listen(
      (HttpRequest request) {
        if (request.method == 'POST' && request.uri.path == '/resolve_cf') {
          _handleResolveCf(request);
        } else if (request.method == 'POST' &&
            request.uri.path == '/evaluateJavascriptViaWebview') {
          _evaluateJavascriptViaWebview(request);
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..write('Not Found')
            ..close();
        }
      },
      onError: (e, st) {
        if (kDebugMode) {
          debugPrint('CF server listener error: $e\n$st');
        }
      },
      cancelOnError: false,
    );
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint(
        "Couldn't start Cloudflare Resolution Webview Server: $e\n$st",
      );
    }
  }
}

/// Stops the local Cloudflare Resolution Webview Server.
Future<void> stopwebviewServer() async {
  final server = _cfServer;
  if (server == null) return;
  try {
    await server.close(force: true);
  } finally {
    _cfServer = null;
    cfPort = 0;
  }
}

/// Handles `POST /resolve_cf`. Loads [url] in a headless WebView and polls the
/// DOM for the Cloudflare challenge success marker, then persists the
/// `cf_clearance` cookies and reports whether the page is still challenged.
/// Port of mangayomi's [_handleResolveCf].
void _handleResolveCf(HttpRequest request) async {
  int time = 0;
  bool timeOut = false;
  bool isCloudFlare = true;
  try {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final url = data['url'] as String?;

    if (url == null) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write(jsonEncode({'error': 'Missing url parameter'}))
        ..close();
      return;
    }

    webview.HeadlessInAppWebView? headlessWebView;
    headlessWebView = webview.HeadlessInAppWebView(
      webViewEnvironment: webViewEnvironment,
      // Let the WebView solve with its default User-Agent (mangayomi does the
      // same — no UA override). The resolved UA is read back from
      // `navigator.userAgent` and persisted via setCookie so the retried
      // request can reuse it, since `cf_clearance` is bound to the exact UA
      // that solved the challenge.
      initialUrlRequest: webview.URLRequest(url: webview.WebUri(url)),
      onLoadStop: (controller, url) async {
        try {
          isCloudFlare =
              await controller.platform.evaluateJavascript(
                source:
                    "document.head.innerHTML.includes('#challenge-success-text')",
              ) ??
              false;
        } catch (_) {
          isCloudFlare = false;
        }

        await Future.doWhile(() async {
          if (!timeOut && isCloudFlare) {
            try {
              isCloudFlare =
                  await controller.platform.evaluateJavascript(
                    source:
                        "document.head.innerHTML.includes('#challenge-success-text')",
                  ) ??
                  false;
            } catch (_) {
              isCloudFlare = false;
            }
          }
          if (isCloudFlare) {
            await Future.delayed(const Duration(milliseconds: 300));
          }

          return isCloudFlare;
        });
        if (!timeOut) {
          final ua =
              await controller.evaluateJavascript(
                source: 'navigator.userAgent',
              ) ??
              '';
          await MClient.setCookie(url.toString(), ua, controller);
        }
      },
    );

    headlessWebView.run();

    await Future.doWhile(() async {
      timeOut = time == 15;
      if (!isCloudFlare || timeOut) {
        return false;
      }
      await Future.delayed(const Duration(seconds: 1));
      time++;
      return true;
    });
    try {
      headlessWebView.dispose();
    } catch (_) {}

    request.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'result': isCloudFlare}))
      ..close();
  } catch (e) {
    request.response
      ..statusCode = HttpStatus.badRequest
      ..write(jsonEncode({'error': 'Invalid JSON'}))
      ..close();
  }
}

/// Handles `POST /evaluateJavascriptViaWebview`. Loads [url] in a headless
/// WebView, runs [scripts] on load-stop, and returns whatever the page posts
/// back via the `setResponse` JS handler. Port of mangayomi's handler.
Future<void> _evaluateJavascriptViaWebview(HttpRequest request) async {
  try {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final url = data['url'] as String;
    final headers =
        (data['headers'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value.toString()),
        ) ??
        {};
    final scripts =
        (data['scripts'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final time = data['time'] as int? ?? 30;

    int t = 0;
    bool timeOut = false;
    bool isOk = false;
    String response = '';
    webview.HeadlessInAppWebView? headlessWebView;
    try {
      headlessWebView = webview.HeadlessInAppWebView(
        webViewEnvironment: webViewEnvironment,
        onWebViewCreated: (controller) {
          controller.addJavaScriptHandler(
            handlerName: 'setResponse',
            callback: (args) {
              response = args[0] as String;
              isOk = true;
            },
          );
        },
        initialUrlRequest: webview.URLRequest(
          url: webview.WebUri(url),
          headers: headers,
        ),
        onLoadStop: (controller, loadedUrl) async {
          for (final script in scripts) {
            await controller.platform.evaluateJavascript(source: script);
          }
        },
      );

      await headlessWebView.run();

      await Future.doWhile(() async {
        timeOut = time == t;
        if (timeOut || isOk) {
          return false;
        }
        await Future.delayed(const Duration(seconds: 1));
        t++;
        return true;
      });
    } finally {
      try {
        await headlessWebView?.dispose();
      } catch (_) {}
    }
    request.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'result': response}))
      ..close();
  } catch (_) {
    request.response
      ..statusCode = HttpStatus.badRequest
      ..write(jsonEncode({'error': 'Invalid JSON'}))
      ..close();
  }
}

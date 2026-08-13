// ignore_for_file: non_nullable_equals_parameter, depend_on_referenced_packages, implementation_imports
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui show Codec;

import 'package:extended_image_library/src/extended_image_provider.dart';
import 'package:extended_image_library/src/network/extended_network_image_provider.dart'
    as image_provider;
import 'package:extended_image_library/src/platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http_client_helper/http_client_helper.dart';
import 'package:path/path.dart';

import '../services/http/m_client.dart';
import 'cache_directory.dart';

/// LRU Memory Cache for decoded image data.
///
/// Faithful port of mangayomi's [_LRUCache] (lib/modules/widgets/
/// custom_extended_image_provider.dart). Used to keep the *encoded* bytes of
/// recently-fetched network images in memory so re-decode of a still-visible
/// cover during a fast scroll doesn't hit disk (let alone network). Bounded by
/// a byte budget (50 MB by default) instead of an entry count, since each
/// raw image payload is hundreds of KB to a few MB.
class _LRUCache<K, V> {
  final int _maxSize;
  final _cache = <K, V>{};
  int _currentSize = 0;
  final int Function(V)? _sizeOf;

  _LRUCache({required this._maxSize, this._sizeOf});

  V? get(K key) {
    final value = _cache.remove(key);
    if (value != null) {
      _cache[key] = value; // Move to end (most recently used)
    }
    return value;
  }

  void put(K key, V value) {
    _cache.remove(key); // Remove if exists
    _cache[key] = value; // Add to end

    if (_sizeOf != null) {
      _currentSize += _sizeOf(value);
      while (_currentSize > _maxSize && _cache.isNotEmpty) {
        final oldest = _cache.entries.first;
        _currentSize -= _sizeOf(oldest.value);
        _cache.remove(oldest.key);
      }
    } else {
      while (_cache.length > _maxSize) {
        _cache.remove(_cache.keys.first);
      }
    }
  }

  void remove(K key) {
    final value = _cache.remove(key);
    if (value != null && _sizeOf != null) {
      _currentSize -= _sizeOf(value);
    }
  }

  void clear() {
    _cache.clear();
    _currentSize = 0;
  }

  int get length => _cache.length;
  int get currentSize => _currentSize;
}

/// Global memory cache (100 images max, ~50 MB).
final _memoryCache = _LRUCache<String, Uint8List>(
  maxSize: 50 * 1024 * 1024, // 50 MB
  sizeOf: (data) => data.length,
);

/// Cache metadata for LRU eviction.
class _CacheMetadata {
  final String path;
  final int size;
  final DateTime lastAccessed;

  _CacheMetadata({
    required this.path,
    required this.size,
    required this.lastAccessed,
  });
}

/// Global disk-cache manager.
///
/// Faithful port of mangayomi's [_CacheManager]. Walks the cache folder, sums
/// file sizes, and if the total exceeds [_maxCacheSize] deletes files in
/// least-recently-accessed order until under the limit. Stat-based eviction
/// (instead of a manifest) keeps the cache correct across reinstalls /
/// reboots without any persistent index to corrupt.
class _CacheManager {
  static const _maxCacheSize = 500 * 1024 * 1024; // 500 MB

  static Future<int> getCacheSize(Directory cacheDir) async {
    if (!await cacheDir.exists()) return 0;

    int totalSize = 0;
    await for (final entity in cacheDir.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }

  static Future<void> evictOldestIfNeeded(Directory cacheDir) async {
    final size = await getCacheSize(cacheDir);
    if (size <= _maxCacheSize) return;

    // Collect all cache files with metadata.
    final List<_CacheMetadata> files = [];
    await for (final entity in cacheDir.list()) {
      if (entity is File) {
        final stat = await entity.stat();
        files.add(
          _CacheMetadata(
            path: entity.path,
            size: stat.size,
            lastAccessed: stat.accessed,
          ),
        );
      }
    }

    // Sort by last accessed (oldest first).
    files.sort((a, b) => a.lastAccessed.compareTo(b.lastAccessed));

    // Delete until under limit.
    int currentSize = size;
    for (final file in files) {
      if (currentSize <= _maxCacheSize) break;
      try {
        await File(file.path).delete();
        currentSize -= file.size;
      } catch (e) {
        if (kDebugMode) print('Failed to delete cache file: $e');
      }
    }
  }
}

/// [ExtendedNetworkImageProvider] subclass that backs the cover / page image
/// cache in LNStash. Faithful port of mangayomi's
/// `CustomExtendedNetworkImageProvider` — same in-memory byte LRU, same
/// disk-cache structure (MD5-keyed files under [CacheDirectory], with a
/// 500 MB LRU eviction cap), same retry + exponential backoff, and the same
/// `cacheMaxAge` expiry semantics.
///
/// HTTP transport is routed through [MClient.init] exactly like mangayomi:
/// an [InterceptedClient] whose [MCookieManager] injects stored cookies and
/// whose [ResolveCloudFlareChallenge] retry policy solves Cloudflare
/// challenges with a headless WebView before re-issuing the request.
///
/// Two folder-name conventions are emitted by callers and respected here:
///   - `cacheimagecover` (default) for library / detail cover thumbnails.
///   - `cacheimagemanga` for reader pages.
/// Keeping both folders distinct matches mangayomi's layout, so a future
/// upstream-ported disk tool is drop-in compatible.
class CustomExtendedNetworkImageProvider
    extends ImageProvider<image_provider.ExtendedNetworkImageProvider>
    with ExtendedImageProvider<image_provider.ExtendedNetworkImageProvider>
    implements image_provider.ExtendedNetworkImageProvider {
  /// Creates an object that fetches the image at the given URL.
  ///
  /// The arguments must not be null.
  CustomExtendedNetworkImageProvider(
    this.url, {
    this.scale = 1.0,
    this.headers,
    this.cache = true,
    this.retries = 3,
    this.timeLimit,
    this.timeRetry = const Duration(milliseconds: 100),
    this.cacheKey,
    this.printError = true,
    this.cacheRawData = false,
    this.cancelToken,
    this.imageCacheName,
    this.imageCacheFolderName,
    this.cacheMaxAge = const Duration(days: 30),
    this.showCloudFlareError = false,
  });

  /// The name of [ImageCache], you can define custom [ImageCache] to store this provider.
  @override
  final String? imageCacheName;

  /// Whether cache raw data if you need to get raw data directly.
  /// For example, we need raw image data to edit,
  /// but [ui.Image.toByteData()] is very slow. So we cache the image
  /// data here.
  @override
  final bool cacheRawData;

  /// The time limit to request image
  @override
  final Duration? timeLimit;

  /// The time to retry to request
  @override
  final int retries;

  /// The time duration to retry to request
  @override
  final Duration timeRetry;

  /// Whether cache image to local
  @override
  final bool cache;

  /// The URL from which the image will be fetched.
  @override
  final String url;

  /// The scale to place in the [ImageInfo] object of the image.
  @override
  final double scale;

  /// The HTTP headers that will be used with [HttpClient] to fetch image from network.
  @override
  final Map<String, String>? headers;

  /// The token to cancel network request
  @override
  final CancellationToken? cancelToken;

  /// Custom cache key
  @override
  final String? cacheKey;

  /// print error
  @override
  final bool printError;

  /// The max duration to cache image.
  /// After this time the cache is expired and the image is reloaded.
  @override
  final Duration? cacheMaxAge;

  /// Folder name under the application cache directory where disk-cached
  /// image bytes are stored. Defaults to `cacheimagecover` (covers / thumbs).
  /// Use `cacheimagemanga` for full-resolution reader pages so they live in
  /// a separate folder with its own 500 MB eviction bucket.
  final String? imageCacheFolderName;

  /// Enables the Cloudflare retry policy for this request. Pass `true` for
  /// reader pages and covers (matching mangayomi).
  final bool showCloudFlareError;

  @override
  ImageStreamCompleter loadImage(
    image_provider.ExtendedNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    // Ownership of this controller is handed off to [_loadAsync]; it is that
    // method's responsibility to close the controller's stream when the image
    // has been loaded or an error is thrown.
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(
        key as CustomExtendedNetworkImageProvider,
        chunkEvents,
        decode,
      ),
      scale: key.scale,
      chunkEvents: chunkEvents.stream,
      debugLabel: key.url,
      informationCollector: () {
        return <DiagnosticsNode>[
          DiagnosticsProperty<ImageProvider>('Image provider', this),
          DiagnosticsProperty<image_provider.ExtendedNetworkImageProvider>(
            'Image key',
            key,
          ),
        ];
      },
    );
  }

  @override
  Future<CustomExtendedNetworkImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<CustomExtendedNetworkImageProvider>(this);
  }

  Future<ui.Codec> _loadAsync(
    CustomExtendedNetworkImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    ImageDecoderCallback decode,
  ) async {
    assert(key == this);
    final String md5Key = cacheKey ?? keyToMd5(key.url);
    ui.Codec? result;
    if (cache) {
      try {
        final Uint8List? data = await _loadCache(key, chunkEvents, md5Key);
        if (data != null) {
          result = await instantiateImageCodec(data, decode);
        }
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
      }
    }

    if (result == null) {
      try {
        final Uint8List? data = await _loadNetwork(key, chunkEvents);
        if (data != null) {
          result = await instantiateImageCodec(data, decode);
        }
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
      }
    }

    // Failed to load
    if (result == null) {
      return Future<ui.Codec>.error(StateError('Failed to load $url.'));
    }

    return result;
  }

  /// Get the image from cache folder.
  Future<Uint8List?> _loadCache(
    CustomExtendedNetworkImageProvider key,
    StreamController<ImageChunkEvent>? chunkEvents,
    String md5Key,
  ) async {
    // Check memory cache first.
    final cachedData = _memoryCache.get(md5Key);
    if (cachedData != null) {
      return cachedData;
    }

    final Directory cacheImagesDirectory = await CacheDirectory.create(
      imageCacheFolderName,
    );
    Uint8List? data;
    final File cacheFile = File(join(cacheImagesDirectory.path, md5Key));

    // Exists: try to find cache image file.
    if (cacheFile.existsSync()) {
      if (key.cacheMaxAge != null) {
        final DateTime now = DateTime.now();
        final DateTime lastModified = cacheFile.lastModifiedSync();
        if (now.difference(lastModified) > key.cacheMaxAge!) {
          cacheFile.deleteSync();
        } else {
          data = await cacheFile.readAsBytes();
          _memoryCache.put(md5Key, data);
        }
      } else {
        data = await cacheFile.readAsBytes();
        _memoryCache.put(md5Key, data);
      }
    }

    // Load from network.
    if (data == null) {
      data = await _loadNetwork(key, chunkEvents);
      if (data != null) {
        // Evict old cache if needed before writing.
        await _CacheManager.evictOldestIfNeeded(cacheImagesDirectory);

        // Cache image file.
        await File(join(cacheImagesDirectory.path, md5Key)).writeAsBytes(data);

        // Store in memory cache.
        _memoryCache.put(md5Key, data);
      }
    }

    return data;
  }

  /// Get the image from network.
  ///
  /// Faithful port of mangayomi's [_loadNetwork]. Streams the response body
  /// into a buffer with progress events, falling back to dynamic growth when
  /// the server doesn't send a content-length. Cancellation propagates via
  /// the [OperationCanceledError] semantics from [cancelToken].
  Future<Uint8List?> _loadNetwork(
    CustomExtendedNetworkImageProvider key,
    StreamController<ImageChunkEvent>? chunkEvents,
  ) async {
    try {
      final Uri resolved = Uri.base.resolve(key.url);
      // Some extensions emit a bare site-root as the image URL (e.g. mangadna's
      // `thumbnail_url` becomes `https://mangadna.com/` when a card's
      // `data-src` is empty). Fetching the root yields an HTML page, not an
      // image, so short-circuit before the request is even issued.
      if (resolved.path.isEmpty || resolved.path == '/') {
        if (kDebugMode) {
          print('NetworkImage URL is a site root, skipping: $resolved');
        }
        return null;
      }
      final StreamedResponse? response = await _tryGetResponse(resolved);

      if (response == null || response.statusCode != HttpStatus.ok) {
        if (kDebugMode) {
          print('NetworkImage is an empty file: $resolved');
        }
        return null;
      }

      // Pre-allocate list if content length is known.
      final int total = response.contentLength ?? 0;
      final List<int> bytes = total > 0
          ? List<int>.filled(total, 0, growable: true)
          : <int>[];
      int received = 0;

      await for (var chunk in response.stream) {
        if (total > 0 && received + chunk.length <= total) {
          bytes.setRange(received, received + chunk.length, chunk);
        } else {
          bytes.addAll(chunk);
        }
        received += chunk.length;
        chunkEvents?.add(
          ImageChunkEvent(
            cumulativeBytesLoaded: received,
            expectedTotalBytes: total,
          ),
        );
      }

      if (bytes.isEmpty) {
        if (kDebugMode) {
          print('NetworkImage is an empty file: $resolved');
        }
        return null;
      }

      final payload = Uint8List.fromList(bytes);
      // Cloudflare / CDN often return 200 with HTML, SVG text, or other
      // non-bitmap bodies. Feed those to Flutter's ImageDecoder and you get
      // "Invalid image data" / HWUI unimplemented spam — reject early.
      if (!_looksLikeBitmap(payload)) {
        if (kDebugMode) {
          print('NetworkImage payload is not a decodeable bitmap: $resolved');
        }
        return null;
      }

      return payload;
    } on OperationCanceledError catch (_) {
      if (kDebugMode) {
        print('User cancel request $url.');
      }
      return Future<Uint8List>.error(StateError('User cancel request $url.'));
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    } finally {
      await chunkEvents?.close();
    }
    return null;
  }

  /// Issues the GET request through [MClient.init] (mangayomi's `_getResponse`).
  ///
  /// Routes through the intercepted client so [MCookieManager] injects stored
  /// cookies and [ResolveCloudFlareChallenge] can solve a Cloudflare 403/503
  /// before the retry. On any non-200 the request is re-issued through a fresh
  /// intercepted client — if the retry policy just saved a `cf_clearance`
  /// cookie, that second attempt now carries it.
  Future<StreamedResponse> _getResponse(Uri resolved) async {
    final http.Request request = http.Request('GET', resolved);

    // Optimize headers for better caching and compression.
    final optimizedHeaders = {
      ...?headers,
      'Accept-Encoding': 'gzip, deflate, br',
      'Accept': 'image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      'Connection': 'keep-alive',
    };
    request.headers.addAll(optimizedHeaders);

    // Same-site *CDN subdomains* (e.g. cdn.readcomicsonline.ru) challenge any
    // Referer — strip only for those. Apex-host covers
    // (readcomicsonline.ru/uploads/...) need the source Referer; stripping it
    // yields Cloudflare 403s on search/discover results even with a valid
    // cf_clearance. Cross-site CDNs (fmcdn.mfcdn.net) also keep Referer.
    // mangayomi never strips Referer; this is the narrow exception for CDN hosts.
    String? refererKey;
    String? referer;
    request.headers.forEach((key, value) {
      if (key.toLowerCase() == 'referer') {
        refererKey = key;
        referer = value;
      }
    });
    if (referer != null && referer!.isNotEmpty) {
      final sourceHost = Uri.tryParse(referer!)?.host;
      final imageHost = resolved.host;
      if (sourceHost != null &&
          sourceHost.isNotEmpty &&
          imageHost.isNotEmpty &&
          imageHost != sourceHost &&
          imageHost.endsWith('.$sourceHost')) {
        request.headers.remove(refererKey);
      }
    }

    if (kDebugMode) {
      debugPrint(
        'IMG first attempt: ${request.method} ${request.url}\n'
        'headers: ${request.headers}',
      );
    }

    StreamedResponse response = await MClient.init(
      showCloudFlareError: showCloudFlareError,
    ).send(request);

    if (kDebugMode) {
      debugPrint(
        'IMG first response: ${response.statusCode} '
        'server=${response.headers['server']} '
        'cf-mitigated=${response.headers['cf-mitigated']} '
        'cf-ray=${response.headers['cf-ray']}',
      );
    }

    if (response.statusCode != HttpStatus.ok) {
      final res = await MClient.init(
        showCloudFlareError: showCloudFlareError,
      ).send(response.request ?? request);
      if (kDebugMode) {
        debugPrint(
          'IMG retry request: ${res.request?.method} ${res.request?.url}\n'
          'headers: ${res.request?.headers}',
        );
        debugPrint(
          'IMG retry response: ${res.statusCode} '
          'server=${res.headers['server']} '
          'cf-mitigated=${res.headers['cf-mitigated']} '
          'cf-ray=${res.headers['cf-ray']}',
        );
      }
      return res;
    }

    return response;
  }

  /// Http get with cancel + exponential backoff retry (mangayomi's
  /// `_tryGetResponse`). Retries on exceptions only; non-200 responses are
  /// handled by [_getResponse]'s fallback re-send.
  Future<StreamedResponse?> _tryGetResponse(Uri resolved) async {
    cancelToken?.throwIfCancellationRequested();

    int attempt = 0;
    while (attempt < retries) {
      try {
        return await CancellationTokenSource.register(
          cancelToken,
          _getResponse(resolved),
        );
      } catch (e) {
        attempt++;
        if (attempt >= retries) {
          rethrow;
        }

        // Exponential backoff: 100ms, 200ms, 400ms, 800ms, etc.
        final backoffDelay = Duration(
          milliseconds: timeRetry.inMilliseconds * (1 << attempt),
        );

        if (kDebugMode) {
          print(
            'Retry attempt $attempt/$retries after ${backoffDelay.inMilliseconds}ms',
          );
        }

        await Future.delayed(backoffDelay);
        cancelToken?.throwIfCancellationRequested();
      }
    }

    return null;
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is CustomExtendedNetworkImageProvider &&
        url == other.url &&
        scale == other.scale &&
        cacheRawData == other.cacheRawData &&
        timeLimit == other.timeLimit &&
        cancelToken == other.cancelToken &&
        timeRetry == other.timeRetry &&
        cache == other.cache &&
        cacheKey == other.cacheKey &&
        retries == other.retries &&
        imageCacheName == other.imageCacheName &&
        cacheMaxAge == other.cacheMaxAge;
  }

  @override
  int get hashCode => Object.hash(
    url,
    scale,
    cacheRawData,
    timeLimit,
    cancelToken,
    timeRetry,
    cache,
    cacheKey,
    retries,
    imageCacheName,
    cacheMaxAge,
  );

  @override
  String toString() => '$runtimeType("$url", scale: $scale)';

  @override
  /// Get network image data from cached.
  Future<Uint8List?> getNetworkImageData({
    StreamController<ImageChunkEvent>? chunkEvents,
  }) async {
    final String uId = cacheKey ?? keyToMd5(url);

    if (cache) {
      return await _loadCache(this, chunkEvents, uId);
    }

    return await _loadNetwork(this, chunkEvents);
  }

  @override
  WebHtmlElementStrategy get webHtmlElementStrategy =>
      WebHtmlElementStrategy.fallback;
}

/// True when [bytes] start with a common raster magic header Flutter can decode.
/// Rejects HTML/Cloudflare error bodies and SVG text returned as "image/png".
bool _looksLikeBitmap(Uint8List bytes) {
  if (bytes.length < 4) return false;
  // PNG
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return true;
  }
  // JPEG
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return true;
  }
  // GIF
  if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
    return true;
  }
  // BMP
  if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
    return true;
  }
  // WEBP: RIFF....WEBP
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return true;
  }
  return false;
}

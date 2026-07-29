import 'dart:convert';
import 'dart:isolate';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent cache mapping an extension package name to its launcher-icon URL.
///
/// Keiyoushi's distribution repo (`extensions`) does **not** host an `icon/`
/// directory, so the legacy `.../repo/icon/${pkg}.png` URLs the app used to
/// build always 404'd. The authoritative icon URLs live in the full
/// `index.json` as each entry's `resources.iconUrl` field — but that file is
/// ~1.3 MB vs the ~460 KB `index.min.json` the app normally fetches, and it
/// uses a different schema (object with `extensionList.extensions[]`,
/// `packageName`, `versionName`, `resources.iconUrl`).
///
/// To keep the fast, light `index.min.json` as the per-fetch source of the
/// extension *list* while still resolving icons correctly, we fetch the full
/// `index.json` **once**, extract every `packageName → resources.iconUrl`
/// pair, and persist them to `SharedPreferences`. Subsequent icon lookups are
/// a single synchronous key read — fast, offline-friendly, and self-healing
/// (any pkg missing from the cache falls back to the deterministic CDN
/// derivation in [iconUrlForPkg]).
///
/// The cache is keyed purely by package name because icon URLs are CDN paths
/// into the `extensions-source` repo, independent of which index repo listed
/// the extension.
class ExtensionIconCache {
  ExtensionIconCache._();

  static const String _prefix = 'ext_icon_url_';
  static const String _populatedKey = 'ext_icon_cache_populated';

  static final ExtensionIconCache instance = ExtensionIconCache._();

  SharedPreferences? _prefs;

  /// Lazily-loaded SharedPreferences handle.
  Future<SharedPreferences> get _sp async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Look up the cached icon URL for [pkg]. Returns `null` when [pkg] is
  /// empty or unknown to the cache.
  ///
  /// Always prefer [resolveIconUrl] for display — it falls back to the
  /// deterministic CDN derivation when the cache has no entry.
  Future<String?> cachedIconUrl(String pkg) async {
    if (pkg.isEmpty) return null;
    final prefs = await _sp;
    return prefs.getString('$_prefix$pkg');
  }

  /// Resolve the best icon URL for [pkg]:
  ///   1. The persisted cache value (fast read, authoritative).
  ///   2. The deterministic CDN derivation from the package name.
  ///   3. `null` if [pkg] is empty.
  ///
  /// This is the single entry point display code should use — it never
  /// returns the stale `.../repo/icon/${pkg}.png` value that older DB rows
  /// may still hold, so existing installs self-heal without a migration.
  Future<String?> resolveIconUrl(String pkg) async {
    if (pkg.isEmpty) return null;
    final cached = await cachedIconUrl(pkg);
    if (cached != null && cached.isNotEmpty) return cached;
    return iconUrlForPkg(pkg);
  }

  /// Persist a single `pkg → iconUrl` mapping.
  Future<void> put(String pkg, String iconUrl) async {
    if (pkg.isEmpty || iconUrl.isEmpty) return;
    final prefs = await _sp;
    await prefs.setString('$_prefix$pkg', iconUrl);
  }

  /// Whether the one-time full-index population has already run.
  Future<bool> get isPopulated async {
    final prefs = await _sp;
    return prefs.getBool(_populatedKey) ?? false;
  }

  /// Synchronous derivation of the icon URL from a package name, used as a
  /// fallback when the cache has no entry and as a guarantee that display
  /// never returns the broken `repo/icon/...` URL.
  ///
  /// `eu.kanade.tachiyomi.extension.{lang}.{name}` →
  /// `https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/{lang}/{name}/res/mipmap-xhdpi/ic_launcher.png`
  ///
  /// The last two dot-separated segments after the fixed
  /// `eu.kanade.tachiyomi.extension` prefix are `{lang}` and `{name}`, which
  /// matches the `extensions-source` directory layout for every extension.
  static String? iconUrlForPkg(String pkg) {
    if (pkg.isEmpty) return null;
    const base = 'eu.kanade.tachiyomi.extension.';
    if (!pkg.startsWith(base)) return null;
    final tail = pkg.substring(base.length);
    final dot = tail.indexOf('.');
    if (dot <= 0 || dot >= tail.length - 1) return null;
    final lang = tail.substring(0, dot);
    final name = tail.substring(dot + 1);
    if (lang.isEmpty || name.isEmpty) return null;
    return 'https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main'
        '/src/$lang/$name/res/mipmap-xhdpi/ic_launcher.png';
  }


  /// Fetch the full Keiyoushi `index.json` (~1.3 MB) once, extract every
  /// `packageName → resources.iconUrl` pair, and persist them. Parsing runs
  /// in a background isolate so the UI isolate never blocks on the large
  /// decode. Subsequent calls are no-ops once the cache is populated, unless
  /// [force] is true.
  ///
  /// [fullIndexUrl] defaults to the Keiyoushi full index. Network or parse
  /// failures are swallowed (and reported via [onError]) so icon resolution
  /// degrades gracefully to the derivation fallback instead of crashing the
  /// extension list.
  Future<void> ensurePopulated({
    String fullIndexUrl =
        'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.json',
    http.Client? httpClient,
    bool force = false,
    void Function(Object error)? onError,
  }) async {
    if (!force && await isPopulated) return;
    final http.Client client = httpClient ?? http.Client();
    final bool ownsClient = httpClient == null;
    try {
      final res = await client.get(Uri.parse(fullIndexUrl));
      if (res.statusCode != 200) {
        onError?.call(
          Exception('Full index returned ${res.statusCode}: $fullIndexUrl'),
        );
        return;
      }
      // Decode off the UI isolate — the full index is ~1.3 MB.
      final pairs = await Isolate.run(
        () => _parseFullIndexIconUrls(res.body),
      );
      final prefs = await _sp;
      await prefs.setBool(_populatedKey, true);
      // SharedPreferences has no batch set, so write each pair. There are
      // ~1.3k extensions; this is a one-time cost on a background future.
      for (final entry in pairs.entries) {
        await prefs.setString('$_prefix${entry.key}', entry.value);
      }
    } catch (e) {
      onError?.call(e);
    } finally {
      if (ownsClient) client.close();
    }
  }

  /// Top-level isolate entry: parse the full `index.json` (object with
  /// `extensionList.extensions[]`) and return `{packageName: iconUrl}`.
  static Map<String, String> _parseFullIndexIconUrls(String body) {
    final root = jsonDecode(body);
    if (root is! Map) return const {};
    final list = root['extensionList']?['extensions'];
    if (list is! List) return const {};
    final out = <String, String>{};
    for (final raw in list) {
      if (raw is! Map) continue;
      final pkg = raw['packageName'];
      if (pkg is! String || pkg.isEmpty) continue;
      final resources = raw['resources'];
      if (resources is! Map) continue;
      final icon = resources['iconUrl'];
      if (icon is String && icon.isNotEmpty) {
        out[pkg] = icon;
      }
    }
    return out;
  }
}


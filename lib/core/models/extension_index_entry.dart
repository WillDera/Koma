import 'extension_source.dart' show SourceCodeLanguage;

class ExtensionIndexEntry {
  final String pkg;
  final String name;

  /// Mihon APK relative/absolute URL only. Never holds JS [sourceCodeUrl].
  final String apkUrl;

  /// Mangayomi native index `sourceCodeUrl` (JS/Dart script). Null for Mihon.
  final String? sourceCodeUrl;

  /// Catalog language: [SourceCodeLanguage.mihon], [SourceCodeLanguage.js],
  /// [SourceCodeLanguage.dart], or [SourceCodeLanguage.unsupported].
  final String sourceCodeLanguage;

  final String version;
  final String lang;
  final String contentWarning;
  final bool isNsfw;
  final String? baseUrl;
  final String? iconUrl;
  final String? apiUrl;
  final bool hasCloudflare;

  /// `manga` / `anime` / `novel`, or null when the index omitted itemType/isManga.
  final String? itemType;
  final List<Map<String, dynamic>> sources;

  const ExtensionIndexEntry({
    required this.pkg,
    required this.name,
    required this.apkUrl,
    this.sourceCodeUrl,
    this.sourceCodeLanguage = SourceCodeLanguage.mihon,
    required this.version,
    required this.lang,
    this.contentWarning = 'CONTENT_WARNING_SAFE',
    this.isNsfw = false,
    this.baseUrl,
    this.iconUrl,
    this.apiUrl,
    this.hasCloudflare = false,
    this.itemType,
    required this.sources,
  });

  bool get isJs => SourceCodeLanguage.isJs(sourceCodeLanguage);
  bool get isMihon => SourceCodeLanguage.isMihon(sourceCodeLanguage);
  bool get isDart => sourceCodeLanguage == SourceCodeLanguage.dart;

  String? get className {
    if (sources.isEmpty) return null;
    final c = sources.first['className'];
    if (c is String && c.isNotEmpty) return c;
    return null;
  }

  /// Map mangayomi `sourceCodeLanguage` (int index or string) → catalog token.
  /// Enum order: dart=0, javascript=1, mihon=2, lnreader=3.
  static String parseSourceCodeLanguage(dynamic raw) {
    if (raw is int) {
      switch (raw) {
        case 0:
          return SourceCodeLanguage.dart;
        case 1:
          return SourceCodeLanguage.js;
        case 2:
          return SourceCodeLanguage.mihon;
        default:
          return SourceCodeLanguage.unsupported;
      }
    }
    if (raw is String) {
      switch (raw.toLowerCase().trim()) {
        case 'js':
        case 'javascript':
          return SourceCodeLanguage.js;
        case 'dart':
          return SourceCodeLanguage.dart;
        case 'mihon':
          return SourceCodeLanguage.mihon;
        default:
          return SourceCodeLanguage.unsupported;
      }
    }
    // Mangayomi Source.fromJson defaults missing language to dart (index 0).
    return SourceCodeLanguage.dart;
  }

  /// Map mangayomi `itemType` / legacy `isManga` → `manga`/`anime`/`novel`.
  /// Returns null when neither field is present in the index JSON.
  static String? parseItemType(Map<String, dynamic> j) {
    if (!j.containsKey('itemType') && !j.containsKey('isManga')) return null;
    final raw = j['itemType'];
    if (raw is int && raw >= 0 && raw <= 2) {
      return const ['manga', 'anime', 'novel'][raw];
    }
    if (raw is String) {
      final s = raw.toLowerCase().trim();
      if (s == 'manga' || s == 'anime' || s == 'novel') return s;
      final n = int.tryParse(s);
      if (n != null && n >= 0 && n <= 2) {
        return const ['manga', 'anime', 'novel'][n];
      }
    }
    final isManga = j['isManga'];
    if (isManga == true) return 'manga';
    if (isManga == false) return 'anime';
    // itemType present but unusable — same default as Source.fromJson (0).
    return 'manga';
  }

  static bool _looksLikeMihon(Map<String, dynamic> j) {
    return j.containsKey('apk') ||
        j.containsKey('pkg') ||
        j.containsKey('packageName') ||
        j.containsKey('sources');
  }

  factory ExtensionIndexEntry.fromJson(Map<String, dynamic> j) {
    final sources = (j['sources'] as List? ?? const [])
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);

    final hasPackageName = j['packageName'] != null || j['pkg'] != null;
    final hasSourceCodeUrl = j['sourceCodeUrl'] != null;
    final hasId = j['id'] != null;
    final apiUrl = j['apiUrl'] as String?;
    final hasCloudflare = j['hasCloudflare'] == true;
    final itemType = parseItemType(j);

    // Mihon/Keiyoushi shape first — never put JS URLs into apkUrl.
    if (_looksLikeMihon(j)) {
      final pkg = j['packageName'] as String? ?? j['pkg'] as String? ?? '';
      final name = j['name'] as String? ?? (pkg.isEmpty ? 'Unknown' : pkg);

      String apk;
      if (j['resources'] is Map) {
        final r = j['resources'] as Map;
        apk = (r['apkUrl'] as String?) ?? '';
      } else {
        apk = j['apk'] as String? ?? '';
      }

      final version =
          j['versionName'] as String? ?? j['version'] as String? ?? '0';

      final String lang;
      if (sources.isNotEmpty) {
        lang =
            sources.first['language'] as String? ??
            sources.first['lang'] as String? ??
            'en';
      } else {
        lang = j['lang'] as String? ?? 'en';
      }

      final contentWarning =
          j['contentWarning'] as String? ?? 'CONTENT_WARNING_SAFE';
      final nsfw = j['nsfw'] == 1 ||
          j['isNsfw'] == true ||
          contentWarning == 'CONTENT_WARNING_NSFW' ||
          contentWarning == 'CONTENT_WARNING_MIXED';

      final baseUrl =
          j['baseUrl'] as String? ??
          (sources.isNotEmpty
              ? (sources.first['baseUrl'] as String?) ??
                    (sources.first['homeUrl'] as String?)
              : null);
      final iconUrl = j['resources'] is Map
          ? (j['resources'] as Map)['iconUrl'] as String?
          : (j['iconUrl'] as String?);

      return ExtensionIndexEntry(
        pkg: pkg,
        name: name,
        apkUrl: apk,
        sourceCodeUrl: null,
        sourceCodeLanguage: SourceCodeLanguage.mihon,
        version: version,
        lang: lang,
        contentWarning: contentWarning,
        isNsfw: nsfw,
        baseUrl: baseUrl,
        iconUrl: iconUrl,
        apiUrl: apiUrl,
        hasCloudflare: hasCloudflare,
        itemType: itemType,
        sources: sources,
      );
    }

    // Mangayomi native (JS / Dart-eval) — id + sourceCodeUrl, no package/apk.
    if (hasSourceCodeUrl || (hasId && !hasPackageName)) {
      final pkg = j['id']?.toString() ?? '';
      final name = (j['name'] as String?) ?? (pkg.isEmpty ? 'Unknown' : pkg);
      final isNsfw = j['isNsfw'] == true || j['nsfw'] == 1;
      return ExtensionIndexEntry(
        pkg: pkg,
        name: name,
        apkUrl: '',
        sourceCodeUrl: j['sourceCodeUrl'] as String?,
        sourceCodeLanguage: parseSourceCodeLanguage(j['sourceCodeLanguage']),
        version: j['version'] as String? ?? '0',
        lang: j['lang'] as String? ?? 'en',
        contentWarning:
            isNsfw ? 'CONTENT_WARNING_NSFW' : 'CONTENT_WARNING_SAFE',
        isNsfw: isNsfw,
        baseUrl: j['baseUrl'] as String?,
        iconUrl: j['iconUrl'] as String?,
        apiUrl: apiUrl,
        hasCloudflare: hasCloudflare,
        itemType: itemType,
        sources: sources,
      );
    }

    // Fallback: treat as Mihon-like with whatever fields exist.
    final pkg = j['packageName'] as String? ?? j['pkg'] as String? ?? '';
    return ExtensionIndexEntry(
      pkg: pkg,
      name: j['name'] as String? ?? (pkg.isEmpty ? 'Unknown' : pkg),
      apkUrl: j['apk'] as String? ?? '',
      sourceCodeUrl: null,
      sourceCodeLanguage: SourceCodeLanguage.mihon,
      version: j['versionName'] as String? ?? j['version'] as String? ?? '0',
      lang: j['lang'] as String? ?? 'en',
      contentWarning: j['contentWarning'] as String? ?? 'CONTENT_WARNING_SAFE',
      isNsfw: false,
      baseUrl: j['baseUrl'] as String?,
      iconUrl: j['iconUrl'] as String?,
      apiUrl: apiUrl,
      hasCloudflare: hasCloudflare,
      itemType: itemType,
      sources: sources,
    );
  }
}

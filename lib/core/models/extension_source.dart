import '../utils/language.dart';

/// `sourceCodeLanguage` values.
///
/// Installed sources persist [mihon], [js], or [dart]. Catalog index entries
/// may also use [unsupported] (rejected at install).
class SourceCodeLanguage {
  static const mihon = 'mihon';
  static const js = 'js';
  static const dart = 'dart';
  static const unsupported = 'unsupported';

  static bool isJs(String? v) => v == js || v == 'javascript';
  static bool isMihon(String? v) => v == mihon;
  static bool isDart(String? v) => v == dart;
  static bool isInstallable(String? v) => isJs(v) || isMihon(v) || isDart(v);
}

class ExtensionSource {
  final String id;
  final String sourceId;
  final String name;
  final String version;
  final String? versionLast;
  final String lang;
  final String apkPath;
  final String className;
  final String? iconUrl;
  final String? baseUrl;
  final String? sourceCodeUrl;
  final String? repoUrl;

  /// Mangayomi JS API base (e.g. MangaDex). Null/empty when unused.
  final String? apiUrl;

  /// Whether the source sits behind Cloudflare (mangayomi).
  final bool hasCloudflare;

  /// Product kind: `manga` / `anime` / `novel`. Koma is manga-only UI;
  /// field is persisted for index/JS fidelity.
  final String itemType;

  /// JS/Dart body for [SourceCodeLanguage.js] / [SourceCodeLanguage.dart];
  /// empty for Mihon APKs.
  final String sourceCode;

  /// [SourceCodeLanguage.mihon], [SourceCodeLanguage.js], or
  /// [SourceCodeLanguage.dart].
  final String sourceCodeLanguage;

  final String pkgName;
  final int versionCode;
  final String signatureHash;
  final bool isInstalled;
  final bool isActive;
  final bool isNsfw;
  final bool isPinned;
  final bool isObsolete;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// True when a newer version is available in the source's repo index.
  /// `versionLast` is written by [checkForUpdates] on app start / index fetch.
  bool get isUpdateAvailable {
    final latest = versionLast;
    if (latest == null || latest.isEmpty) return false;
    return compareVersions(version, latest) < 0;
  }

  /// Mihon Untrusted: inactive install awaiting trust, with signing metadata.
  bool get isUntrusted =>
      isInstalled &&
      !isActive &&
      pkgName.isNotEmpty &&
      signatureHash.isNotEmpty &&
      !isJs &&
      !isDart;

  bool get isJs => SourceCodeLanguage.isJs(sourceCodeLanguage);

  bool get isDart => SourceCodeLanguage.isDart(sourceCodeLanguage);

  ExtensionSource({
    required this.id,
    required this.sourceId,
    required this.name,
    required this.version,
    this.versionLast,
    required this.lang,
    required this.apkPath,
    required this.className,
    this.iconUrl,
    this.baseUrl,
    this.sourceCodeUrl,
    this.repoUrl,
    this.apiUrl,
    this.hasCloudflare = false,
    this.itemType = 'manga',
    this.sourceCode = '',
    this.sourceCodeLanguage = SourceCodeLanguage.mihon,
    this.pkgName = '',
    this.versionCode = 0,
    this.signatureHash = '',
    this.isInstalled = true,
    this.isActive = true,
    this.isNsfw = false,
    this.isPinned = false,
    this.isObsolete = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  ExtensionSource copyWith({
    String? id,
    String? sourceId,
    String? name,
    String? version,
    String? versionLast,
    String? lang,
    String? apkPath,
    String? className,
    String? iconUrl,
    String? baseUrl,
    String? sourceCodeUrl,
    String? repoUrl,
    String? apiUrl,
    bool? hasCloudflare,
    String? itemType,
    String? sourceCode,
    String? sourceCodeLanguage,
    String? pkgName,
    int? versionCode,
    String? signatureHash,
    bool? isInstalled,
    bool? isActive,
    bool? isNsfw,
    bool? isPinned,
    bool? isObsolete,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExtensionSource(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      name: name ?? this.name,
      version: version ?? this.version,
      versionLast: versionLast ?? this.versionLast,
      lang: lang ?? this.lang,
      apkPath: apkPath ?? this.apkPath,
      className: className ?? this.className,
      iconUrl: iconUrl ?? this.iconUrl,
      baseUrl: baseUrl ?? this.baseUrl,
      sourceCodeUrl: sourceCodeUrl ?? this.sourceCodeUrl,
      repoUrl: repoUrl ?? this.repoUrl,
      apiUrl: apiUrl ?? this.apiUrl,
      hasCloudflare: hasCloudflare ?? this.hasCloudflare,
      itemType: itemType ?? this.itemType,
      sourceCode: sourceCode ?? this.sourceCode,
      sourceCodeLanguage: sourceCodeLanguage ?? this.sourceCodeLanguage,
      pkgName: pkgName ?? this.pkgName,
      versionCode: versionCode ?? this.versionCode,
      signatureHash: signatureHash ?? this.signatureHash,
      isInstalled: isInstalled ?? this.isInstalled,
      isActive: isActive ?? this.isActive,
      isNsfw: isNsfw ?? this.isNsfw,
      isPinned: isPinned ?? this.isPinned,
      isObsolete: isObsolete ?? this.isObsolete,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceId': sourceId,
    'name': name,
    'version': version,
    'version_last': versionLast,
    'lang': lang,
    'apk_path': apkPath,
    'class_name': className,
    'icon_url': iconUrl,
    'base_url': baseUrl,
    'source_code_url': sourceCodeUrl,
    'repo_url': repoUrl,
    'api_url': apiUrl,
    'has_cloudflare': hasCloudflare ? 1 : 0,
    'item_type': itemType,
    'source_code': sourceCode,
    'source_code_language': sourceCodeLanguage,
    'pkg_name': pkgName,
    'version_code': versionCode,
    'signature_hash': signatureHash,
    'is_installed': isInstalled ? 1 : 0,
    'is_active': isActive ? 1 : 0,
    'is_nsfw': isNsfw ? 1 : 0,
    'is_pinned': isPinned ? 1 : 0,
    'is_obsolete': isObsolete ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory ExtensionSource.fromJson(Map<String, dynamic> json) =>
      ExtensionSource(
        id: json['id'] as String? ?? '',
        sourceId: json['sourceId'] as String? ?? json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        version: json['version'] as String? ?? '',
        versionLast: json['version_last'] as String?,
        lang: json['lang'] as String? ?? '',
        apkPath: json['apk_path'] as String? ?? '',
        className: json['class_name'] as String? ?? '',
        iconUrl: json['icon_url'] as String?,
        baseUrl: json['base_url'] as String?,
        sourceCodeUrl: json['source_code_url'] as String?,
        repoUrl: json['repo_url'] as String?,
        apiUrl: json['api_url'] as String?,
        hasCloudflare: (json['has_cloudflare'] as int? ?? 0) == 1 ||
            json['has_cloudflare'] == true,
        itemType: json['item_type'] as String? ?? 'manga',
        sourceCode: json['source_code'] as String? ?? '',
        sourceCodeLanguage:
            json['source_code_language'] as String? ?? SourceCodeLanguage.mihon,
        pkgName: json['pkg_name'] as String? ?? '',
        versionCode: (json['version_code'] as num?)?.toInt() ?? 0,
        signatureHash: json['signature_hash'] as String? ?? '',
        isInstalled: (json['is_installed'] as int? ?? 0) == 1,
        isActive: (json['is_active'] as int? ?? 1) == 1,
        isNsfw: (json['is_nsfw'] as int? ?? 0) == 1,
        isPinned: (json['is_pinned'] as int? ?? 0) == 1,
        isObsolete: (json['is_obsolete'] as int? ?? 0) == 1,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : DateTime.now(),
      );
}

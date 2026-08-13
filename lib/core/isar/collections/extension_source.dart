import 'package:isar_community/isar.dart';

import '../../utils/language.dart';

part 'extension_source.g.dart';

/// One installed Keiyoushi/Mihon APK extension OR a JS extension.
@collection
@Name('ExtensionSource')
class ExtensionSource {
  Id? id;

  /// Bridge cache key (hex for Mihon APKs, catalog pkg id for JS).
  @Index(unique: true, replace: true)
  String sourceId;

  /// Mihon `Source.id` as string (long numeric). Empty for JS.
  /// Persisted so library pills can resolve manga that still store this id.
  String nativeId;

  String name;
  String version;
  String? versionLast;
  String lang;

  /// APK path on disk (Mihon) — empty for JS extensions.
  String apkPath;

  /// Kotlin class name (Mihon) — empty for JS extensions.
  String className;

  String? iconUrl;
  String? baseUrl;
  String? sourceCodeUrl;
  String? repoUrl;

  /// Mangayomi JS API base (e.g. MangaDex). Null/empty when unused.
  String? apiUrl;

  /// Whether the source sits behind Cloudflare (mangayomi).
  bool hasCloudflare;

  /// Product kind: `manga` / `anime` / `novel`. Koma is manga-only UI;
  /// field is persisted for index/JS fidelity.
  String itemType;

  /// JS source body (mangayomi). Empty for Mihon APKs.
  String sourceCode;

  /// Package name from the APK (trust key). Empty until inspected.
  String pkgName;

  /// Package versionCode from the APK.
  int versionCode;

  /// Primary (last) SHA-256 signing fingerprint. Empty until inspected.
  String signatureHash;

  bool isInstalled;
  bool isActive;
  bool isNsfw;
  bool isPinned;
  bool isObsolete;

  /// `mihon` for the native Keiyoushi bridge, `js` for flutter_qjs.
  String sourceCodeLanguage;

  DateTime? createdAt;
  DateTime? updatedAt;

  bool get isUpdateAvailable {
    final latest = versionLast;
    if (latest == null || latest.isEmpty) return false;
    return compareVersions(version, latest) < 0;
  }

  ExtensionSource copyWith({
    Id? id,
    String? sourceId,
    String? nativeId,
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
    String? pkgName,
    int? versionCode,
    String? signatureHash,
    bool? isInstalled,
    bool? isActive,
    bool? isNsfw,
    bool? isPinned,
    bool? isObsolete,
    String? sourceCodeLanguage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExtensionSource(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      nativeId: nativeId ?? this.nativeId,
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
      pkgName: pkgName ?? this.pkgName,
      versionCode: versionCode ?? this.versionCode,
      signatureHash: signatureHash ?? this.signatureHash,
      isInstalled: isInstalled ?? this.isInstalled,
      isActive: isActive ?? this.isActive,
      isNsfw: isNsfw ?? this.isNsfw,
      isPinned: isPinned ?? this.isPinned,
      isObsolete: isObsolete ?? this.isObsolete,
      sourceCodeLanguage: sourceCodeLanguage ?? this.sourceCodeLanguage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  ExtensionSource({
    this.id = Isar.autoIncrement,
    required this.sourceId,
    this.nativeId = '',
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
    this.pkgName = '',
    this.versionCode = 0,
    this.signatureHash = '',
    this.isInstalled = true,
    this.isActive = true,
    this.isNsfw = false,
    this.isPinned = false,
    this.isObsolete = false,
    this.sourceCodeLanguage = 'mihon',
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'source_id': sourceId,
    'native_id': nativeId,
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
    'pkg_name': pkgName,
    'version_code': versionCode,
    'signature_hash': signatureHash,
    'is_installed': isInstalled ? 1 : 0,
    'is_active': isActive ? 1 : 0,
    'is_nsfw': isNsfw ? 1 : 0,
    'is_pinned': isPinned ? 1 : 0,
    'is_obsolete': isObsolete ? 1 : 0,
    'source_code_language': sourceCodeLanguage,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory ExtensionSource.fromJson(Map<String, dynamic> json) =>
      ExtensionSource(
        id: json['id'] as int?,
        sourceId: json['source_id'] as String? ?? '',
        nativeId: json['native_id'] as String? ?? '',
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
        pkgName: json['pkg_name'] as String? ?? '',
        versionCode: (json['version_code'] as num?)?.toInt() ?? 0,
        signatureHash: json['signature_hash'] as String? ?? '',
        isInstalled: (json['is_installed'] as int? ?? 0) == 1,
        isActive: (json['is_active'] as int? ?? 1) == 1,
        isNsfw: (json['is_nsfw'] as int? ?? 0) == 1,
        isPinned: (json['is_pinned'] as int? ?? 0) == 1,
        isObsolete: (json['is_obsolete'] as int? ?? 0) == 1,
        sourceCodeLanguage: json['source_code_language'] as String? ?? 'mihon',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );
}

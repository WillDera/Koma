import 'package:isar_community/isar.dart';

part 'extension_source.g.dart';

/// One installed Keiyoushi/Mihon APK extension OR (future, PHASE 9) a
/// JS extension. The `id` is the native bridge's MD5-based ID for Mihon
/// sources, or a synthetic ID we mint for JS sources.
@collection
@Name('ExtensionSource')
class ExtensionSource {
  Id? id;

  /// Native bridge MD5 ID (Mihon) or synthetic ID (JS). Stored as String
  /// in the existing schema; we use Isar.autoIncrement for the row PK and
  /// keep [sourceId] as the stable logical identifier.
  @Index(unique: true, replace: true)
  String sourceId;

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

  bool isInstalled;
  bool isActive;
  bool isNsfw;
  bool isPinned;
  bool isObsolete;

  /// `mihon` for the native Keiyoushi bridge, `js` for the flutter_qjs
  /// runtime. Added in PHASE 1a (not in the existing Drift schema) so
  /// the unified ExtensionService in PHASE 10 can dispatch correctly.
  /// Default `mihon` matches the existing data.
  String sourceCodeLanguage;

  DateTime? createdAt;
  DateTime? updatedAt;

  bool get isUpdateAvailable => versionLast != null && versionLast != version;

  ExtensionSource copyWith({
    Id? id,
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
        sourceId: json['source_id'] as String? ?? json['id'] as String? ?? '',
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
        isInstalled: (json['is_installed'] as int? ?? 0) == 1,
        isActive: (json['is_active'] as int? ?? 1) == 1,
        isNsfw: (json['is_nsfw'] as int? ?? 0) == 1,
        isPinned: (json['is_pinned'] as int? ?? 0) == 1,
        isObsolete: (json['is_obsolete'] as int? ?? 0) == 1,
        sourceCodeLanguage:
            json['source_code_language'] as String? ?? 'mihon',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );
}

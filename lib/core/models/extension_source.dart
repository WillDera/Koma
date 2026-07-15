class ExtensionSource {
  final String id;
  final String name;
  final String version;
  final String lang;
  final String apkPath;
  final String className;
  final String? iconUrl;
  final bool isInstalled;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExtensionSource({
    required this.id,
    required this.name,
    required this.version,
    required this.lang,
    required this.apkPath,
    required this.className,
    this.iconUrl,
    this.isInstalled = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ExtensionSource copyWith({
    String? id,
    String? name,
    String? version,
    String? lang,
    String? apkPath,
    String? className,
    String? iconUrl,
    bool? isInstalled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExtensionSource(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      lang: lang ?? this.lang,
      apkPath: apkPath ?? this.apkPath,
      className: className ?? this.className,
      iconUrl: iconUrl ?? this.iconUrl,
      isInstalled: isInstalled ?? this.isInstalled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'lang': lang,
        'apk_path': apkPath,
        'class_name': className,
        'icon_url': iconUrl,
        'is_installed': isInstalled ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ExtensionSource.fromJson(Map<String, dynamic> json) => ExtensionSource(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        version: json['version'] as String? ?? '',
        lang: json['lang'] as String? ?? '',
        apkPath: json['apk_path'] as String? ?? '',
        className: json['class_name'] as String? ?? '',
        iconUrl: json['icon_url'] as String?,
        isInstalled: (json['is_installed'] as int? ?? 0) == 1,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : DateTime.now(),
      );
}

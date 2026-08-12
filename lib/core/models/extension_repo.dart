/// Extension ecosystem for a repo index URL.
///
/// `mihon` — Keiyoushi/Mihon APK index (`pkg`/`apk`).
/// `javascript` — mangayomi-style index (`sourceCodeUrl` + `sourceCodeLanguage`).
class ExtensionRepoKind {
  static const mihon = 'mihon';
  static const javascript = 'javascript';

  static bool isKnown(String? v) =>
      v == mihon || v == javascript;
}

class ExtensionRepo {
  final int id;
  final String name;
  final String url;
  final bool enabled;
  final DateTime createdAt;

  /// Mihon store `signingKeyFingerprint` from `repo.json` (lowercase hex).
  /// Empty/null → APKs from this repo require explicit user trust.
  final String? signingKey;

  /// [ExtensionRepoKind.mihon] or [ExtensionRepoKind.javascript].
  final String kind;

  ExtensionRepo({
    int? id,
    required this.name,
    required this.url,
    this.enabled = true,
    DateTime? createdAt,
    this.signingKey,
    this.kind = ExtensionRepoKind.mihon,
  }) : id = id ?? 0,
       createdAt = createdAt ?? DateTime.now();

  bool get isJavascript => kind == ExtensionRepoKind.javascript;
  bool get isMihon => kind == ExtensionRepoKind.mihon;

  ExtensionRepo copyWith({
    int? id,
    String? name,
    String? url,
    bool? enabled,
    DateTime? createdAt,
    String? Function()? signingKey,
    String? kind,
  }) {
    return ExtensionRepo(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      signingKey: signingKey != null ? signingKey() : this.signingKey,
      kind: kind ?? this.kind,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'enabled': enabled ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'signing_key': signingKey,
    'kind': kind,
  };

  factory ExtensionRepo.fromJson(Map<String, dynamic> json) => ExtensionRepo(
    id: json['id'] as int? ?? 0,
    name: json['name'] as String? ?? '',
    url: json['url'] as String? ?? '',
    enabled: (json['enabled'] as int? ?? 0) == 1,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : DateTime.now(),
    signingKey: json['signing_key'] as String?,
    kind: ExtensionRepoKind.isKnown(json['kind'] as String?)
        ? json['kind'] as String
        : ExtensionRepoKind.mihon,
  );
}

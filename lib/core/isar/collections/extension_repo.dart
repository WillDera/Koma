import 'package:isar_community/isar.dart';

part 'extension_repo.g.dart';

@collection
@Name('ExtensionRepo')
class ExtensionRepo {
  Id? id;

  String name;

  @Index(unique: true, replace: true)
  String url;

  bool enabled;
  DateTime? createdAt;

  /// Mihon `meta.signingKeyFingerprint` from sibling `repo.json`.
  String? signingKey;

  /// `mihon` (APK index) or `javascript` (mangayomi JS index).
  String kind;

  ExtensionRepo({
    this.id = Isar.autoIncrement,
    required this.name,
    required this.url,
    this.enabled = true,
    this.createdAt,
    this.signingKey,
    this.kind = 'mihon',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'enabled': enabled ? 1 : 0,
    'created_at': createdAt?.toIso8601String(),
    'signing_key': signingKey,
    'kind': kind,
  };

  factory ExtensionRepo.fromJson(Map<String, dynamic> json) => ExtensionRepo(
    id: json['id'] as int?,
    name: json['name'] as String? ?? '',
    url: json['url'] as String? ?? '',
    enabled: (json['enabled'] as int? ?? 0) == 1,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null,
    signingKey: json['signing_key'] as String?,
    kind: json['kind'] as String? ?? 'mihon',
  );
}

enum SourceType { js, mihon }

class MSource {
  final String id;
  final String sourceId;
  final String name;
  final String lang;
  final String baseUrl;
  final String version;
  final String? sourceCode;
  final String? apkPath;
  final String? className;
  final SourceType sourceType;

  /// Mangayomi JS API base (e.g. MangaDex). Empty when unused.
  final String? apiUrl;

  /// Whether the source sits behind Cloudflare.
  final bool hasCloudflare;

  /// Date parse format injected into the JS runtime.
  final String? dateFormat;

  /// Locale for [dateFormat].
  final String? dateFormatLocale;

  const MSource({
    required this.id,
    required this.sourceId,
    required this.name,
    required this.lang,
    required this.baseUrl,
    this.version = '1.0',
    this.sourceCode,
    this.apkPath,
    this.className,
    this.sourceType = SourceType.mihon,
    this.apiUrl,
    this.hasCloudflare = false,
    this.dateFormat,
    this.dateFormatLocale,
  });

  bool get isJs => sourceType == SourceType.js;

  bool get isNative => sourceType == SourceType.mihon;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceId': sourceId,
    'name': name,
    'lang': lang,
    'baseUrl': baseUrl,
    'version': version,
    if (sourceCode != null) 'sourceCode': sourceCode,
    if (apkPath != null) 'apkPath': apkPath,
    if (className != null) 'className': className,
    'sourceType': sourceType.name,
    if (apiUrl != null) 'apiUrl': apiUrl,
    'hasCloudflare': hasCloudflare,
    if (dateFormat != null) 'dateFormat': dateFormat,
    if (dateFormatLocale != null) 'dateFormatLocale': dateFormatLocale,
  };

  factory MSource.fromJson(Map<String, dynamic> json) => MSource(
    id: json['id'] as String? ?? '',
    sourceId: json['sourceId'] as String? ?? json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    lang: json['lang'] as String? ?? 'en',
    baseUrl: json['baseUrl'] as String? ?? '',
    version: json['version'] as String? ?? '1.0',
    sourceCode: json['sourceCode'] as String?,
    apkPath: json['apkPath'] as String?,
    className: json['className'] as String?,
    sourceType: json['sourceType'] == 'js' ? SourceType.js : SourceType.mihon,
    apiUrl: json['apiUrl'] as String?,
    hasCloudflare: json['hasCloudflare'] == true,
    dateFormat: json['dateFormat'] as String?,
    dateFormatLocale: json['dateFormatLocale'] as String?,
  );

  /// Build from [ExtensionSource] (or any duck-typed object with the same fields).
  factory MSource.fromExtensionSource(dynamic ext) {
    final lang = ext.sourceCodeLanguage as String?;
    final isJs = lang == 'js' || lang == 'javascript';
    final code = ext.sourceCode as String?;
    return MSource(
      id: ext.id as String,
      sourceId: (ext.sourceId as String?) ?? ext.id as String,
      name: ext.name as String,
      lang: (ext.lang as String?) ?? 'en',
      baseUrl: (ext.baseUrl as String?) ?? '',
      version: (ext.version as String?) ?? '1.0',
      sourceCode: (code != null && code.isNotEmpty) ? code : null,
      apkPath: ext.apkPath as String?,
      className: ext.className as String?,
      sourceType: isJs ? SourceType.js : SourceType.mihon,
      apiUrl: ext.apiUrl as String?,
      hasCloudflare: (ext.hasCloudflare as bool?) ?? false,
      // dateFormat* come from the JS mangayomiSources header at inject time.
    );
  }
}

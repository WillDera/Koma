/// User-imported Piper voice (.onnx + config JSON).
class PiperVoice {
  const PiperVoice({
    required this.id,
    required this.displayName,
    required this.onnxFile,
    required this.configFile,
    this.locale,
  });

  final String id;
  final String displayName;

  /// Basename under `{documents}/piper_voices/{id}/`.
  final String onnxFile;
  final String configFile;
  final String? locale;

  Map<String, Object?> toJson() => {
    'id': id,
    'displayName': displayName,
    'onnxFile': onnxFile,
    'configFile': configFile,
    if (locale != null) 'locale': locale,
  };

  factory PiperVoice.fromJson(Map<String, dynamic> json) {
    return PiperVoice(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Piper voice',
      onnxFile: json['onnxFile'] as String? ?? '',
      configFile: json['configFile'] as String? ?? '',
      locale: json['locale'] as String?,
    );
  }
}

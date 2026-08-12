/// One weight of an imported font family.
class CustomFontFace {
  const CustomFontFace({
    required this.relativePath,
    required this.weight,
  });

  /// Path relative to `{documents}/fonts/{id}/`.
  final String relativePath;
  final int weight;

  Map<String, Object?> toJson() => {
    'relativePath': relativePath,
    'weight': weight,
  };

  factory CustomFontFace.fromJson(Map<String, dynamic> json) {
    return CustomFontFace(
      relativePath: json['relativePath'] as String? ?? '',
      weight: json['weight'] as int? ?? 400,
    );
  }
}

/// A user-imported font family registered with Flutter's [FontLoader].
class CustomFont {
  const CustomFont({
    required this.id,
    required this.displayName,
    required this.registeredFamily,
    required this.faces,
  });

  final String id;
  final String displayName;

  /// Family name passed to [FontLoader] and [TextStyle.fontFamily].
  final String registeredFamily;
  final List<CustomFontFace> faces;

  Map<String, Object?> toJson() => {
    'id': id,
    'displayName': displayName,
    'registeredFamily': registeredFamily,
    'faces': faces.map((f) => f.toJson()).toList(),
  };

  factory CustomFont.fromJson(Map<String, dynamic> json) {
    final rawFaces = json['faces'] as List<dynamic>? ?? [];
    return CustomFont(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Custom font',
      registeredFamily: json['registeredFamily'] as String? ?? '',
      faces: rawFaces
          .map((e) => CustomFontFace.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((f) => f.relativePath.isNotEmpty)
          .toList(),
    );
  }
}

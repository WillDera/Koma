/// Safe coercions for JSON / extension-bridge numbers.
///
/// Dart's `jsonDecode` and Kotlin↔HTTP maps often yield [double] for whole
/// numbers (`12.0`). `value as int?` throws — use these helpers instead.
int? asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final t = value.trim();
    return int.tryParse(t) ?? double.tryParse(t)?.toInt();
  }
  return null;
}

int asIntOr(Object? value, [int fallback = 0]) => asInt(value) ?? fallback;

double? asDouble(Object? value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

double asDoubleOr(Object? value, [double fallback = 0]) =>
    asDouble(value) ?? fallback;

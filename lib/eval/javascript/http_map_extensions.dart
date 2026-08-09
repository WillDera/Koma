/// Mangayomi [ToMapExtension] from `eval/javascript/http.dart` — Map helpers
/// shared by Dart filter models and PageUrl JSON parsing.
extension ToMapExtension on Map? {
  Map<String, dynamic>? get toMapStringDynamic {
    return this?.map((key, value) => MapEntry(key.toString(), value));
  }

  Map<String, String>? get toMapStringString {
    return this?.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }
}

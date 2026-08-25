import 'package:isar_community/isar.dart';

part 'source_pref_value.g.dart';

/// Persisted JS/Dart extension preference value (dual-write with PrefsCache).
@collection
@Name('SourcePrefValue')
class SourcePrefValue {
  Id? id;

  /// `sourceId:prefKey` — unique storage slot.
  @Index(unique: true, replace: true)
  String storageKey;

  String sourceId;

  String prefKey;

  /// JSON-encoded typed value (bool, string, list, …).
  String valueJson;

  SourcePrefValue({
    this.id = Isar.autoIncrement,
    required this.storageKey,
    required this.sourceId,
    required this.prefKey,
    required this.valueJson,
  });

  static String composeKey(String sourceId, String prefKey) =>
      '$sourceId:$prefKey';
}

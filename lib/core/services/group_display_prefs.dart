import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How titles appear inside an expanded collection group (and stack cards).
enum GroupDisplayMode {
  overlay,
  coverOnly;

  static GroupDisplayMode fromId(String? id) {
    for (final m in values) {
      if (m.name == id) return m;
    }
    return overlay;
  }
}

/// Persisted display settings for collection groups only — never shared with
/// Library layout (columns / card variant).
class GroupDisplaySettings {
  const GroupDisplaySettings({
    this.columns = 3,
    this.mode = GroupDisplayMode.overlay,
  });

  final int columns;
  final GroupDisplayMode mode;

  GroupDisplaySettings copyWith({
    int? columns,
    GroupDisplayMode? mode,
  }) {
    return GroupDisplaySettings(
      columns: columns ?? this.columns,
      mode: mode ?? this.mode,
    );
  }
}

class GroupDisplayPrefs {
  GroupDisplayPrefs._();

  static const _keyColumns = 'group_display_columns';
  static const _keyMode = 'group_display_mode';

  static Future<GroupDisplaySettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final cols = prefs.getInt(_keyColumns) ?? 3;
    return GroupDisplaySettings(
      columns: cols == 2 ? 2 : 3,
      mode: GroupDisplayMode.fromId(prefs.getString(_keyMode)),
    );
  }

  static Future<void> save(GroupDisplaySettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyColumns, settings.columns == 2 ? 2 : 3);
    await prefs.setString(_keyMode, settings.mode.name);
  }
}

class GroupDisplayNotifier extends AsyncNotifier<GroupDisplaySettings> {
  @override
  Future<GroupDisplaySettings> build() => GroupDisplayPrefs.load();

  Future<void> setSettings(GroupDisplaySettings next) async {
    state = AsyncData(next);
    await GroupDisplayPrefs.save(next);
  }
}

final groupDisplayProvider =
    AsyncNotifierProvider<GroupDisplayNotifier, GroupDisplaySettings>(
  GroupDisplayNotifier.new,
);

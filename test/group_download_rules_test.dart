import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/services/group_download_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('resolveRule', () {
    test('inherit falls through to global off → skip', () {
      expect(
        GroupDownloadRules.resolveRule(
          groupIds: [1],
          globalDownloadNew: false,
          rules: const {1: GroupDownloadRule.inherit},
        ),
        GroupDownloadBehavior.skip,
      );
    });

    test('inherit falls through to global on → downloadAll', () {
      expect(
        GroupDownloadRules.resolveRule(
          groupIds: const [],
          globalDownloadNew: true,
        ),
        GroupDownloadBehavior.downloadAll,
      );
    });

    test('any never → skip (beats always)', () {
      expect(
        GroupDownloadRules.resolveRule(
          groupIds: [1, 2],
          globalDownloadNew: true,
          rules: const {
            1: GroupDownloadRule.always,
            2: GroupDownloadRule.never,
          },
        ),
        GroupDownloadBehavior.skip,
      );
    });

    test('any always → downloadAll', () {
      expect(
        GroupDownloadRules.resolveRule(
          groupIds: [1],
          globalDownloadNew: false,
          rules: const {1: GroupDownloadRule.always},
        ),
        GroupDownloadBehavior.downloadAll,
      );
    });

    test('unreadOnly → downloadUnreadOnly', () {
      expect(
        GroupDownloadRules.resolveRule(
          groupIds: [5],
          globalDownloadNew: false,
          rules: const {5: GroupDownloadRule.unreadOnly},
        ),
        GroupDownloadBehavior.downloadUnreadOnly,
      );
    });

    test('always beats unreadOnly', () {
      expect(
        GroupDownloadRules.resolveRule(
          groupIds: [1, 2],
          globalDownloadNew: false,
          rules: const {
            1: GroupDownloadRule.unreadOnly,
            2: GroupDownloadRule.always,
          },
        ),
        GroupDownloadBehavior.downloadAll,
      );
    });
  });

  group('prefs round-trip', () {
    test('save and load map by group id string', () async {
      SharedPreferences.setMockInitialValues({});
      await GroupDownloadRules.save({
        10: GroupDownloadRule.always,
        20: GroupDownloadRule.never,
      });
      final loaded = await GroupDownloadRules.load();
      expect(loaded[10], GroupDownloadRule.always);
      expect(loaded[20], GroupDownloadRule.never);
      expect(loaded.containsKey(99), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(GroupDownloadRules.prefsKey), isNotNull);
      expect(prefs.getString(GroupDownloadRules.prefsKey), contains('"10"'));
    });

    test('loads legacy category prefs key', () async {
      SharedPreferences.setMockInitialValues({
        GroupDownloadRules.legacyPrefsKey: '{"7":"always"}',
      });
      final loaded = await GroupDownloadRules.load();
      expect(loaded[7], GroupDownloadRule.always);
    });
  });
}

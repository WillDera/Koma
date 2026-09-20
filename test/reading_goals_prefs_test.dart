import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/services/reading_goals_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('defaults', () {
    test('dailyMinutesGoal defaults to 20', () async {
      expect(await ReadingGoalsPrefs.dailyMinutesGoal(), 20);
    });

    test('weeklyDaysGoal defaults to 5', () async {
      expect(await ReadingGoalsPrefs.weeklyDaysGoal(), 5);
    });
  });

  group('persistence', () {
    test('set and get daily / weekly goals', () async {
      await ReadingGoalsPrefs.setDailyMinutesGoal(45);
      await ReadingGoalsPrefs.setWeeklyDaysGoal(3);
      expect(await ReadingGoalsPrefs.dailyMinutesGoal(), 45);
      expect(await ReadingGoalsPrefs.weeklyDaysGoal(), 3);
    });
  });

  group('progress helpers', () {
    test('dailyProgress is minutes / goal', () {
      expect(ReadingGoalsPrefs.dailyProgress(10, goal: 20), 0.5);
      expect(ReadingGoalsPrefs.dailyProgress(40, goal: 20), 2.0);
      expect(ReadingGoalsPrefs.dailyProgress(0), 0.0);
    });

    test('streakMet compares days to goal', () {
      expect(ReadingGoalsPrefs.streakMet(5, 5), isTrue);
      expect(ReadingGoalsPrefs.streakMet(4, 5), isFalse);
      expect(ReadingGoalsPrefs.streakMet(6, 5), isTrue);
    });
  });
}

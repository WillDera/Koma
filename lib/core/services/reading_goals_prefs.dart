import 'package:shared_preferences/shared_preferences.dart';

/// Daily / weekly reading goal prefs and simple progress helpers.
class ReadingGoalsPrefs {
  ReadingGoalsPrefs._();

  static const keyDailyMinutes = 'reading_goals_daily_minutes';
  static const keyWeeklyDays = 'reading_goals_weekly_days';

  static const defaultDailyMinutesGoal = 20;
  static const defaultWeeklyDaysGoal = 5;

  static Future<int> dailyMinutesGoal([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = p.getInt(keyDailyMinutes);
    if (v == null || v <= 0) return defaultDailyMinutesGoal;
    return v;
  }

  static Future<void> setDailyMinutesGoal(int minutes) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(keyDailyMinutes, minutes);
  }

  static Future<int> weeklyDaysGoal([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = p.getInt(keyWeeklyDays);
    if (v == null || v <= 0) return defaultWeeklyDaysGoal;
    return v;
  }

  static Future<void> setWeeklyDaysGoal(int days) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(keyWeeklyDays, days);
  }

  /// Fraction of [goal] completed today (may exceed 1.0).
  static double dailyProgress(int minutesToday, {int? goal}) {
    final g = goal ?? defaultDailyMinutesGoal;
    if (g <= 0) return 0;
    return minutesToday / g;
  }

  /// Whether [daysWithReading] meets the weekly/streak [goal].
  static bool streakMet(int daysWithReading, int goal) =>
      daysWithReading >= goal;
}

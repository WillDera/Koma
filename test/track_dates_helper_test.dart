import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/services/trackers/track_date_utils.dart';

void main() {
  group('TrackDateUtils.toFuzzyDate / fromFuzzyDate', () {
    test('round-trips a calendar day', () {
      final epoch = DateTime(2024, 3, 15).millisecondsSinceEpoch;
      final fuzzy = TrackDateUtils.toFuzzyDate(epoch);
      expect(fuzzy, {'year': 2024, 'month': 3, 'day': 15});
      expect(TrackDateUtils.fromFuzzyDate(fuzzy), epoch);
    });

    test('null and non-positive epoch yield null fuzzy', () {
      expect(TrackDateUtils.toFuzzyDate(null), isNull);
      expect(TrackDateUtils.toFuzzyDate(0), isNull);
      expect(TrackDateUtils.toFuzzyDate(-1), isNull);
    });

    test('fromFuzzyDate ignores missing or zero year', () {
      expect(TrackDateUtils.fromFuzzyDate(null), isNull);
      expect(TrackDateUtils.fromFuzzyDate({'year': 0, 'month': 1, 'day': 1}),
          isNull);
      expect(
        TrackDateUtils.fromFuzzyDate({'year': 2020}),
        DateTime(2020, 1, 1).millisecondsSinceEpoch,
      );
    });

    test('clearFuzzyDate has null components', () {
      final clear = TrackDateUtils.clearFuzzyDate();
      expect(clear['year'], isNull);
      expect(clear['month'], isNull);
      expect(clear['day'], isNull);
    });
  });

  group('TrackDateUtils.toMalDate / fromMalDate', () {
    test('formats YYYY-MM-DD', () {
      final epoch = DateTime(2023, 9, 5).millisecondsSinceEpoch;
      expect(TrackDateUtils.toMalDate(epoch), '2023-09-05');
      expect(TrackDateUtils.fromMalDate('2023-09-05'), epoch);
    });

    test('clear sentinel becomes empty string', () {
      expect(TrackDateUtils.toMalDate(0), '');
      expect(TrackDateUtils.toMalDate(null, forClear: true), '');
      expect(TrackDateUtils.toMalDate(null), isNull);
    });

    test('fromMalDate empty or invalid is null', () {
      expect(TrackDateUtils.fromMalDate(null), isNull);
      expect(TrackDateUtils.fromMalDate(''), isNull);
      expect(TrackDateUtils.fromMalDate('  '), isNull);
      expect(TrackDateUtils.fromMalDate('not-a-date'), isNull);
    });
  });

  group('TrackDateUtils.todayEpochMs / formatDisplay', () {
    test('todayEpochMs is local midnight', () {
      final fixed = DateTime(2026, 9, 19, 14, 30);
      expect(
        TrackDateUtils.todayEpochMs(fixed),
        DateTime(2026, 9, 19).millisecondsSinceEpoch,
      );
    });

    test('formatDisplay', () {
      expect(TrackDateUtils.formatDisplay(null), 'Not set');
      expect(TrackDateUtils.formatDisplay(0), 'Not set');
      final epoch = DateTime(2021, 1, 2).millisecondsSinceEpoch;
      expect(TrackDateUtils.formatDisplay(epoch), '2021-01-02');
    });
  });
}

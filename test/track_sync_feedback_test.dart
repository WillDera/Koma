import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/services/trackers/track_sync_feedback.dart';

void main() {
  group('TrackSyncOutcome', () {
    test('ritualLine prefers synced services', () {
      const outcome = TrackSyncOutcome(
        mangaId: 1,
        chapter: 42,
        syncedNames: ['AniList', 'MAL'],
        failedNames: ['MU'],
      );
      expect(outcome.ritualLine, 'Synced to AniList · MAL · Ch. 42');
      expect(outcome.hasFailure, isTrue);
      expect(outcome.failureToast, "Couldn't sync progress to MU");
    });

    test('ritualLine shows failure when nothing synced', () {
      const outcome = TrackSyncOutcome(
        mangaId: 2,
        chapter: 7,
        syncedNames: [],
        failedNames: ['MAL'],
      );
      expect(outcome.ritualLine, "Couldn't sync to MAL");
      expect(outcome.didAnything, isTrue);
    });

    test('empty outcome has no ritual line', () {
      const outcome = TrackSyncOutcome(
        mangaId: 3,
        chapter: 1,
        syncedNames: [],
        failedNames: [],
      );
      expect(outcome.ritualLine, isNull);
      expect(outcome.failureToast, isNull);
      expect(outcome.didAnything, isFalse);
    });
  });
}

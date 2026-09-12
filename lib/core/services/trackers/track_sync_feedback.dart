import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Result of pushing chapter progress to linked trackers.
class TrackSyncOutcome {
  const TrackSyncOutcome({
    required this.mangaId,
    required this.chapter,
    required this.syncedNames,
    required this.failedNames,
  });

  final int mangaId;
  final int chapter;
  final List<String> syncedNames;
  final List<String> failedNames;

  bool get didAnything => syncedNames.isNotEmpty || failedNames.isNotEmpty;
  bool get hasFailure => failedNames.isNotEmpty;

  /// Quiet line for the chapter transition page.
  String? get ritualLine {
    if (syncedNames.isNotEmpty) {
      final who = syncedNames.join(' · ');
      return 'Synced to $who · Ch. $chapter';
    }
    if (failedNames.isNotEmpty) {
      final who = failedNames.join(' · ');
      return "Couldn't sync to $who";
    }
    return null;
  }

  String? get failureToast {
    if (!hasFailure) return null;
    final who = failedNames.join(', ');
    return "Couldn't sync progress to $who";
  }
}

/// Latest chapter-sync outcome for the manga reader ritual UI.
class LatestTrackSyncNotifier extends Notifier<TrackSyncOutcome?> {
  @override
  TrackSyncOutcome? build() => null;

  void setOutcome(TrackSyncOutcome? outcome) => state = outcome;
}

final latestTrackSyncProvider =
    NotifierProvider<LatestTrackSyncNotifier, TrackSyncOutcome?>(
  LatestTrackSyncNotifier.new,
);

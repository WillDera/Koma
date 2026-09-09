import 'package:isar_community/isar.dart';

part 'track_preference.g.dart';

@collection
@Name('Track Preference')
class TrackPreference {
  /// Sync service id is the primary key (MAL=1, Anilist=2, MangaUpdates=7).
  Id? syncId;

  String? username;
  String? displayName;
  String? avatarUrl;
  String? oAuth;
  String? prefs;
  bool? refreshing;

  TrackPreference({
    this.syncId,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.oAuth,
    this.prefs,
    this.refreshing,
  });
}

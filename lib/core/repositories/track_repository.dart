import 'package:isar_community/isar.dart';

import '../isar/collections/track.dart';
import '../isar/collections/track_preference.dart';

/// Sync IDs match Mihon: MAL=1, Anilist=2, MangaUpdates=7.
class TrackIds {
  static const mal = 1;
  static const anilist = 2;
  static const mangaUpdates = 7;
}

class TrackRepository {
  TrackRepository(this._isar);
  final Isar _isar;

  Future<List<Track>> getTracksForManga(int mangaId) async {
    return _isar.tracks.filter().mangaIdEqualTo(mangaId).findAll();
  }

  Future<Track?> getTrack(int mangaId, int syncId) async {
    return _isar.tracks
        .filter()
        .mangaIdEqualTo(mangaId)
        .syncIdEqualTo(syncId)
        .findFirst();
  }

  Future<int> upsertTrack(Track track) async {
    return _isar.writeTxn(() async {
      if (track.mangaId != null && track.syncId != null) {
        final existing = await _isar.tracks
            .filter()
            .mangaIdEqualTo(track.mangaId!)
            .syncIdEqualTo(track.syncId!)
            .findFirst();
        if (existing != null) {
          track.id = existing.id;
        }
      }
      track.updatedAt = DateTime.now().millisecondsSinceEpoch;
      return _isar.tracks.put(track);
    });
  }

  Future<void> deleteTrack(int id) async {
    await _isar.writeTxn(() => _isar.tracks.delete(id));
  }

  Future<TrackPreference?> getPreference(int syncId) async {
    final byId = await _isar.trackPreferences.get(syncId);
    if (byId != null) return byId;
    // Fallback if a row was written under an unexpected id.
    return _isar.trackPreferences
        .filter()
        .syncIdEqualTo(syncId)
        .findFirst();
  }

  Future<List<TrackPreference>> getAllPreferences() async {
    return _isar.trackPreferences.where().findAll();
  }

  Future<void> savePreference(TrackPreference pref) async {
    final syncId = pref.syncId;
    if (syncId == null) {
      throw StateError('TrackPreference.syncId is required');
    }
    await _isar.writeTxn(() async {
      await _isar.trackPreferences.put(pref);
    });
    final saved = await getPreference(syncId);
    if (saved == null ||
        ((saved.oAuth == null || saved.oAuth!.isEmpty) &&
            (saved.username == null || saved.username!.isEmpty))) {
      throw StateError('Failed to persist tracker login');
    }
  }

  Future<void> clearPreference(int syncId) async {
    await _isar.writeTxn(() => _isar.trackPreferences.delete(syncId));
  }

  Future<bool> isLoggedIn(int syncId) async {
    final pref = await getPreference(syncId);
    if (pref == null) return false;
    return (pref.oAuth != null && pref.oAuth!.isNotEmpty) ||
        (pref.username != null && pref.username!.isNotEmpty);
  }
}

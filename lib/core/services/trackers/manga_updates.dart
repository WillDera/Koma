import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../isar/collections/track.dart';
import '../../isar/collections/track_preference.dart';
import '../../repositories/repositories.dart';
import '../../repositories/track_repository.dart';
import 'base_tracker.dart';

/// MangaUpdates session API (Mihon MangaUpdatesApi shape).
class MangaUpdatesTracker extends BaseTracker {
  MangaUpdatesTracker(this.repos);

  @override
  final Repositories repos;

  @override
  int get syncId => TrackIds.mangaUpdates;

  @override
  String get name => 'MangaUpdates';

  static const _base = 'https://api.mangaupdates.com';
  static const _readingList = 0;
  static const _wishList = 1;

  Future<String?> _sessionToken() async {
    final pref = await tracks.getPreference(syncId);
    if (pref?.oAuth == null) return null;
    try {
      final json = jsonDecode(pref!.oAuth!) as Map<String, dynamic>;
      return json['session_token'] as String?;
    } catch (_) {
      return pref?.oAuth;
    }
  }

  Map<String, String> _authHeaders(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<void> login(String username, String password) async {
    final res = await http.put(
      Uri.parse('$_base/v1/account/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('MangaUpdates login failed (${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final context = body['context'] as Map<String, dynamic>? ?? body;
    final token = context['session_token'] as String? ?? '';
    if (token.isEmpty) throw StateError('No session token from MangaUpdates');

    String? displayName = username;
    try {
      final profile = await http.get(
        Uri.parse('$_base/v1/account/profile'),
        headers: _authHeaders(token),
      );
      if (profile.statusCode == 200) {
        final p = jsonDecode(profile.body) as Map<String, dynamic>;
        displayName = p['username'] as String? ?? username;
      }
    } catch (_) {}

    await tracks.savePreference(
      TrackPreference(
        syncId: syncId,
        username: username,
        displayName: displayName,
        oAuth: jsonEncode({'session_token': token}),
      ),
    );
  }

  @override
  Future<List<TrackSearchResult>> search(String query) async {
    final res = await http.post(
      Uri.parse('$_base/v1/series/search'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'search': query,
        'filter_types': ['drama cd', 'novel'],
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) return const [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>? ?? const [];
    return [
      for (final r in results)
        if (r is Map<String, dynamic>)
          TrackSearchResult(
            mediaId: (r['record']?['series_id'] as num?)?.toInt() ??
                (r['series_id'] as num?)?.toInt() ??
                0,
            title: (r['record']?['title'] as String?) ??
                (r['title'] as String?) ??
                '',
            coverUrl: r['record']?['image']?['url']?['original'] as String? ??
                r['record']?['image']?['url'] as String?,
            summary: r['record']?['description'] as String?,
            totalChapters: (r['record']?['latest_chapter'] as num?)?.toInt(),
            trackingUrl: r['record']?['url'] as String?,
          ),
    ].where((e) => e.mediaId != 0 && e.title.isNotEmpty).toList();
  }

  @override
  Future<Track> bind({
    required int mangaId,
    required TrackSearchResult hit,
    int lastChapterRead = 0,
  }) async {
    final token = await _sessionToken();
    if (token == null) throw StateError('Not logged in to MangaUpdates');

    final status = lastChapterRead > 0 ? _readingList : _wishList;
    final body = [
      {
        'series': {'id': hit.mediaId},
        'list_id': status,
      },
    ];
    await http.post(
      Uri.parse('$_base/v1/lists/series'),
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );

    final track = Track(
      mangaId: mangaId,
      syncId: syncId,
      mediaId: hit.mediaId,
      title: hit.title,
      lastChapterRead: lastChapterRead > 0 ? lastChapterRead : 0,
      totalChapter: hit.totalChapters,
      status: lastChapterRead > 0
          ? TrackStatus.reading
          : TrackStatus.planToRead,
      trackingUrl: hit.trackingUrl,
      score: 0,
    );
    await tracks.upsertTrack(track);
    return track;
  }

  @override
  Future<void> updateProgress(Track track, int lastChapterRead) async {
    final token = await _sessionToken();
    if (token == null) return;
    final mediaId = track.mediaId;
    if (mediaId == null) return;

    final body = [
      {
        'series': {'id': mediaId},
        'list_id': _readingList,
        'status': {'chapter': lastChapterRead},
      },
    ];
    await http.post(
      Uri.parse('$_base/v1/lists/series/update'),
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );
    track.lastChapterRead = lastChapterRead;
    track.status = TrackStatus.reading;
    await tracks.upsertTrack(track);
  }
}

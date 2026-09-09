import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../isar/collections/track.dart';
import '../../isar/collections/track_preference.dart';
import '../../repositories/repositories.dart';
import '../../repositories/track_repository.dart';
import 'base_tracker.dart';

/// MyAnimeList PKCE OAuth (redirect `koma://mal-auth`).
class MyAnimeListTracker extends BaseTracker {
  MyAnimeListTracker(this.repos);

  @override
  final Repositories repos;

  @override
  int get syncId => TrackIds.mal;

  @override
  String get name => 'MyAnimeList';

  static const clientIdKey = 'tracker_mal_client_id';
  static const redirectUri = 'koma://mal-auth';
  static const _authUrl = 'https://myanimelist.net/v1/oauth2/authorize';
  static const _tokenUrl = 'https://myanimelist.net/v1/oauth2/token';
  static const _api = 'https://api.myanimelist.net/v2';

  Future<String> _clientId() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(clientIdKey) ?? '').trim();
  }

  Future<Map<String, dynamic>?> _oauth() async {
    final pref = await tracks.getPreference(syncId);
    if (pref?.oAuth == null) return null;
    try {
      return jsonDecode(pref!.oAuth!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _accessToken() async {
    final oauth = await _oauth();
    return oauth?['access_token'] as String?;
  }

  static String _randomString(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<void> login() async {
    final clientId = await _clientId();
    if (clientId.isEmpty) {
      throw StateError('Set MyAnimeList client id in Settings → Tracking first');
    }
    final verifier = _randomString(64);
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');

    final authUri = Uri.parse(_authUrl).replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': clientId,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'redirect_uri': redirectUri,
      },
    );
    final result = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: 'koma',
    );
    final code = Uri.parse(result).queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw StateError('MyAnimeList auth cancelled');
    }

    final tokenRes = await http.post(
      Uri.parse(_tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'code': code,
        'code_verifier': verifier,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
      },
    );
    if (tokenRes.statusCode < 200 || tokenRes.statusCode >= 300) {
      throw StateError('MAL token exchange failed (${tokenRes.statusCode})');
    }
    final tokenJson = jsonDecode(tokenRes.body) as Map<String, dynamic>;
    final access = tokenJson['access_token'] as String? ?? '';
    if (access.isEmpty) throw StateError('No MAL access token');

    String? displayName;
    try {
      final me = await http.get(
        Uri.parse('$_api/users/@me'),
        headers: {'Authorization': 'Bearer $access'},
      );
      if (me.statusCode == 200) {
        displayName =
            (jsonDecode(me.body) as Map<String, dynamic>)['name'] as String?;
      }
    } catch (_) {}

    await tracks.savePreference(
      TrackPreference(
        syncId: TrackIds.mal,
        username: displayName,
        displayName: displayName,
        oAuth: jsonEncode(tokenJson),
      ),
    );
  }

  @override
  Future<List<TrackSearchResult>> search(String query) async {
    final token = await _accessToken();
    if (token == null) throw StateError('Not logged in to MyAnimeList');
    final uri = Uri.parse('$_api/manga').replace(
      queryParameters: {
        'q': query,
        'limit': '20',
        'fields': 'id,title,main_picture,synopsis,num_chapters',
      },
    );
    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) return const [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? const [];
    return [
      for (final row in data)
        if (row is Map<String, dynamic>)
          TrackSearchResult(
            mediaId: (row['node']?['id'] as num?)?.toInt() ?? 0,
            title: row['node']?['title'] as String? ?? '',
            coverUrl: row['node']?['main_picture']?['medium'] as String? ??
                row['node']?['main_picture']?['large'] as String?,
            summary: row['node']?['synopsis'] as String?,
            totalChapters: (row['node']?['num_chapters'] as num?)?.toInt(),
            trackingUrl: row['node']?['id'] != null
                ? 'https://myanimelist.net/manga/${row['node']['id']}'
                : null,
          ),
    ].where((e) => e.mediaId != 0 && e.title.isNotEmpty).toList();
  }

  @override
  Future<Track> bind({
    required int mangaId,
    required TrackSearchResult hit,
    int lastChapterRead = 0,
  }) async {
    final token = await _accessToken();
    if (token == null) throw StateError('Not logged in to MyAnimeList');

    final status = lastChapterRead > 0 ? 'reading' : 'plan_to_read';
    await http.put(
      Uri.parse('$_api/manga/${hit.mediaId}/my_list_status'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'status': status,
        'num_chapters_read': '$lastChapterRead',
      },
    );

    final track = Track(
      mangaId: mangaId,
      syncId: syncId,
      mediaId: hit.mediaId,
      title: hit.title,
      lastChapterRead: lastChapterRead,
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
    final token = await _accessToken();
    if (token == null) return;
    final mediaId = track.mediaId;
    if (mediaId == null) return;

    await http.put(
      Uri.parse('$_api/manga/$mediaId/my_list_status'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'status': 'reading',
        'num_chapters_read': '$lastChapterRead',
      },
    );
    track.lastChapterRead = lastChapterRead;
    track.status = TrackStatus.reading;
    await tracks.upsertTrack(track);
  }
}

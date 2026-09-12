import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../isar/collections/track.dart';
import '../../isar/collections/track_preference.dart';
import '../../repositories/repositories.dart';
import '../../repositories/track_repository.dart';
import 'base_tracker.dart';

/// MyAnimeList PKCE OAuth (redirect `koma://mal-auth`).
///
/// MAL currently supports **only** the PKCE `plain` method — the code
/// challenge must equal the code verifier (not S256).
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

  /// PKCE code_verifier: 43–128 chars from the unreserved set.
  static String _randomVerifier([int length = 128]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rnd = Random.secure();
    final n = length.clamp(43, 128);
    return List.generate(n, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  static Future<void>? _loginInFlight;

  Future<void> login() async {
    final existing = _loginInFlight;
    if (existing != null) {
      await existing;
      return;
    }
    final done = _loginImpl();
    _loginInFlight = done;
    try {
      await done;
    } finally {
      if (identical(_loginInFlight, done)) {
        _loginInFlight = null;
      }
    }
  }

  Future<void> _loginImpl() async {
    if (await isLoggedIn()) return;
    final clientId = await _clientId();
    if (clientId.isEmpty) {
      throw StateError(
        'Set MyAnimeList client id in Settings → Tracking first. '
        'Register at myanimelist.net/apiconfig with App Redirect URL '
        'exactly: $redirectUri',
      );
    }
    // MAL only supports PKCE "plain": challenge == verifier.
    final verifier = _randomVerifier();
    final challenge = verifier;

    final authUri = Uri.parse(_authUrl).replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': clientId,
        'code_challenge': challenge,
        'code_challenge_method': 'plain',
        'redirect_uri': redirectUri,
      },
    );
    final result = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: 'koma',
      // iOS: preferEphemeral hides the shared Safari session.
      // Android: do NOT pass ephemeralIntentFlags — FLAG_ACTIVITY_NO_HISTORY
      // keeps the Custom Tab from closing cleanly after koma:// redirect.
      options: const FlutterWebAuth2Options(
        preferEphemeral: true,
      ),
    );
    final code = Uri.parse(result).queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw StateError('MyAnimeList auth cancelled');
    }

    late final http.Response tokenRes;
    try {
      tokenRes = await http.post(
        Uri.parse(_tokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'client_id': clientId,
          'code': code,
          'code_verifier': verifier,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri,
        },
      );
    } on SocketException catch (e) {
      throw StateError(
        'Could not reach myanimelist.net ($e). '
        'Check network/DNS, then try again.',
      );
    } on http.ClientException catch (e) {
      throw StateError(
        'Could not reach myanimelist.net ($e). '
        'Check network/DNS, then try again.',
      );
    }
    if (tokenRes.statusCode < 200 || tokenRes.statusCode >= 300) {
      String detail = tokenRes.body.trim();
      try {
        final err = jsonDecode(tokenRes.body) as Map<String, dynamic>;
        detail = (err['message'] as String?) ??
            (err['hint'] as String?) ??
            (err['error_description'] as String?) ??
            (err['error'] as String?) ??
            detail;
      } catch (_) {}
      if (detail.length > 180) detail = '${detail.substring(0, 180)}…';
      throw StateError(
        'MAL token exchange failed (${tokenRes.statusCode}): $detail. '
        'Confirm client id and App Redirect URL is exactly $redirectUri',
      );
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

  Future<TrackerRecPage> recommendations({
    int limit = 24,
    int offset = 0,
  }) async {
    final token = await _accessToken();
    if (token == null) {
      return const TrackerRecPage(items: [], reachedEnd: true);
    }
    final uri = Uri.parse('$_api/manga/suggestions').replace(
      queryParameters: {
        'limit': '$limit',
        'offset': '$offset',
        'fields': 'id,title,main_picture,synopsis,num_chapters',
      },
    );
    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return const TrackerRecPage(items: [], reachedEnd: true);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? const [];
    final items = [
      for (final row in data)
        if (row is Map<String, dynamic>)
          TrackSearchResult(
            mediaId: (row['node']?['id'] as num?)?.toInt() ?? 0,
            title: row['node']?['title'] as String? ?? '',
            coverUrl: row['node']?['main_picture']?['large'] as String? ??
                row['node']?['main_picture']?['medium'] as String?,
            summary: row['node']?['synopsis'] as String?,
            totalChapters: (row['node']?['num_chapters'] as num?)?.toInt(),
            trackingUrl: row['node']?['id'] != null
                ? 'https://myanimelist.net/manga/${row['node']['id']}'
                : null,
          ),
    ].where((e) => e.mediaId != 0 && e.title.isNotEmpty).toList();
    return TrackerRecPage(
      items: items,
      reachedEnd: data.isEmpty || data.length < limit,
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

  @override
  Future<TrackerMediaDetails?> fetchMediaDetails(int mediaId) async {
    final token = await _accessToken();
    if (token == null) return null;
    final uri = Uri.parse('$_api/manga/$mediaId').replace(
      queryParameters: {
        'fields':
            'id,title,main_picture,alternative_titles,start_date,media_type,'
            'status,mean,num_list_users,num_favorites,genres,num_chapters,'
            'synopsis,source',
      },
    );
    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final alt = body['alternative_titles'] as Map<String, dynamic>? ?? const {};
    final synonyms = <String>[
      for (final s in (alt['synonyms'] as List<dynamic>? ?? const []))
        if ('$s'.isNotEmpty) '$s',
    ];
    final genres = <String>[
      for (final g in (body['genres'] as List<dynamic>? ?? const []))
        if (g is Map && (g['name'] as String?)?.isNotEmpty == true)
          g['name'] as String,
    ];
    DateTime? startDate;
    final startRaw = body['start_date'] as String?;
    if (startRaw != null && startRaw.isNotEmpty) {
      startDate = DateTime.tryParse(startRaw);
    }
    final mean = (body['mean'] as num?)?.toDouble();
    final meanPct = mean == null ? null : (mean * 10).round();
    return TrackerMediaDetails(
      format: body['media_type'] as String?,
      publicationStatus: body['status'] as String?,
      startDate: startDate,
      averageScore: meanPct,
      meanScore: meanPct,
      popularity: (body['num_list_users'] as num?)?.toInt(),
      favourites: (body['num_favorites'] as num?)?.toInt(),
      source: null,
      genres: genres,
      tags: const [],
      romajiTitle: null,
      englishTitle: alt['en'] as String?,
      nativeTitle: alt['ja'] as String?,
      synonyms: synonyms,
      coverUrl: body['main_picture']?['large'] as String? ??
          body['main_picture']?['medium'] as String?,
      trackingUrl: 'https://myanimelist.net/manga/$mediaId',
      totalChapters: (body['num_chapters'] as num?)?.toInt(),
    );
  }

  @override
  Future<void> updateScore(Track track, int score) async {
    final token = await _accessToken();
    if (token == null) throw StateError('Not logged in to MyAnimeList');
    final mediaId = track.mediaId;
    if (mediaId == null) throw StateError('MAL track missing media id');
    final malScore = score.clamp(0, 10);
    await http.put(
      Uri.parse('$_api/manga/$mediaId/my_list_status'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'score': '$malScore'},
    );
    track.score = malScore;
    await tracks.upsertTrack(track);
  }

  @override
  Future<List<TrackerReview>> listReviews(int mediaId) async {
    // MAL public reviews API is limited; return empty and rely on score UI.
    return const [];
  }

  @override
  Future<TrackerReview?> upsertReview({
    required int mediaId,
    required String body,
    String? title,
    int? score,
    int? existingReviewId,
  }) async {
    // MAL does not expose a simple create-review endpoint for mobile OAuth
    // apps in the same way as AniList — score via updateScore instead.
    return null;
  }
}

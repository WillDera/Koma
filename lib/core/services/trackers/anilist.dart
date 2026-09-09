import 'dart:convert';

import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../isar/collections/track.dart';
import '../../isar/collections/track_preference.dart';
import '../../repositories/repositories.dart';
import '../../repositories/track_repository.dart';
import 'base_tracker.dart';

/// AniList GraphQL + OAuth (redirect `koma://anilist-auth`).
class AnilistTracker extends BaseTracker {
  AnilistTracker(this.repos);

  @override
  final Repositories repos;

  @override
  int get syncId => TrackIds.anilist;

  @override
  String get name => 'AniList';

  static const clientIdKey = 'tracker_anilist_client_id';
  static const clientSecretKey = 'tracker_anilist_client_secret';
  static const redirectUri = 'koma://anilist-auth';
  static const _tokenUrl = 'https://anilist.co/api/v2/oauth/token';
  static const _authUrl = 'https://anilist.co/api/v2/oauth/authorize';
  static const _graphql = 'https://graphql.anilist.co';

  Future<({String id, String secret})> _clientCreds() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      id: (prefs.getString(clientIdKey) ?? '').trim(),
      secret: (prefs.getString(clientSecretKey) ?? '').trim(),
    );
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

  Future<void> login() async {
    final creds = await _clientCreds();
    if (creds.id.isEmpty || creds.secret.isEmpty) {
      throw StateError(
        'Set AniList client id/secret in Settings → Tracking first. '
        'Register at anilist.co/settings/developer with Redirect URL '
        'exactly: $redirectUri',
      );
    }
    final authUri = Uri.parse(_authUrl).replace(
      queryParameters: {
        'client_id': creds.id,
        'redirect_uri': redirectUri,
        'response_type': 'code',
      },
    );
    final result = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: 'koma',
    );
    final code = Uri.parse(result).queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw StateError('AniList auth cancelled');
    }

    final tokenRes = await http.post(
      Uri.parse(_tokenUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'grant_type': 'authorization_code',
        'client_id': creds.id,
        'client_secret': creds.secret,
        'redirect_uri': redirectUri,
        'code': code,
      }),
    );
    if (tokenRes.statusCode < 200 || tokenRes.statusCode >= 300) {
      String detail = tokenRes.body;
      try {
        final err = jsonDecode(tokenRes.body) as Map<String, dynamic>;
        detail = (err['message'] as String?) ??
            (err['error'] as String?) ??
            detail;
      } catch (_) {}
      throw StateError(
        'AniList token exchange failed: $detail. '
        'Confirm client id/secret and Redirect URL is exactly $redirectUri',
      );
    }
    final tokenJson = jsonDecode(tokenRes.body) as Map<String, dynamic>;
    final access = tokenJson['access_token'] as String? ?? '';
    if (access.isEmpty) throw StateError('No AniList access token');

    String? viewerId;
    String? displayName;
    try {
      final viewer = await _gql(
        access,
        '{ Viewer { id name } }',
      );
      final v = viewer['data']?['Viewer'] as Map<String, dynamic>?;
      viewerId = '${v?['id'] ?? ''}';
      displayName = v?['name'] as String?;
    } catch (_) {}

    await tracks.savePreference(
      TrackPreference(
        syncId: TrackIds.anilist,
        username: (viewerId != null && viewerId.isNotEmpty) ? viewerId : null,
        displayName: displayName,
        oAuth: jsonEncode(tokenJson),
      ),
    );
  }

  Future<Map<String, dynamic>> _gql(
    String token,
    String query, {
    Map<String, dynamic>? variables,
  }) async {
    final res = await http.post(
      Uri.parse(_graphql),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'query': query,
        if (variables != null) 'variables': variables,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('AniList GraphQL failed (${res.statusCode}): ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      final msg = first is Map
          ? (first['message'] as String? ?? '$first')
          : '$first';
      throw StateError('AniList GraphQL error: $msg');
    }
    return body;
  }

  Future<TrackerRecPage> recommendations({
    int limit = 24,
    int page = 1,
  }) async {
    final token = await _accessToken();
    if (token == null) {
      return const TrackerRecPage(items: [], reachedEnd: true);
    }
    final body = await _gql(
      token,
      r'''
        query ($page: Int, $perPage: Int) {
          Page(page: $page, perPage: $perPage) {
            pageInfo { hasNextPage }
            recommendations(sort: RATING_DESC, onList: false) {
              mediaRecommendation {
                id
                type
                title { userPreferred romaji english }
                coverImage { large medium }
                siteUrl
                chapters
              }
            }
          }
        }
      ''',
      variables: {'page': page, 'perPage': limit},
    );
    final pageData = body['data']?['Page'] as Map<String, dynamic>?;
    final pageInfo = pageData?['pageInfo'] as Map<String, dynamic>?;
    final hasNext = pageInfo?['hasNextPage'] as bool? ?? false;
    final rows = pageData?['recommendations'] as List<dynamic>? ?? const [];
    final out = <TrackSearchResult>[];
    final seen = <int>{};
    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final media = row['mediaRecommendation'] as Map<String, dynamic>?;
      if (media == null) continue;
      if ((media['type'] as String?) != 'MANGA') continue;
      final id = (media['id'] as num?)?.toInt() ?? 0;
      if (id == 0 || !seen.add(id)) continue;
      final titleMap = media['title'] as Map<String, dynamic>? ?? const {};
      final title = (titleMap['userPreferred'] as String?)?.trim().isNotEmpty ==
              true
          ? titleMap['userPreferred'] as String
          : (titleMap['english'] as String?)?.trim().isNotEmpty == true
          ? titleMap['english'] as String
          : (titleMap['romaji'] as String? ?? '');
      if (title.isEmpty) continue;
      final cover = media['coverImage'] as Map<String, dynamic>?;
      out.add(
        TrackSearchResult(
          mediaId: id,
          title: title,
          coverUrl: cover?['large'] as String? ?? cover?['medium'] as String?,
          totalChapters: (media['chapters'] as num?)?.toInt(),
          trackingUrl: media['siteUrl'] as String?,
        ),
      );
    }
    return TrackerRecPage(
      items: out,
      // Empty raw page or no further pages — not “zero manga on this page”.
      reachedEnd: rows.isEmpty || !hasNext,
    );
  }

  @override
  Future<List<TrackSearchResult>> search(String query) async {
    final token = await _accessToken();
    // Search works without auth; prefer token when present.
    final res = await http.post(
      Uri.parse(_graphql),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'query': r'''
          query ($search: String) {
            Page(page: 1, perPage: 20) {
              media(search: $search, type: MANGA) {
                id
                title { userPreferred romaji english }
                coverImage { large }
                description
                chapters
                siteUrl
              }
            }
          }
        ''',
        'variables': {'search': query},
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) return const [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final media =
        body['data']?['Page']?['media'] as List<dynamic>? ?? const [];
    return [
      for (final m in media)
        if (m is Map<String, dynamic>)
          TrackSearchResult(
            mediaId: (m['id'] as num).toInt(),
            title: (m['title']?['userPreferred'] as String?) ??
                (m['title']?['romaji'] as String?) ??
                (m['title']?['english'] as String?) ??
                '',
            coverUrl: m['coverImage']?['large'] as String?,
            summary: m['description'] as String?,
            totalChapters: (m['chapters'] as num?)?.toInt(),
            trackingUrl: m['siteUrl'] as String?,
          ),
    ].where((e) => e.title.isNotEmpty).toList();
  }

  @override
  Future<Track> bind({
    required int mangaId,
    required TrackSearchResult hit,
    int lastChapterRead = 0,
  }) async {
    final token = await _accessToken();
    if (token == null) throw StateError('Not logged in to AniList');

    final status = lastChapterRead > 0 ? 'CURRENT' : 'PLANNING';
    final result = await _gql(
      token,
      r'''
        mutation ($mediaId: Int, $progress: Int, $status: MediaListStatus) {
          SaveMediaListEntry(mediaId: $mediaId, progress: $progress, status: $status) {
            id
            mediaId
            status
            progress
          }
        }
      ''',
      variables: {
        'mediaId': hit.mediaId,
        'progress': lastChapterRead,
        'status': status,
      },
    );
    final entry = result['data']?['SaveMediaListEntry'] as Map<String, dynamic>?;
    final track = Track(
      mangaId: mangaId,
      syncId: syncId,
      mediaId: hit.mediaId,
      libraryId: (entry?['id'] as num?)?.toInt(),
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
    if (token == null) {
      throw StateError('Not logged in to AniList');
    }
    final mediaId = track.mediaId;
    final libraryId = track.libraryId;
    if (mediaId == null && libraryId == null) {
      throw StateError('AniList track missing media id');
    }

    // Prefer list-entry id when we have it; otherwise save by mediaId.
    final result = await _gql(
      token,
      libraryId != null
          ? r'''
        mutation ($id: Int, $progress: Int, $status: MediaListStatus) {
          SaveMediaListEntry(id: $id, progress: $progress, status: $status) {
            id
            progress
            mediaId
          }
        }
      '''
          : r'''
        mutation ($mediaId: Int, $progress: Int, $status: MediaListStatus) {
          SaveMediaListEntry(mediaId: $mediaId, progress: $progress, status: $status) {
            id
            progress
            mediaId
          }
        }
      ''',
      variables: {
        if (libraryId != null) 'id': libraryId,
        if (libraryId == null) 'mediaId': mediaId,
        'progress': lastChapterRead,
        'status': 'CURRENT',
      },
    );
    final entry = result['data']?['SaveMediaListEntry'] as Map<String, dynamic>?;
    track.lastChapterRead = lastChapterRead;
    track.status = TrackStatus.reading;
    final entryId = (entry?['id'] as num?)?.toInt();
    if (entryId != null) track.libraryId = entryId;
    await tracks.upsertTrack(track);
  }
}

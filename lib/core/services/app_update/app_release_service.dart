import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_release.dart';
import 'get_application_release.dart';

/// Fetches the latest GitHub release (Mihon [ReleaseServiceImpl] parity).
class AppReleaseService {
  AppReleaseService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// GitHub username mentions in release notes → markdown links (Mihon parity).
  static final _gitHubUsernameMention = RegExp(
    r'\B@([a-z0-9](?:-(?=[a-z0-9])|[a-z0-9]){0,38}(?<=[a-z0-9]))',
    caseSensitive: false,
  );

  Future<AppRelease?> latest(AppUpdateArguments arguments) async {
    final uri = Uri.parse(
      'https://api.github.com/repos/${arguments.repository}/releases/latest',
    );
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'Koma-AppUpdate',
      },
    );
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) return null;

    final version = json['tag_name'] as String? ?? '';
    final infoRaw = json['body'] as String? ?? '';
    final releaseLink = json['html_url'] as String? ?? '';
    final assets = json['assets'];
    if (version.isEmpty || assets is! List) return null;

    final downloadLink = pickApkUrl(assets);
    if (downloadLink == null) return null;

    final info = infoRaw
        .split('<!-->')
        .first
        .replaceAllMapped(_gitHubUsernameMention, (m) {
          final mention = m.group(0)!;
          return '[$mention](https://github.com/${mention.substring(1)})';
        });

    return AppRelease(
      version: version,
      info: info,
      releaseLink: releaseLink,
      downloadLink: downloadLink,
    );
  }

  /// Prefer a versioned `koma-*.apk`, then `app-release.apk`, else any `.apk`.
  static String? pickApkUrl(List<dynamic> assets) {
    String? versioned;
    String? releaseNamed;
    String? fallback;
    for (final raw in assets) {
      if (raw is! Map) continue;
      final name = raw['name'] as String? ?? '';
      final url = raw['browser_download_url'] as String? ?? '';
      if (!name.toLowerCase().endsWith('.apk') || url.isEmpty) continue;
      final lower = name.toLowerCase();
      if (lower.startsWith('koma-')) {
        versioned ??= url;
      } else if (lower == 'app-release.apk') {
        releaseNamed ??= url;
      } else {
        fallback ??= url;
      }
    }
    return versioned ?? releaseNamed ?? fallback;
  }
}

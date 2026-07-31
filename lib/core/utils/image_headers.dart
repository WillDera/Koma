import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/http/m_client.dart';

/// Returns image request headers for a manga source identified by [baseUrl].
///
/// The source's [baseUrl] is used as the `Referer` header — most image CDNs
/// require a Referer matching the source site to serve content. A browser-like
/// [User-Agent] is always included. If [baseUrl] is null or empty only the
/// User-Agent is returned.
///
/// Cookies are NOT injected here: [MCookieManager] (via `MClient.init`) adds
/// the stored `Cookie` header at request time, so a freshly-solved
/// `cf_clearance` cookie is always picked up on the retry (mangayomi parity).
final imageHeadersProvider = Provider.family<Map<String, String>, String?>((
  ref,
  baseUrl,
) {
  final headers = <String, String>{'User-Agent': kBrowserUserAgent};
  if (baseUrl != null && baseUrl.isNotEmpty) {
    headers['Referer'] = baseUrl;
  }
  return headers;
});

/// Resolves [sourceId] to an [ExtensionSource] from Isar and returns image
/// request headers (Referer from baseUrl + User-Agent). Returns only
/// User-Agent when the source is not found.
///
/// Use this in display sites that only have a [sourceId] (library, history,
/// discover manga cards). Sites that already have the source object should
/// read [imageHeadersProvider] directly with the source's [baseUrl].
final sourceImageHeadersProvider =
    FutureProvider.family<Map<String, String>, String>((ref, sourceId) async {
      final repos = ref.read(repositoriesProvider);
      final source = await repos.extensions.getBySourceId(sourceId);
      final baseUrl = source?.baseUrl;
      final headers = <String, String>{'User-Agent': kBrowserUserAgent};
      if (baseUrl != null && baseUrl.isNotEmpty) {
        headers['Referer'] = baseUrl;
      }
      return headers;
    });

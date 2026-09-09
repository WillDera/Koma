import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/extensions/extensions_catalog_provider.dart';
import '../../router/router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dialog_sheet.dart';
import '../../widgets/toast.dart';
import '../models/extension_repo.dart';
import '../providers.dart';

/// Handles `mangayomi://add-repo`, `koma://add-repo`, `tachiyomi://add-repo`,
/// and `mihon://add-repo|extension-store` so Install buttons on sites like
/// [Wotaku](https://wotaku.wiki/ext/mangayomi) can open Koma.
class ExtensionRepoDeepLinkListener {
  ExtensionRepoDeepLinkListener._();

  static const _channel = MethodChannel('com.koma.koma/deep_link');
  static ProviderContainer? _container;
  static String? _lastUri;

  static void init(ProviderContainer container) {
    _container = container;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final link = (call.arguments as String?)?.trim() ?? '';
        if (link.isNotEmpty) unawaited(_handle(link));
      }
      return null;
    });
    unawaited(_consumeInitial());
  }

  static Future<void> _consumeInitial() async {
    try {
      final link =
          (await _channel.invokeMethod<String>('getInitialDeepLink'))?.trim() ??
          '';
      if (link.isNotEmpty) await _handle(link);
    } catch (_) {}
  }

  static Future<void> _handle(String link) async {
    if (link == _lastUri) return;
    _lastUri = link;
    final uri = Uri.tryParse(link);
    if (uri == null) return;

    // OAuth redirects are consumed by flutter_web_auth_2; ignore here so we
    // don't toast "No manga extension index".
    final host = uri.host.toLowerCase();
    if (uri.scheme.toLowerCase() == 'koma' &&
        (host == 'anilist-auth' || host == 'mal-auth')) {
      return;
    }

    final offer = _parse(uri);
    if (offer == null || offer.indexUrls.isEmpty) {
      _toast('No manga extension index found in that link');
      return;
    }

    final ctx = await _waitForContext();
    if (ctx == null || !ctx.mounted) return;

    final confirmed = await StashDialog.show<bool>(
      ctx,
      title: 'Add extension repository',
      content:
          '${offer.name}\n\n'
          '${offer.indexUrls.map((u) => '• $u').join('\n')}',
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx, rootNavigator: false).pop(false),
          child: Text(
            'Cancel',
            style: TextStyle(color: ctx.colors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx, rootNavigator: false).pop(true),
          child: Text('Add', style: TextStyle(color: ctx.colors.accent)),
        ),
      ],
    );
    if (confirmed != true) return;

    final container = _container;
    if (container == null) return;
    final mgr = container.read(extensionManagerProvider);
    final existing = await mgr.listRepos();
    final existingUrls = {
      for (final r in existing) r.url.trim().toLowerCase(),
    };

    var added = 0;
    for (final rawUrl in offer.indexUrls) {
      final url = rawUrl.trim();
      if (url.isEmpty) continue;
      final key = url.toLowerCase();
      if (existingUrls.contains(key) ||
          existingUrls.contains('$key/') ||
          (key.endsWith('/') &&
              existingUrls.contains(key.substring(0, key.length - 1)))) {
        continue;
      }
      try {
        await mgr.addRepo(
          name: offer.name,
          url: url,
          kind: offer.kind,
        );
        existingUrls.add(key);
        added++;
      } catch (e) {
        if (kDebugMode) debugPrint('addRepo failed $url → $e');
      }
    }

    // Land on Available so the user can install sources from the new repo.
    await appRouter.pushNamed(Routes.extensions, extra: 1);
    try {
      await container.read(extensionsCatalogProvider.notifier).refreshInstalled();
      unawaited(
        container.read(extensionsCatalogProvider.notifier).fetchAllIndexes(),
      );
    } catch (_) {}

    // Toast after navigation so the Overlay under the navigator exists.
    await Future<void>.delayed(Duration.zero);
    if (added == 0) {
      _toast('Repository already added');
    } else {
      _toast(added == 1 ? 'Repository added' : 'Added $added repositories');
    }
  }

  static _RepoOffer? _parse(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();

    // Mangayomi / Koma:
    // mangayomi://add-repo?repo_name=…&manga_url=…&novel_url=…
    if ((scheme == 'mangayomi' || scheme == 'koma') && host == 'add-repo') {
      final name = uri.queryParameters['repo_name']?.trim().isNotEmpty == true
          ? uri.queryParameters['repo_name']!.trim()
          : 'Mangayomi repo';
      final urls = <String>[
        ...?uri.queryParametersAll['manga_url'],
        // Novel indexes are the same JS catalog shape; anime is skipped.
        ...?uri.queryParametersAll['novel_url'],
      ];
      // Some older links only pass a generic url=.
      final fallback = uri.queryParameters['url']?.trim();
      if (fallback != null && fallback.isNotEmpty) urls.add(fallback);
      return _RepoOffer(
        name: name,
        indexUrls: _dedupe(urls),
        kind: ExtensionRepoKind.javascript,
      );
    }

    // Mihon / Tachiyomi: tachiyomi://add-repo?url=…  mihon://extension-store?url=…
    if ((scheme == 'tachiyomi' && host == 'add-repo') ||
        (scheme == 'mihon' &&
            (host == 'add-repo' || host == 'extension-store'))) {
      final urls = <String>[
        ...?uri.queryParametersAll['url'],
      ];
      final name = uri.queryParameters['name']?.trim().isNotEmpty == true
          ? uri.queryParameters['name']!.trim()
          : 'Mihon repo';
      return _RepoOffer(
        name: name,
        indexUrls: _dedupe(urls),
        kind: ExtensionRepoKind.mihon,
      );
    }

    return null;
  }

  static List<String> _dedupe(List<String> urls) {
    final out = <String>[];
    final seen = <String>{};
    for (final u in urls) {
      final t = u.trim();
      if (t.isEmpty) continue;
      final key = t.toLowerCase();
      if (seen.add(key)) out.add(t);
    }
    return out;
  }

  static Future<BuildContext?> _waitForContext() async {
    for (var i = 0; i < 40; i++) {
      final ctx = appRouter.routerDelegate.navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) return ctx;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return appRouter.routerDelegate.navigatorKey.currentContext;
  }

  static void _toast(String message) {
    StashToast.showOnNavigator(
      appRouter.routerDelegate.navigatorKey.currentState,
      message: message,
      icon: Icons.check_circle_outline,
    );
  }
}

class _RepoOffer {
  const _RepoOffer({
    required this.name,
    required this.indexUrls,
    required this.kind,
  });

  final String name;
  final List<String> indexUrls;
  final String kind;
}

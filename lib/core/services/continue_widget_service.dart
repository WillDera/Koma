import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';

import '../../features/reader/reader_settings_sheet.dart';
import '../../router/book_navigation.dart';
import '../../router/router.dart';
import '../models/book.dart';
import '../models/manga.dart';
import '../providers.dart';
import '../repositories/manga_repository.dart';
import '../repositories/repositories.dart';
import 'hidden_titles_prefs.dart';

/// Home-screen Continue widget (Android) — title, progress, deep link.
class ContinueWidgetService {
  ContinueWidgetService._();

  static const androidProvider = 'ContinueWidgetProvider';
  static const qualifiedAndroidName = 'com.koma.koma.ContinueWidgetProvider';
  static const deepLinkUri = 'koma://continue';

  static const keyTitle = 'continue_title';
  static const keyProgress = 'continue_progress';
  static const keyCoverPath = 'continue_cover_path';
  static const keyDeepLink = 'continue_deep_link';
  static const keyBookId = 'continue_book_id';
  static const keyMangaId = 'continue_manga_id';
  static const keyJson = 'continue_json';

  static ProviderContainer? _container;
  static StreamSubscription<Uri?>? _clickSub;
  static bool _handling = false;

  static void init(ProviderContainer container) {
    _container = container;
    _clickSub?.cancel();
    _clickSub = HomeWidget.widgetClicked.listen((uri) {
      if (uri == null) return;
      if (_isContinueUri(uri)) unawaited(openContinue());
    });
    unawaited(_consumeInitial());
  }

  static Future<void> _consumeInitial() async {
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (uri != null && _isContinueUri(uri)) {
        await openContinue();
      }
    } catch (_) {}
  }

  static bool _isContinueUri(Uri uri) {
    if (uri.scheme.toLowerCase() == 'koma' &&
        uri.host.toLowerCase() == 'continue') {
      return true;
    }
    final s = uri.toString().toLowerCase();
    return s.contains('koma://continue') || s.contains('continue');
  }

  /// Persist the top continue item and refresh the Android widget.
  static Future<void> updateFromRepos(Repositories repos) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    try {
      final item = await _topContinue(repos);
      if (item == null) {
        await _clear();
        return;
      }
      await _saveItem(item);
      await HomeWidget.updateWidget(
        name: androidProvider,
        androidName: androidProvider,
        qualifiedAndroidName: qualifiedAndroidName,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('ContinueWidget update failed: $e');
    }
  }

  static Future<void> _clear() async {
    await HomeWidget.saveWidgetData<String>(keyTitle, 'Nothing to continue');
    await HomeWidget.saveWidgetData<String>(keyProgress, '');
    await HomeWidget.saveWidgetData<String>(keyCoverPath, null);
    await HomeWidget.saveWidgetData<String>(keyDeepLink, deepLinkUri);
    await HomeWidget.saveWidgetData<String>(keyBookId, null);
    await HomeWidget.saveWidgetData<String>(keyMangaId, null);
    await HomeWidget.saveWidgetData<String>(keyJson, '{}');
    await HomeWidget.updateWidget(
      name: androidProvider,
      androidName: androidProvider,
      qualifiedAndroidName: qualifiedAndroidName,
    );
  }

  static Future<void> _saveItem(_ContinuePayload item) async {
    await HomeWidget.saveWidgetData<String>(keyTitle, item.title);
    await HomeWidget.saveWidgetData<String>(keyProgress, item.progressLabel);
    await HomeWidget.saveWidgetData<String>(keyCoverPath, item.coverPath);
    await HomeWidget.saveWidgetData<String>(keyDeepLink, deepLinkUri);
    await HomeWidget.saveWidgetData<String>(
      keyBookId,
      item.bookId?.toString(),
    );
    await HomeWidget.saveWidgetData<String>(
      keyMangaId,
      item.mangaId?.toString(),
    );
    await HomeWidget.saveWidgetData<String>(
      keyJson,
      '{"title":"${_esc(item.title)}","progress":"${_esc(item.progressLabel)}",'
      '"deepLink":"$deepLinkUri"'
      '${item.bookId != null ? ',"bookId":${item.bookId}' : ''}'
      '${item.mangaId != null ? ',"mangaId":${item.mangaId}' : ''}'
      '}',
    );
  }

  static String _esc(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

  static Future<_ContinuePayload?> _topContinue(Repositories repos) async {
    final results = await Future.wait([
      repos.books.getInProgressBooks(),
      repos.manga.getInProgressManga(),
      HiddenTitlesPrefs.hiddenBookIds(),
    ]);
    final hiddenBooks = results[2] as Set<int>;
    final books = [
      for (final b in results[0] as List<Book>)
        if (!hiddenBooks.contains(b.id)) b,
    ];
    final mangas = (results[1] as List<InProgressManga>)
        .where(
          (m) =>
              m.manga.inLibrary && !ViewerFlags.isHidden(m.manga.viewerFlags),
        )
        .toList(growable: false);

    final candidates = <({DateTime at, _ContinuePayload payload})>[];
    for (final b in books) {
      candidates.add((
        at: b.updatedAt,
        payload: _ContinuePayload(
          title: b.title,
          progressLabel: '${(b.progress * 100).round()}%',
          coverPath: b.coverPath,
          bookId: b.id,
        ),
      ));
    }
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    for (final row in mangas) {
      final m = row.manga;
      candidates.add((
        at: row.lastReadAt ?? epoch,
        payload: _ContinuePayload(
          title: m.name,
          progressLabel: '${(row.progress * 100).round()}%',
          coverPath: _mangaCoverPath(m),
          mangaId: m.id,
        ),
      ));
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.at.compareTo(a.at));
    return candidates.first.payload;
  }

  static String? _mangaCoverPath(Manga m) {
    final custom = m.customCoverPath?.trim();
    if (custom != null && custom.isNotEmpty && File(custom).existsSync()) {
      return custom;
    }
    final url = m.imageUrl?.trim();
    if (url != null &&
        url.isNotEmpty &&
        !url.startsWith('http') &&
        File(url).existsSync()) {
      return url;
    }
    return null;
  }

  /// Open the latest continue item (library rail parity).
  static Future<void> openContinue() async {
    if (_handling) return;
    _handling = true;
    try {
      final container = _container;
      if (container == null) return;
      final repos = container.read(repositoriesProvider);
      final item = await _topContinue(repos);
      final ctx = await _waitForContext();
      if (ctx == null || !ctx.mounted || item == null) return;

      if (item.bookId != null) {
        openBookFromCollection(ctx, item.bookId!);
        return;
      }
      if (item.mangaId != null) {
        final manga = await repos.manga.getMangaById(item.mangaId!);
        if (manga == null || !ctx.mounted) return;
        ctx.pushNamed(
          Routes.mangaDetail,
          extra: (
            sourceId: manga.sourceId,
            url: manga.url,
            title: manga.name,
            manga: manga,
            memo: manga.memo,
          ) as MangaDetailArgs,
        );
      }
    } finally {
      _handling = false;
    }
  }

  static Future<BuildContext?> _waitForContext() async {
    for (var i = 0; i < 40; i++) {
      final ctx = appRouter.routerDelegate.navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) return ctx;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return appRouter.routerDelegate.navigatorKey.currentContext;
  }
}

class _ContinuePayload {
  const _ContinuePayload({
    required this.title,
    required this.progressLabel,
    this.coverPath,
    this.bookId,
    this.mangaId,
  });

  final String title;
  final String progressLabel;
  final String? coverPath;
  final int? bookId;
  final int? mangaId;
}

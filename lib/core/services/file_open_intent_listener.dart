import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../router/book_navigation.dart';
import '../../router/router.dart';
import '../models/extension_repo.dart';
import '../models/manga.dart';
import '../models/manga_chapter.dart';
import '../providers.dart';
import 'app_storage.dart';
import 'ebook_media_store.dart';
import 'ebook_service.dart';
import 'export_service.dart';
import 'koma_package_store.dart';
import 'local_cbz_prefs.dart';
import 'local_cbz_scanner.dart';
import 'local_cbz_source.dart';

/// Android VIEW/SEND → import ebook / CBZ / backup / extension index.
class FileOpenIntentListener {
  FileOpenIntentListener._();

  static const _channel = MethodChannel('com.koma.koma/open_file');

  static void init(ProviderContainer container) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onOpenFile') {
        final path = (call.arguments as String?)?.trim() ?? '';
        if (path.isNotEmpty) unawaited(_dispatch(container, path));
      }
      return null;
    });
    unawaited(_consumeInitial(container));
  }

  static Future<void> _consumeInitial(ProviderContainer container) async {
    try {
      final path =
          (await _channel.invokeMethod<String>('getInitialOpenFile'))?.trim() ??
          '';
      if (path.isNotEmpty) await _dispatch(container, path);
    } catch (_) {}
  }

  static Future<void> _dispatch(
    ProviderContainer container,
    String path,
  ) async {
    final file = File(path);
    if (!await file.exists()) return;
    final lower = path.toLowerCase();
    final name = p.basename(lower);

    try {
      if (_isEbook(lower)) {
        await _importEbook(container, path);
        return;
      }
      if (LocalCbzSource.isArchivePath(lower)) {
        await _importCbz(container, path);
        return;
      }
      if (lower.endsWith('.tachibk') ||
          lower.endsWith('.tachibak') ||
          lower.endsWith('.backup')) {
        final repos = container.read(repositoriesProvider);
        await ExportService(
          repos,
          extensionManager: container.read(extensionManagerProvider),
        ).importBytes(
          await file.readAsBytes(),
          filename: p.basename(path),
        );
        await container.read(libraryProvider.notifier).loadBooks();
        return;
      }
      if (lower.endsWith('.pb') || name.endsWith('index.json')) {
        await _importExtensionIndex(container, path);
        return;
      }
      if (lower.endsWith('.json')) {
        final bytes = await file.readAsBytes();
        final head = String.fromCharCodes(bytes.take(240));
        if (head.contains('"books"') ||
            head.contains('"manga"') ||
            head.contains('exported_at')) {
          final repos = container.read(repositoriesProvider);
          await ExportService(
            repos,
            extensionManager: container.read(extensionManagerProvider),
          ).importBytes(
            bytes,
            filename: p.basename(path),
          );
          await container.read(libraryProvider.notifier).loadBooks();
        } else {
          await _importExtensionIndex(container, path);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FileOpenIntentListener: failed $path → $e');
      }
    }
  }

  static bool _isEbook(String lower) {
    return lower.endsWith('.epub') ||
        lower.endsWith('.pdf') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.md') ||
        lower.endsWith('.fb2') ||
        lower.endsWith('.mobi') ||
        lower.endsWith('.azw') ||
        lower.endsWith('.azw3') ||
        lower.endsWith('.kf8') ||
        lower.endsWith('.html');
  }

  static Future<void> _importEbook(
    ProviderContainer container,
    String pickedPath,
  ) async {
    final ebookSvc = EbookService();
    final filePath = await ebookSvc.persistImportCopy(pickedPath);
    final repos = container.read(repositoriesProvider);
    final ln = container.read(libraryProvider.notifier);
    final parsed = await ebookSvc.parse(filePath);
    if (parsed == null) throw Exception('Unsupported ebook format');
    final existing = await repos.books.findLocalBook(
      parsed.book.title,
      parsed.book.author,
    );
    if (existing != null) {
      final ctx = appRouter.routerDelegate.navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        openBookReader(ctx, bookId: existing.id);
      }
      return;
    }
    final bookId = await ln.addBook(parsed.book);
    final chapters = await EbookMediaStore.promote(
      sessionId: parsed.mediaSessionId,
      bookId: bookId,
      chapters: parsed.chapters,
    );
    for (final ch in chapters) {
      await repos.books.insertChapter(ch);
    }
    if (filePath.toLowerCase().endsWith('.epub')) {
      await KomaPackageStore.compileEpub(bookId: bookId, epubPath: filePath);
    }
    final ctx = appRouter.routerDelegate.navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      openBookReader(ctx, bookId: bookId);
    }
  }

  static Future<void> _importCbz(
    ProviderContainer container,
    String path,
  ) async {
    final repos = container.read(repositoriesProvider);
    final title = p.basenameWithoutExtension(path);
    // Prefer a per-title series folder under the configured local root so
    // rescans keep one manga with its chapters; otherwise register the file.
    final folder = await LocalCbzPrefs.folderPath();
    late final String seriesUrl;
    late final String chapterUrl;
    if (folder != null && folder.isNotEmpty) {
      final seriesDir = Directory(p.join(folder, title));
      if (!await seriesDir.exists()) await seriesDir.create(recursive: true);
      final dest = p.join(seriesDir.path, p.basename(path));
      if (p.normalize(File(path).absolute.path) != p.normalize(dest)) {
        await File(path).copy(dest);
      }
      seriesUrl = p.normalize(seriesDir.absolute.path);
      chapterUrl = p.normalize(File(dest).absolute.path);
      await LocalCbzScanner(repos).scanFolder(folder, forceInLibrary: true);
    } else {
      seriesUrl = p.normalize(File(path).absolute.path);
      chapterUrl = seriesUrl;
      await LocalCbzPrefs.includeSeriesUrl(seriesUrl);
      final existing = await repos.manga.getMangaByKey(
        LocalCbzSource.sourceId,
        seriesUrl,
      );
      final mangaId = existing?.id ??
          await repos.manga.insertManga(
            Manga(
              id: 0,
              name: title,
              url: seriesUrl,
              sourceId: LocalCbzSource.sourceId,
              inLibrary: true,
            ),
          );
      if (existing != null) {
        await repos.manga.setMangaInLibrary(mangaId, true);
      }
      await repos.manga.mergeNewChapters(mangaId, [
        MangaChapter.withRecognition(
          id: 0,
          mangaId: mangaId,
          mangaTitle: title,
          name: title,
          url: chapterUrl,
          index: 0,
          isDownloaded: true,
        ),
      ]);
    }
    await container.read(libraryProvider.notifier).loadBooks();
  }

  static Future<void> _importExtensionIndex(
    ProviderContainer container,
    String path,
  ) async {
    final repos = container.read(repositoriesProvider);
    final docs = await AppStorage.documents();
    final destDir = Directory(p.join(docs.path, 'extension_indexes'));
    if (!await destDir.exists()) await destDir.create(recursive: true);
    final dest = p.join(destDir.path, p.basename(path));
    await File(path).copy(dest);
    final fileUrl = Uri.file(dest).toString();
    final name = p.basenameWithoutExtension(path);
    final existing = await repos.extensions.getExtensionRepos();
    if (!existing.any((r) => r.url == fileUrl)) {
      await repos.extensions.insertExtensionRepo(
        ExtensionRepo(
          name: name.isEmpty ? 'Local index' : name,
          url: fileUrl,
        ),
      );
    }
    try {
      await container.read(extensionManagerProvider).reloadAll();
    } catch (_) {}
    appRouter.pushNamed(Routes.extensions);
  }
}

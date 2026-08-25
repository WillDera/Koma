import 'package:shared_preferences/shared_preferences.dart';

import '../../models/extension_source.dart';
import '../../models/library_category.dart';
import '../../models/manga_chapter.dart';
import '../../repositories/repositories.dart';
import 'foreign_backup.dart';
import 'import_result.dart';

class BackupImporter {
  BackupImporter(this._repos);
  final Repositories _repos;

  Future<ImportResult> importForeign(ForeignLibraryBackup backup) async {
    final installed = await _repos.extensions.getInstalledExtensions();

    final oldCatIdToNew = <int, int>{};
    final orderToNew = <int, int>{};
    var categoriesImported = 0;
    for (final cat in backup.categories) {
      if (cat.name.trim().isEmpty) continue;
      final newId = await _repos.categories.upsertByName(
        LibraryCategory(id: 0, name: cat.name, order: cat.order, flags: cat.flags),
      );
      if (cat.id != 0) oldCatIdToNew[cat.id] = newId;
      orderToNew[cat.order] = newId;
      categoriesImported++;
    }

    var mangaImported = 0;
    var mangaSkipped = 0;
    var chaptersImported = 0;
    final missing = <String>{};
    final seenMissingNames = <String>{};

    for (final entry in backup.manga) {
      final resolved = _resolveSourceId(
        installed,
        entry.backupSourceId,
        entry.sourceName,
      );
      if (_isMissingSource(installed, resolved, entry.backupSourceId)) {
        final label = entry.sourceName?.isNotEmpty == true
            ? entry.sourceName!
            : entry.backupSourceId;
        if (seenMissingNames.add(label)) missing.add(label);
      }

      final catIds = <int>[];
      for (final raw in entry.manga.categoryIds) {
        final mapped = oldCatIdToNew[raw] ?? orderToNew[raw];
        if (mapped != null) catIds.add(mapped);
      }

      final incoming = entry.manga.copyWith(
        sourceId: resolved,
        categoryIds: catIds,
      );

      var existing = await _repos.manga.getMangaByKey(resolved, incoming.url);
      existing ??= await _repos.manga.getMangaByKey(
        entry.backupSourceId,
        incoming.url,
      );

      int mangaId;
      if (existing == null) {
        mangaId = await _repos.manga.insertManga(incoming);
        mangaImported++;
      } else {
        mangaId = existing.id;
        final merged = existing.copyWith(
          inLibrary: existing.inLibrary || incoming.inLibrary,
          imageUrl: _prefer(existing.imageUrl, incoming.imageUrl),
          author: _prefer(existing.author, incoming.author),
          artist: _prefer(existing.artist, incoming.artist),
          description: _prefer(existing.description, incoming.description),
          notes: _prefer(existing.notes, incoming.notes),
          categoryIds: {
            ...existing.categoryIds,
            ...catIds,
          }.toList(),
          status: existing.status == 0 ? incoming.status : existing.status,
        );
        await _repos.manga.updateManga(merged);
        mangaSkipped++;
      }

      chaptersImported += await _mergeChapters(mangaId, entry.chapters);
    }

    var reposImported = 0;
    for (final repo in backup.repos) {
      if (repo.url.isEmpty) continue;
      await _repos.extensions.insertExtensionRepo(repo);
      reposImported++;
    }

    var cookiesImported = 0;
    for (final cookie in backup.cookies) {
      if (cookie.host.isEmpty) continue;
      await _repos.cookies.setCookie(cookie.host, cookie.cookie);
      cookiesImported++;
    }

    for (final ext in backup.jsExtensions) {
      final have = await _repos.extensions.getBySourceId(ext.sourceId);
      if (have == null) {
        await _repos.extensions.insertExtensionSource(ext);
      }
    }

    if (backup.showNsfw || backup.novelFontSize != null) {
      final prefs = await SharedPreferences.getInstance();
      if (backup.showNsfw) {
        await prefs.setBool('show_nsfw_extensions', true);
      }
      if (backup.novelFontSize != null) {
        await prefs.setDouble('font_size', backup.novelFontSize!);
      }
    }

    return ImportResult(
      booksImported: 0,
      booksSkipped: 0,
      chaptersImported: 0,
      chaptersSkipped: 0,
      snippetsImported: 0,
      snippetsSkipped: 0,
      mangaImported: mangaImported,
      mangaSkipped: mangaSkipped,
      mangaChaptersImported: chaptersImported,
      categoriesImported: categoriesImported,
      reposImported: reposImported,
      cookiesImported: cookiesImported,
      missingSources: missing.toList()..sort(),
      skippedAnime: backup.skippedAnime,
      skippedNovels: backup.skippedNovels,
      version: 0,
    );
  }

  Future<int> _mergeChapters(
    int mangaId,
    List<MangaChapter> incoming,
  ) async {
    if (incoming.isEmpty) return 0;
    final existing = await _repos.manga.getMangaChapters(mangaId);
    final byUrl = {for (final c in existing) c.url: c};
    var imported = 0;
    for (final ch in incoming) {
      final local = byUrl[ch.url];
      if (local == null) {
        await _repos.manga.putMangaChapter(
          ch.copyWith(id: 0, mangaId: mangaId),
        );
        imported++;
        continue;
      }
      final readAt = _maxDate(local.readAt, ch.readAt);
      final lastPage = ch.lastPageRead > local.lastPageRead
          ? ch.lastPageRead
          : local.lastPageRead;
      final changed =
          (local.isRead || ch.isRead) != local.isRead ||
          (local.isBookmarked || ch.isBookmarked) != local.isBookmarked ||
          lastPage != local.lastPageRead ||
          readAt != local.readAt;
      if (!changed) {
        imported++;
        continue;
      }
      await _repos.manga.putMangaChapter(
        local.copyWith(
          isRead: local.isRead || ch.isRead,
          isBookmarked: local.isBookmarked || ch.isBookmarked,
          lastPageRead: lastPage,
          readAt: readAt,
        ),
      );
      imported++;
    }
    return imported;
  }

  static String _resolveSourceId(
    List<ExtensionSource> installed,
    String backupId,
    String? name,
  ) {
    if (backupId.isEmpty && (name == null || name.isEmpty)) return backupId;
    for (final ext in installed) {
      if (ext.sourceId == backupId || ext.id == backupId) {
        return ext.sourceId;
      }
    }
    if (name != null && name.isNotEmpty) {
      final matches = installed.where((e) => e.name == name).toList();
      if (matches.length == 1) return matches.first.sourceId;
    }
    return backupId;
  }

  static bool _isMissingSource(
    List<ExtensionSource> installed,
    String resolved,
    String backupId,
  ) {
    if (resolved.isEmpty && backupId.isEmpty) return false;
    return !installed.any(
      (e) =>
          e.sourceId == resolved ||
          e.id == resolved ||
          e.sourceId == backupId ||
          e.id == backupId,
    );
  }

  static String? _prefer(String? current, String? incoming) {
    if (current != null && current.trim().isNotEmpty) return current;
    return incoming;
  }

  static DateTime? _maxDate(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }
}

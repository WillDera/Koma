import 'dart:convert';

import 'package:archive/archive.dart';

import '../../models/extension_repo.dart';
import '../../models/extension_source.dart';
import '../../models/library_category.dart';
import '../../models/manga.dart';
import '../../models/manga_chapter.dart';
import '../../utils/json_coerce.dart';
import 'backup_status_map.dart';
import 'foreign_backup.dart';

/// Decode a Mangayomi `.backup` ZIP (JSON member `*.backup.db`) or a raw
/// version `"1"`/`"2"` JSON object.
ForeignLibraryBackup decodeMangayomiBackup(List<int> bytes) {
  Map<String, dynamic> data;
  if (bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4b &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04) {
    final archive = ZipDecoder().decodeBytes(bytes);
    if (archive.files.isEmpty) {
      throw const FormatException('Mangayomi backup ZIP is empty');
    }
    ArchiveFile? member;
    for (final f in archive.files) {
      if (f.isFile && f.name.endsWith('.backup.db')) {
        member = f;
        break;
      }
    }
    member ??= archive.files.firstWhere(
      (f) => f.isFile,
      orElse: () => throw const FormatException('No JSON in Mangayomi backup'),
    );
    data = jsonDecode(utf8.decode(member.content as List<int>))
        as Map<String, dynamic>;
  } else {
    data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  final version = '${data['version'] ?? ''}';
  if (version != '1' && version != '2') {
    throw FormatException('Unsupported Mangayomi backup version $version');
  }

  final rawCats = (data['categories'] as List<dynamic>?) ?? const [];
  final categories = <LibraryCategory>[];
  final oldCatIdToOrder = <int, int>{};
  for (final raw in rawCats) {
    final m = Map<String, dynamic>.from(raw as Map);
    final itemType = asIntOr(m['forItemType']);
    if (itemType == 1) continue; // anime
    final id = asIntOr(m['id']);
    final pos = asIntOr(m['pos']);
    oldCatIdToOrder[id] = pos;
    categories.add(
      LibraryCategory(
        id: id,
        name: m['name'] as String? ?? '',
        order: pos,
      ),
    );
  }

  final rawManga = (data['manga'] as List<dynamic>?) ?? const [];
  final chaptersByManga = <int, List<Map<String, dynamic>>>{};
  for (final raw in (data['chapters'] as List<dynamic>?) ?? const []) {
    final m = Map<String, dynamic>.from(raw as Map);
    final mangaId = asInt(m['mangaId']);
    if (mangaId == null) continue;
    chaptersByManga.putIfAbsent(mangaId, () => []).add(m);
  }

  final historyByChapter = <int, DateTime>{};
  for (final raw in (data['history'] as List<dynamic>?) ?? const []) {
    final m = Map<String, dynamic>.from(raw as Map);
    final chapterId = asInt(m['chapterId']);
    final millis = asInt(m['date']);
    if (chapterId == null || millis == null || millis <= 0) continue;
    historyByChapter[chapterId] = DateTime.fromMillisecondsSinceEpoch(millis);
  }

  var skippedAnime = 0;
  var skippedNovels = 0;
  final mangaOut = <ForeignManga>[];
  final sourceLabels = <String>[];

  for (final raw in rawManga) {
    final m = Map<String, dynamic>.from(raw as Map);
    final itemType = asIntOr(m['itemType']);
    if (itemType == 1) {
      skippedAnime++;
      continue;
    }
    if (itemType == 2) {
      skippedNovels++;
      continue;
    }
    if (m['isLocalArchive'] == true) continue;

    final oldId = asIntOr(m['id']);
    final sourceId = asInt(m['sourceId'])?.toString() ?? '';
    final sourceName = m['source'] as String?;
    if (sourceName != null && sourceName.isNotEmpty) {
      sourceLabels.add(sourceName);
    }

    final backupCatIds = (m['categories'] as List<dynamic>?)
            ?.map((e) => asInt(e))
            .whereType<int>()
            .toList() ??
        const <int>[];

    final chapterMaps = List<Map<String, dynamic>>.from(
      chaptersByManga[oldId] ?? const [],
    );
    chapterMaps.sort((a, b) => asIntOr(a['id']).compareTo(asIntOr(b['id'])));
    final chapters = <MangaChapter>[];
    for (var i = 0; i < chapterMaps.length; i++) {
      final c = chapterMaps[i];
      final chId = asIntOr(c['id']);
      final dateUpload = asInt(c['dateUpload']) ?? 0;
      final lastPage = asInt(c['lastPageRead']) ?? 0;
      chapters.add(
        MangaChapter(
          id: 0,
          mangaId: 0,
          name: c['name'] as String? ?? '',
          url: c['url'] as String? ?? '',
          scanlator: c['scanlator'] as String?,
          dateUpload: dateUpload,
          index: i,
          isRead: c['isRead'] == true,
          lastPageRead: lastPage,
          isBookmarked: c['isBookmarked'] == true,
          readAt: historyByChapter[chId],
        ),
      );
    }

    final dateAdded = asInt(m['dateAdded']) ?? 0;
    final readCount = chapters.where((c) => c.isRead).length;
    mangaOut.add(
      ForeignManga(
        backupSourceId: sourceId,
        sourceName: sourceName,
        manga: Manga(
          id: 0,
          name: m['name'] as String? ?? '',
          url: m['link'] as String? ?? m['url'] as String? ?? '',
          imageUrl: m['imageUrl'] as String?,
          author: m['author'] as String?,
          artist: m['artist'] as String?,
          description: m['description'] as String?,
          status: mangayomiStatusToSManga(asIntOr(m['status'])),
          genres: ((m['genre'] as List<dynamic>?) ?? const [])
              .map((e) => e.toString())
              .toList(),
          sourceId: sourceId,
          inLibrary: m['favorite'] == true,
          readingStatus: readingStatusFromChapters(
            readCount: readCount,
            total: chapters.length,
          ),
          categoryIds: backupCatIds,
          createdAt: dateAdded > 0
              ? DateTime.fromMillisecondsSinceEpoch(dateAdded)
              : DateTime.now(),
        ),
        chapters: chapters,
      ),
    );
  }

  final repos = <ExtensionRepo>[];
  final cookies = <ForeignCookie>[];
  var showNsfw = false;
  double? novelFontSize;
  for (final raw in (data['settings'] as List<dynamic>?) ?? const []) {
    final s = Map<String, dynamic>.from(raw as Map);
    showNsfw = s['showNSFW'] == true || showNsfw;
    novelFontSize = (s['novelFontSize'] as num?)?.toDouble() ?? novelFontSize;
    for (final rawRepo
        in (s['mangaExtensionsRepo'] as List<dynamic>?) ?? const []) {
      final repo = Map<String, dynamic>.from(rawRepo as Map);
      final url = repo['jsonUrl'] as String? ?? '';
      if (url.isEmpty) continue;
      repos.add(
        ExtensionRepo(
          name: repo['name'] as String? ?? url,
          url: url,
          kind: ExtensionRepoKind.javascript,
        ),
      );
    }
    for (final rawCookie in (s['cookiesList'] as List<dynamic>?) ?? const []) {
      final c = Map<String, dynamic>.from(rawCookie as Map);
      final host = c['host'] as String? ?? '';
      if (host.isEmpty) continue;
      cookies.add(
        ForeignCookie(host: host, cookie: c['cookie'] as String? ?? ''),
      );
    }
  }

  final jsExtensions = <ExtensionSource>[];
  for (final raw in (data['extensions'] as List<dynamic>?) ?? const []) {
    final e = Map<String, dynamic>.from(raw as Map);
    final itemType = asIntOr(e['itemType']);
    if (itemType != 0) continue;
    final langIndex = asIntOr(e['sourceCodeLanguage']);
    // 0 dart, 1 javascript, 2 mihon (APK — skip), 3 lnreader (skip)
    if (langIndex == 2 || langIndex == 3) continue;
    final code = e['sourceCode'] as String? ?? '';
    if (code.isEmpty) continue;
    final id = asInt(e['id'])?.toString() ?? '';
    if (id.isEmpty) continue;
    jsExtensions.add(
      ExtensionSource(
        id: id,
        sourceId: id,
        name: e['name'] as String? ?? '',
        version: e['version'] as String? ?? '0',
        lang: e['lang'] as String? ?? '',
        apkPath: '',
        className: '',
        iconUrl: e['iconUrl'] as String?,
        baseUrl: e['baseUrl'] as String?,
        sourceCodeUrl: e['sourceCodeUrl'] as String?,
        apiUrl: e['apiUrl'] as String?,
        hasCloudflare: e['hasCloudflare'] == true,
        itemType: itemType == 2 ? 'novel' : 'manga',
        sourceCode: code,
        sourceCodeLanguage: langIndex == 0
            ? SourceCodeLanguage.dart
            : SourceCodeLanguage.js,
        isNsfw: e['isNsfw'] == true,
        isPinned: e['isPinned'] == true,
        isInstalled: true,
        isActive: e['isActive'] != false,
      ),
    );
  }

  return ForeignLibraryBackup(
    categories: categories,
    manga: mangaOut,
    repos: repos,
    cookies: cookies,
    jsExtensions: jsExtensions,
    sourceLabels: sourceLabels.toSet().toList(),
    skippedAnime: skippedAnime,
    skippedNovels: skippedNovels,
    showNsfw: showNsfw,
    novelFontSize: novelFontSize,
  );
}

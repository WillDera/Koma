import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../eval/dispatch_service.dart';
import '../../eval/models/m_source.dart';
import '../models/extension_source.dart';
import '../models/manga.dart';
import '../models/manga_chapter.dart';
import '../repositories/repositories.dart';
import '../utils/chapter_recognition.dart';
import 'local_cbz_source.dart';

/// A better catalogue hit for an in-library title (more / newer chapters).
class MigrateSuggestion {
  const MigrateSuggestion({
    required this.mangaId,
    required this.targetSourceId,
    required this.targetSourceName,
    required this.targetUrl,
    required this.targetTitle,
    this.targetMemo,
    required this.currentChapterCount,
    required this.targetChapterCount,
    this.currentMaxChapter,
    this.targetMaxChapter,
  });

  final int mangaId;
  final String targetSourceId;
  final String targetSourceName;
  final String targetUrl;
  final String targetTitle;
  final String? targetMemo;
  final int currentChapterCount;
  final int targetChapterCount;
  final double? currentMaxChapter;
  final double? targetMaxChapter;

  int get extraChapters =>
      (targetChapterCount - currentChapterCount).clamp(0, 1 << 30);

  String get fingerprint => '$targetSourceId|$targetUrl';

  /// User-facing one-liner, e.g. "12 more chapters on MangaDex".
  String get message {
    final src = targetSourceName.isNotEmpty ? targetSourceName : 'another source';
    if (extraChapters > 0) {
      final n = extraChapters;
      return '$n more chapter${n == 1 ? '' : 's'} on $src';
    }
    final cur = currentMaxChapter;
    final tgt = targetMaxChapter;
    if (cur != null && tgt != null && tgt > cur) {
      return 'Newer chapters on $src (through ch. ${_fmt(tgt)})';
    }
    return 'More complete on $src';
  }

  static String _fmt(double n) {
    if (n == n.roundToDouble()) return n.round().toString();
    return n.toStringAsFixed(1);
  }

  Map<String, dynamic> toJson() => {
        'mangaId': mangaId,
        'targetSourceId': targetSourceId,
        'targetSourceName': targetSourceName,
        'targetUrl': targetUrl,
        'targetTitle': targetTitle,
        'targetMemo': targetMemo,
        'currentChapterCount': currentChapterCount,
        'targetChapterCount': targetChapterCount,
        'currentMaxChapter': currentMaxChapter,
        'targetMaxChapter': targetMaxChapter,
      };

  factory MigrateSuggestion.fromJson(Map<String, dynamic> json) {
    return MigrateSuggestion(
      mangaId: json['mangaId'] as int,
      targetSourceId: json['targetSourceId'] as String? ?? '',
      targetSourceName: json['targetSourceName'] as String? ?? '',
      targetUrl: json['targetUrl'] as String? ?? '',
      targetTitle: json['targetTitle'] as String? ?? '',
      targetMemo: json['targetMemo'] as String?,
      currentChapterCount: json['currentChapterCount'] as int? ?? 0,
      targetChapterCount: json['targetChapterCount'] as int? ?? 0,
      currentMaxChapter: (json['currentMaxChapter'] as num?)?.toDouble(),
      targetMaxChapter: (json['targetMaxChapter'] as num?)?.toDouble(),
    );
  }
}

/// Searches other installed sources for the same library title and ranks by
/// chapter completeness (max recognized chapter, then count).
class MigrateSuggestionService {
  MigrateSuggestionService({
    required Repositories repositories,
    required this._dispatch,
  }) : _repos = repositories;

  final Repositories _repos;
  final ExtensionDispatchService _dispatch;

  static const _concurrency = 4;
  static const _minExtraChapters = 3;
  static const _cacheTtl = Duration(hours: 12);
  static const _prefsCachePrefix = 'migrate_suggest_cache_v2_';
  static const _prefsDismissPrefix = 'migrate_suggest_dismiss_v1_';

  /// Returns a suggestion when another source looks meaningfully more complete.
  /// Null when none, dismissed, or [manga] is not in the library.
  Future<MigrateSuggestion?> findBetterSource(
    Manga manga, {
    bool force = false,
  }) async {
    if (!manga.inLibrary) return null;
    if (LocalCbzSource.isLocal(manga.sourceId)) return null;
    if (manga.name.trim().isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    if (!force) {
      final cached = _readCache(prefs, manga.id);
      if (cached != null) {
        final dismissed = prefs.getString('$_prefsDismissPrefix${manga.id}');
        if (dismissed != null &&
            cached.suggestion?.fingerprint == dismissed) {
          return null;
        }
        return cached.suggestion;
      }
    }

    final currentChapters = await _repos.manga.getMangaChapters(manga.id);
    final currentStats = _stats(manga.name, currentChapters);

    final sources = await _candidateSources(manga.sourceId);
    if (sources.isEmpty) {
      await _writeCache(prefs, manga.id, null);
      return null;
    }

    final queries = <String>{
      manga.name.trim(),
      for (final alt in manga.alternateTitles)
        if (alt.trim().isNotEmpty) alt.trim(),
    };

    final hits = <_SourceHit>[];
    var next = 0;
    Future<void> worker() async {
      while (true) {
        final i = next++;
        if (i >= sources.length) return;
        final src = sources[i];
        final hit = await _bestHitForSource(src, queries);
        if (hit != null) hits.add(hit);
      }
    }

    final workers = List.generate(
      _concurrency.clamp(1, sources.length),
      (_) => worker(),
    );
    await Future.wait(workers);

    MigrateSuggestion? best;
    var bestScore = -1.0;
    for (final hit in hits) {
      try {
        final detail = await _dispatch.getMangaDetail(
          MSource.fromExtensionSource(hit.source),
          hit.url,
          memo: hit.memo,
          title: hit.title,
        );
        final remoteChapters = detail.chapters;
        if (remoteChapters.isEmpty) continue;

        final remoteAsLocal = [
          for (var i = 0; i < remoteChapters.length; i++)
            MangaChapter(
              id: 0,
              mangaId: 0,
              name: remoteChapters[i].name,
              url: remoteChapters[i].url,
              index: i,
              chapterNumber: ChapterRecognition.parseChapterNumber(
                hit.title,
                remoteChapters[i].name,
                remoteChapters[i].chapterNumber.toDouble(),
              ),
            ),
        ];
        final remoteStats = _stats(hit.title, remoteAsLocal);
        if (!_isBetter(current: currentStats, remote: remoteStats)) continue;

        final score = _rankScore(
          titleScore: hit.titleScore,
          current: currentStats,
          remote: remoteStats,
        );
        if (score <= bestScore) continue;

        bestScore = score;
        best = MigrateSuggestion(
          mangaId: manga.id,
          targetSourceId: hit.source.sourceId,
          targetSourceName: hit.source.name,
          targetUrl: hit.url,
          targetTitle: hit.title,
          targetMemo: hit.memo,
          currentChapterCount: currentStats.count,
          targetChapterCount: remoteStats.count,
          currentMaxChapter: currentStats.maxChapter,
          targetMaxChapter: remoteStats.maxChapter,
        );
      } catch (_) {
        // Skip failing sources — suggestion is best-effort.
      }
    }

    final dismissed = prefs.getString('$_prefsDismissPrefix${manga.id}');
    if (best != null && dismissed == best.fingerprint) {
      await _writeCache(prefs, manga.id, null);
      return null;
    }

    await _writeCache(prefs, manga.id, best);
    return best;
  }

  Future<void> dismiss(int mangaId, String fingerprint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefsDismissPrefix$mangaId', fingerprint);
    await _writeCache(prefs, mangaId, null);
  }

  Future<void> clearDismiss(int mangaId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefsDismissPrefix$mangaId');
  }

  Future<List<ExtensionSource>> _candidateSources(String excludeSourceId) async {
    final all = await _repos.extensions.getInstalledExtensions();
    final out = <ExtensionSource>[];
    for (final s in all) {
      if (!s.isInstalled || !s.isActive || s.isObsolete) continue;
      if (LocalCbzSource.isLocal(s.sourceId)) continue;
      if (s.sourceId == excludeSourceId || s.id == excludeSourceId) continue;
      final type = s.itemType.trim().toLowerCase();
      if (type.isNotEmpty && type != 'manga') continue;
      out.add(s);
    }
    out.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  Future<_SourceHit?> _bestHitForSource(
    ExtensionSource source,
    Set<String> queries,
  ) async {
    _SourceHit? best;
    for (final query in queries) {
      try {
        final page = await _dispatch.search(
          MSource.fromExtensionSource(source),
          1,
          query,
        );
        for (final m in page.list) {
          final title = m.title.trim();
          final url = m.url.trim();
          if (title.isEmpty || url.isEmpty) continue;
          final score = _titleScore(query, title);
          if (score < 50) continue;
          if (best == null || score > best.titleScore) {
            best = _SourceHit(
              source: source,
              url: url,
              title: title,
              memo: m.memo,
              titleScore: score,
            );
          }
        }
      } catch (_) {
        // ignore source search failures
      }
    }
    return best;
  }

  static int _titleScore(String query, String hit) {
    final nq = _normTitle(query);
    final nh = _normTitle(hit);
    if (nq.isEmpty || nh.isEmpty) return 0;
    // Full-name match only (case-insensitive). Prefix / token overlap would
    // falsely link "Absolute Wonder Woman (2024-)" with "Absolute Batman (2024-)".
    if (nq == nh) return 100;
    return 0;
  }

  static String _normTitle(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static _ChapterStats _stats(String title, List<MangaChapter> chapters) {
    // Count unique major chapters (1.1 / 1.2 / 1-en → one). Parse from the
    // chapter name so source indexes don't split language variants apart.
    final majors = <int>{};
    double? maxChapter;
    for (final c in chapters) {
      final n = ChapterRecognition.parseFromName(title, c.name);
      if (!ChapterRecognition.isRecognized(n)) continue;
      majors.add(n.floor());
      if (maxChapter == null || n > maxChapter) maxChapter = n;
    }
    final count = majors.isNotEmpty ? majors.length : chapters.length;
    return _ChapterStats(count: count, maxChapter: maxChapter);
  }

  static bool _isBetter({
    required _ChapterStats current,
    required _ChapterStats remote,
  }) {
    final curMax = current.maxChapter;
    final remMax = remote.maxChapter;
    if (curMax != null && remMax != null) {
      if (remMax >= curMax + 1.0) return true;
      if (remMax >= curMax &&
          remote.count >= current.count + _minExtraChapters) {
        return true;
      }
      return false;
    }
    return remote.count >= current.count + _minExtraChapters;
  }

  static double _rankScore({
    required int titleScore,
    required _ChapterStats current,
    required _ChapterStats remote,
  }) {
    final curMax = current.maxChapter ?? 0;
    final remMax = remote.maxChapter ?? 0;
    final chapterGain = remMax - curMax;
    final countGain = (remote.count - current.count).toDouble();
    return titleScore * 10 + chapterGain * 100 + countGain;
  }

  _CacheEntry? _readCache(SharedPreferences prefs, int mangaId) {
    final raw = prefs.getString('$_prefsCachePrefix$mangaId');
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.fromMillisecondsSinceEpoch(map['at'] as int? ?? 0);
      if (DateTime.now().difference(at) > _cacheTtl) return null;
      final sug = map['suggestion'];
      if (sug == null) {
        return _CacheEntry(at: at, suggestion: null);
      }
      return _CacheEntry(
        at: at,
        suggestion: MigrateSuggestion.fromJson(
          Map<String, dynamic>.from(sug as Map),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(
    SharedPreferences prefs,
    int mangaId,
    MigrateSuggestion? suggestion,
  ) async {
    await prefs.setString(
      '$_prefsCachePrefix$mangaId',
      jsonEncode({
        'at': DateTime.now().millisecondsSinceEpoch,
        'suggestion': suggestion?.toJson(),
      }),
    );
  }
}

class _ChapterStats {
  const _ChapterStats({required this.count, this.maxChapter});
  final int count;
  final double? maxChapter;
}

class _SourceHit {
  const _SourceHit({
    required this.source,
    required this.url,
    required this.title,
    this.memo,
    required this.titleScore,
  });
  final ExtensionSource source;
  final String url;
  final String title;
  final String? memo;
  final int titleScore;
}

class _CacheEntry {
  const _CacheEntry({required this.at, required this.suggestion});
  final DateTime at;
  final MigrateSuggestion? suggestion;
}

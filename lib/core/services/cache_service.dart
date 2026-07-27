import 'package:isar_community/isar.dart';

import '../repositories/repositories.dart';
import '../models/chapter.dart';
import '../isar/collections/web_cache.dart';

class CacheService {
  final Repositories _repos;

  CacheService(this._repos);

  Future<bool> isCached(String url) async {
    final hash = _urlHash(url);
    final row = await _repos.isar.webCaches
        .where()
        .urlHashEqualTo(hash)
        .findFirst();
    return row != null;
  }

  Future<Chapter?> getCached(String url) async {
    final hash = _urlHash(url);
    final row = await _repos.isar.webCaches
        .where()
        .urlHashEqualTo(hash)
        .findFirst();
    if (row == null) return null;
    return Chapter(
      id: row.id ?? 0,
      bookId: 0,
      title: row.title,
      content: row.content,
      index: 0,
    );
  }

  Future<void> cacheContent(String url, String title, String htmlContent) async {
    final hash = _urlHash(url);
    await _repos.isar.writeTxn(() async {
      await _repos.isar.webCaches.put(WebCache(
        urlHash: hash,
        url: url,
        title: title,
        content: htmlContent,
        cachedAt: DateTime.now(),
      ));
    });
  }

  Future<void> clearCache() async {
    await _repos.isar.writeTxn(() => _repos.isar.webCaches.where().deleteAll());
  }

  String _urlHash(String url) {
    return 'cache:${url.hashCode}';
  }
}

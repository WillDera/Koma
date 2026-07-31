import 'dart:async';

import 'package:isar_community/isar.dart';

import '../isar/collections/manga_cookie.dart' as i;

/// Persists per-host cookies for image CDN requests.
///
/// Cookies are injected into image request headers via
/// [CookieHeaderProvider]. Each host has at most one cookie entry (unique
/// index on [i.MangaCookie.host]).
class CookieRepository {
  final Isar _isar;

  CookieRepository(this._isar);

  Future<i.MangaCookie?> getByHost(String host) async {
    return _isar.mangaCookies.where().hostEqualTo(host).findFirst();
  }

  Future<void> setCookie(String host, String cookie) async {
    await _isar.writeTxn(() async {
      final existing = await _isar.mangaCookies
          .where()
          .hostEqualTo(host)
          .findFirst();
      if (existing == null) {
        await _isar.mangaCookies.put(i.MangaCookie(host: host, cookie: cookie));
      } else {
        existing.cookie = cookie;
        await _isar.mangaCookies.put(existing);
      }
    });
  }

  Future<void> deleteCookie(String host) async {
    await _isar.writeTxn(() async {
      final existing = await _isar.mangaCookies
          .where()
          .hostEqualTo(host)
          .findFirst();
      if (existing != null) {
        await _isar.mangaCookies.delete(existing.id!);
      }
    });
  }

  Future<List<i.MangaCookie>> getAll() async {
    return _isar.mangaCookies.where().findAll();
  }

  Stream<List<i.MangaCookie>> watchAll({bool fireImmediately = true}) {
    return _isar.mangaCookies.where().watch(fireImmediately: fireImmediately);
  }
}

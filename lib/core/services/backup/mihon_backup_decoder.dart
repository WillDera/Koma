import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../models/extension_repo.dart';
import '../../models/library_category.dart';
import '../../models/manga.dart';
import '../../models/manga_chapter.dart';
import 'backup_status_map.dart';
import 'foreign_backup.dart';
import 'proto_wire.dart';

/// Decode a Mihon `.tachibk` (gzip protobuf, or raw protobuf).
ForeignLibraryBackup decodeMihonBackup(List<int> bytes) {
  var payload = bytes;
  if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
    payload = GZipDecoder().decodeBytes(bytes);
  }
  return _decodeBackup(ProtoReader(payload));
}

/// Encode a tiny Mihon backup (tests / round-trip of the fields we import).
Uint8List encodeMihonBackup(ForeignLibraryBackup backup, {bool gzip = true}) {
  final root = ProtoWriter();
  for (final m in backup.manga) {
    root.writeMessage(1, _encodeManga(m));
  }
  for (final c in backup.categories) {
    root.writeMessage(2, _encodeCategory(c));
  }
  final labels = <String, String>{};
  for (final m in backup.manga) {
    if (m.sourceName != null && m.sourceName!.isNotEmpty) {
      labels[m.backupSourceId] = m.sourceName!;
    }
  }
  for (final e in labels.entries) {
    final w = ProtoWriter()
      ..writeString(1, e.value)
      ..writeInt(2, int.tryParse(e.key) ?? 0);
    root.writeMessage(101, w.toBytes());
  }
  for (final r in backup.repos) {
    root.writeMessage(106, _encodeRepo(r));
  }
  final proto = root.toBytes();
  if (!gzip) return proto;
  return Uint8List.fromList(GZipEncoder().encode(proto));
}

ForeignLibraryBackup _decodeBackup(ProtoReader r) {
  final manga = <_RawManga>[];
  final categories = <LibraryCategory>[];
  final sources = <int, String>{};
  final repos = <ExtensionRepo>[];

  while (!r.isDone) {
    final (field, wire) = r.readTag();
    switch (field) {
      case 1:
        manga.add(_decodeManga(ProtoReader(r.readBytes())));
      case 2:
        categories.add(_decodeCategory(ProtoReader(r.readBytes())));
      case 101:
        final src = _decodeSource(ProtoReader(r.readBytes()));
        sources[src.$1] = src.$2;
      case 106:
        repos.add(_decodeRepo(ProtoReader(r.readBytes())));
      default:
        r.skip(wire);
    }
  }

  final orderToCat = {for (final c in categories) c.order: c};
  final outManga = <ForeignManga>[];
  final labels = <String>[];
  for (final raw in manga) {
    final sourceId = raw.source.toString();
    final sourceName = sources[raw.source];
    if (sourceName != null && sourceName.isNotEmpty) {
      labels.add(sourceName);
    }
    final catIds = <int>[];
    for (final order in raw.categoryOrders) {
      final cat = orderToCat[order];
      if (cat != null && cat.id != 0) {
        catIds.add(cat.id);
      } else {
        // Categories get real ids on insert; stash order as a sentinel
        // the importer remaps via name. Use negative order-1.
        catIds.add(-(order.toInt() + 1));
      }
    }
    final chapters = <MangaChapter>[];
    for (var i = 0; i < raw.chapters.length; i++) {
      final ch = raw.chapters[i];
      final history = raw.history[ch.url];
      chapters.add(
        MangaChapter(
          id: 0,
          mangaId: 0,
          name: ch.name,
          url: ch.url,
          scanlator: ch.scanlator,
          dateUpload: ch.dateUpload,
          index: ch.sourceOrder > 0 ? ch.sourceOrder.toInt() : i,
          isRead: ch.read,
          lastPageRead: ch.lastPageRead.toInt(),
          chapterNumber: ch.chapterNumber,
          isBookmarked: ch.bookmark,
          readAt: history,
          dateFetch: ch.dateFetch,
          memo: ch.memo,
        ),
      );
    }
    final readCount = chapters.where((c) => c.isRead).length;
    outManga.add(
      ForeignManga(
        backupSourceId: sourceId,
        sourceName: sourceName,
        manga: Manga(
          id: 0,
          name: raw.title,
          url: raw.url,
          imageUrl: raw.thumbnailUrl,
          author: raw.author,
          artist: raw.artist,
          description: raw.description,
          status: raw.status,
          genres: raw.genre,
          sourceId: sourceId,
          inLibrary: raw.favorite,
          readingStatus: readingStatusFromChapters(
            readCount: readCount,
            total: chapters.length,
          ),
          memo: raw.memo,
          categoryIds: catIds,
          notes: raw.notes,
          viewerFlags: raw.resolvedViewerFlags,
          chapterFlags: raw.chapterFlags,
          createdAt: raw.dateAdded > 0
              ? DateTime.fromMillisecondsSinceEpoch(raw.dateAdded)
              : DateTime.now(),
        ),
        chapters: chapters,
      ),
    );
  }

  return ForeignLibraryBackup(
    categories: categories,
    manga: outManga,
    repos: repos,
    sourceLabels: labels.toSet().toList(),
  );
}

class _RawManga {
  int source = 0;
  String url = '';
  String title = '';
  String? artist;
  String? author;
  String? description;
  List<String> genre = [];
  int status = 0;
  String? thumbnailUrl;
  int dateAdded = 0;
  int viewer = 0;
  int? viewerFlags;
  int chapterFlags = 0;
  final chapters = <_RawChapter>[];
  final categoryOrders = <int>[];
  bool favorite = true;
  bool favoritePresent = false;
  final history = <String, DateTime>{};
  String? notes;
  String? memo;

  int get resolvedViewerFlags => viewerFlags ?? viewer;
}

class _RawChapter {
  String url = '';
  String name = '';
  String? scanlator;
  bool read = false;
  bool bookmark = false;
  int lastPageRead = 0;
  int dateFetch = 0;
  int dateUpload = 0;
  double chapterNumber = -1;
  int sourceOrder = 0;
  String? memo;
}

_RawManga _decodeManga(ProtoReader r) {
  final m = _RawManga();
  while (!r.isDone) {
    final (field, wire) = r.readTag();
    switch (field) {
      case 1:
        m.source = r.readVarint();
      case 2:
        m.url = r.readString();
      case 3:
        m.title = r.readString();
      case 4:
        m.artist = r.readString();
      case 5:
        m.author = r.readString();
      case 6:
        m.description = r.readString();
      case 7:
        m.genre.add(r.readString());
      case 8:
        m.status = r.readVarint();
      case 9:
        m.thumbnailUrl = r.readString();
      case 13:
        m.dateAdded = r.readVarint();
      case 14:
        m.viewer = r.readVarint();
      case 16:
        m.chapters.add(_decodeChapter(ProtoReader(r.readBytes())));
      case 17:
        m.categoryOrders.addAll(r.readPackedVarints(wire));
      case 100:
        m.favoritePresent = true;
        m.favorite = r.readVarint() != 0;
      case 101:
        m.chapterFlags = r.readVarint();
      case 103:
        m.viewerFlags = r.readVarint();
      case 104:
        final h = _decodeHistory(ProtoReader(r.readBytes()));
        if (h != null) m.history[h.$1] = h.$2;
      case 110:
        m.notes = r.readString();
      case 112:
        final raw = r.readBytes();
        m.memo = utf8.decode(raw, allowMalformed: true);
      default:
        r.skip(wire);
    }
  }
  if (!m.favoritePresent) m.favorite = true;
  return m;
}

_RawChapter _decodeChapter(ProtoReader r) {
  final c = _RawChapter();
  while (!r.isDone) {
    final (field, wire) = r.readTag();
    switch (field) {
      case 1:
        c.url = r.readString();
      case 2:
        c.name = r.readString();
      case 3:
        c.scanlator = r.readString();
      case 4:
        c.read = r.readVarint() != 0;
      case 5:
        c.bookmark = r.readVarint() != 0;
      case 6:
        c.lastPageRead = r.readVarint();
      case 7:
        c.dateFetch = r.readVarint();
      case 8:
        c.dateUpload = r.readVarint();
      case 9:
        if (wire == 5) {
          c.chapterNumber = r.readFloat();
        } else {
          r.skip(wire);
        }
      case 10:
        c.sourceOrder = r.readVarint();
      case 13:
        c.memo = utf8.decode(r.readBytes(), allowMalformed: true);
      default:
        r.skip(wire);
    }
  }
  return c;
}

(String, DateTime)? _decodeHistory(ProtoReader r) {
  String url = '';
  int lastRead = 0;
  while (!r.isDone) {
    final (field, wire) = r.readTag();
    switch (field) {
      case 1:
        url = r.readString();
      case 2:
        lastRead = r.readVarint();
      default:
        r.skip(wire);
    }
  }
  if (url.isEmpty || lastRead <= 0) return null;
  return (url, DateTime.fromMillisecondsSinceEpoch(lastRead));
}

LibraryCategory _decodeCategory(ProtoReader r) {
  var name = '';
  var order = 0;
  var id = 0;
  var flags = 0;
  while (!r.isDone) {
    final (field, wire) = r.readTag();
    switch (field) {
      case 1:
        name = r.readString();
      case 2:
        order = r.readVarint();
      case 3:
        id = r.readVarint();
      case 100:
        flags = r.readVarint();
      default:
        r.skip(wire);
    }
  }
  return LibraryCategory(id: id, name: name, order: order, flags: flags);
}

(int, String) _decodeSource(ProtoReader r) {
  var name = '';
  var id = 0;
  while (!r.isDone) {
    final (field, wire) = r.readTag();
    switch (field) {
      case 1:
        name = r.readString();
      case 2:
        id = r.readVarint();
      default:
        r.skip(wire);
    }
  }
  return (id, name);
}

ExtensionRepo _decodeRepo(ProtoReader r) {
  var indexUrl = '';
  var name = '';
  String? signingKey;
  while (!r.isDone) {
    final (field, wire) = r.readTag();
    switch (field) {
      case 1:
        indexUrl = r.readString();
      case 2:
        name = r.readString();
      case 5:
        signingKey = r.readString();
      case 8:
        final listUrl = r.readString();
        if (indexUrl.isEmpty) indexUrl = listUrl;
      default:
        r.skip(wire);
    }
  }
  return ExtensionRepo(
    name: name.isEmpty ? indexUrl : name,
    url: indexUrl,
    signingKey: signingKey,
    kind: ExtensionRepoKind.mihon,
  );
}

List<int> _encodeManga(ForeignManga fm) {
  final w = ProtoWriter();
  final source = int.tryParse(fm.backupSourceId) ?? 0;
  w.writeInt(1, source);
  w.writeString(2, fm.manga.url);
  w.writeString(3, fm.manga.name);
  if (fm.manga.artist != null) w.writeString(4, fm.manga.artist!);
  if (fm.manga.author != null) w.writeString(5, fm.manga.author!);
  if (fm.manga.description != null) w.writeString(6, fm.manga.description!);
  for (final g in fm.manga.genres) {
    w.writeString(7, g);
  }
  w.writeInt(8, fm.manga.status);
  if (fm.manga.imageUrl != null) w.writeString(9, fm.manga.imageUrl!);
  w.writeInt(13, fm.manga.createdAt.millisecondsSinceEpoch);
  if (fm.manga.viewerFlags != 0) {
    w.writeInt(103, fm.manga.viewerFlags);
  }
  if (fm.manga.chapterFlags != 0) {
    w.writeInt(101, fm.manga.chapterFlags);
  }
  for (final ch in fm.chapters) {
    w.writeMessage(16, _encodeChapter(ch));
  }
  for (final order in fm.manga.categoryIds) {
    w.writeInt(17, order);
  }
  if (!fm.manga.inLibrary) {
    w.writeBool(100, false, omitFalse: false);
  }
  if (fm.manga.notes != null && fm.manga.notes!.isNotEmpty) {
    w.writeString(110, fm.manga.notes!);
  }
  return w.toBytes();
}

List<int> _encodeChapter(MangaChapter ch) {
  final w = ProtoWriter();
  w.writeString(1, ch.url);
  w.writeString(2, ch.name);
  if (ch.scanlator != null) w.writeString(3, ch.scanlator!);
  w.writeBool(4, ch.isRead);
  w.writeBool(5, ch.isBookmarked);
  w.writeInt(6, ch.lastPageRead);
  if (ch.dateFetch != 0) w.writeInt(7, ch.dateFetch);
  w.writeInt(8, ch.dateUpload);
  w.writeFloat(9, ch.chapterNumber);
  w.writeInt(10, ch.index);
  return w.toBytes();
}

List<int> _encodeCategory(LibraryCategory c) {
  final w = ProtoWriter();
  w.writeString(1, c.name);
  w.writeInt(2, c.order);
  w.writeInt(3, c.id);
  w.writeInt(100, c.flags);
  return w.toBytes();
}

List<int> _encodeRepo(ExtensionRepo r) {
  final w = ProtoWriter();
  w.writeString(1, r.url);
  w.writeString(2, r.name);
  if (r.signingKey != null) w.writeString(5, r.signingKey!);
  return w.toBytes();
}

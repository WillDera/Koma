import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/extension_index_entry.dart';
import '../models/extension_source.dart' show SourceCodeLanguage;
import 'backup/proto_wire.dart';

/// Result of decoding a Mihon/Keiyoushi extension catalog (JSON or `.pb`).
class ExtensionIndexDecode {
  const ExtensionIndexDecode({
    required this.entries,
    this.signingKey,
    this.extensionListUrl,
    this.storeName,
    this.indexV2Url,
    this.isLegacyRepoMeta = false,
  });

  final List<ExtensionIndexEntry> entries;
  final String? signingKey;
  final String? extensionListUrl;
  final String? storeName;

  /// From legacy `repo.json` — client should re-fetch this URL.
  final String? indexV2Url;

  /// True when the body was only legacy repo meta (no extension list).
  final bool isLegacyRepoMeta;
}

/// Gzip if magic `1f 8b`, otherwise return [bytes] unchanged.
Uint8List maybeGunzipIndexBytes(List<int> bytes) {
  if (bytes.length < 2) return Uint8List.fromList(bytes);
  if (bytes[0] == 0x1f && bytes[1] == 0x8b) {
    return Uint8List.fromList(GZipCodec().decode(bytes));
  }
  return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
}

/// Top-level isolate entry: sniff bytes and decode JSON or protobuf Index.
ExtensionIndexDecode decodeExtensionIndexBytes(
  List<int> rawBytes, {
  String? sourceUrl,
}) {
  final bytes = maybeGunzipIndexBytes(rawBytes);
  if (bytes.isEmpty) {
    throw FormatException(
      'Repo returned an empty body'
      '${sourceUrl != null ? ' ($sourceUrl)' : ''}',
    );
  }

  final first = bytes[0];

  // Legacy JSON array `[...]`
  if (first == 0x5b /* [ */) {
    return ExtensionIndexDecode(
      entries: _parseJsonEntries(utf8.decode(bytes), sourceUrl: sourceUrl),
    );
  }

  // JSON object `{...}` — v2 Index, ExtensionList, or legacy repo.json
  if (first == 0x7b /* { */) {
    return _decodeJsonObject(utf8.decode(bytes), sourceUrl: sourceUrl);
  }

  // HTML mistake (github web page)
  if (first == 0x3c /* < */) {
    throw FormatException(
      'Repo URL returned HTML instead of an extension index. Use a raw URL '
      '(e.g. …/index.pb or …/index.min.json), not a GitHub web page'
      '${sourceUrl != null ? '. Got: $sourceUrl' : '.'}',
    );
  }

  // Protobuf Index / ExtensionList
  return _decodeProtobuf(bytes, sourceUrl: sourceUrl);
}

ExtensionIndexDecode _decodeJsonObject(String body, {String? sourceUrl}) {
  final t = body.trimLeft();
  if (t.startsWith('<!DOCTYPE') ||
      t.startsWith('<!doctype') ||
      t.startsWith('<html') ||
      t.startsWith('<HTML')) {
    throw FormatException(
      'Repo URL returned HTML instead of JSON'
      '${sourceUrl != null ? '. Got: $sourceUrl' : '.'}',
    );
  }

  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw FormatException(
      'Repo JSON is not a recognized format — got ${decoded.runtimeType}'
      '${sourceUrl != null ? ' ($sourceUrl)' : ''}',
    );
  }
  final map = Map<String, dynamic>.from(decoded);

  // Legacy Mihon repo.json meta (optional index_v2 pointer).
  final indexV2 = map['index_v2'] ?? map['indexV2'];
  final hasMeta = map['meta'] is Map;
  final looksLikeLegacyRepo =
      indexV2 != null ||
      (hasMeta &&
          !map.containsKey('extensionList') &&
          !map.containsKey('extensions'));
  if (looksLikeLegacyRepo &&
      !map.containsKey('extensionList') &&
      !map.containsKey('extensions')) {
    String? key;
    final meta = map['meta'];
    if (meta is Map && meta['signingKeyFingerprint'] is String) {
      key = (meta['signingKeyFingerprint'] as String).trim().toLowerCase();
    } else if (map['signingKey'] is String) {
      key = (map['signingKey'] as String).trim().toLowerCase();
    }
    return ExtensionIndexDecode(
      entries: const [],
      signingKey: key,
      storeName: meta is Map ? meta['name'] as String? : map['name'] as String?,
      indexV2Url: indexV2 is String && indexV2.isNotEmpty ? indexV2 : null,
      isLegacyRepoMeta: true,
    );
  }

  // Standalone ExtensionList JSON: { "extensions": [...] }
  if (map['extensions'] is List && !map.containsKey('extensionList')) {
    final exts = (map['extensions'] as List)
        .whereType<Map>()
        .map((e) => ExtensionIndexEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
    return ExtensionIndexDecode(entries: exts);
  }

  // v2 Index JSON
  final signing = map['signingKey'] is String
      ? (map['signingKey'] as String).trim().toLowerCase()
      : null;
  final listUrl = map['extensionListUrl'] as String?;
  final storeName = map['name'] as String?;
  final extList = map['extensionList'];
  if (extList is Map) {
    final extsRaw = extList['extensions'];
    if (extsRaw is List) {
      final entries = extsRaw
          .whereType<Map>()
          .map(
            (e) => ExtensionIndexEntry.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(growable: false);
      return ExtensionIndexDecode(
        entries: entries,
        signingKey: signing,
        extensionListUrl: listUrl,
        storeName: storeName,
      );
    }
  }

  if (listUrl != null && listUrl.isNotEmpty) {
    return ExtensionIndexDecode(
      entries: const [],
      signingKey: signing,
      extensionListUrl: listUrl,
      storeName: storeName,
    );
  }

  throw FormatException(
    'Repo JSON is not a recognized format'
    '${sourceUrl != null ? ' ($sourceUrl)' : ''}',
  );
}

List<ExtensionIndexEntry> _parseJsonEntries(String body, {String? sourceUrl}) {
  final t = body.trimLeft();
  if (t.startsWith('<!DOCTYPE') ||
      t.startsWith('<!doctype') ||
      t.startsWith('<html') ||
      t.startsWith('<HTML')) {
    throw FormatException(
      'Repo URL returned HTML instead of JSON'
      '${sourceUrl != null ? '. Got: $sourceUrl' : '.'}',
    );
  }
  final decoded = jsonDecode(body);
  if (decoded is List) {
    return decoded
        .whereType<Map>()
        .map((e) => ExtensionIndexEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }
  throw FormatException(
    'Expected a JSON array of extensions'
    '${sourceUrl != null ? ' ($sourceUrl)' : ''}',
  );
}

/// Map packageName → iconUrl from a full Index (JSON or protobuf bytes).
Map<String, String> parseExtensionIconUrls(List<int> rawBytes) {
  final decoded = decodeExtensionIndexBytes(rawBytes);
  final out = <String, String>{};
  for (final e in decoded.entries) {
    final icon = e.iconUrl?.trim();
    if (e.pkg.isNotEmpty && icon != null && icon.isNotEmpty) {
      out[e.pkg] = icon;
    }
  }
  return out;
}

// ── Protobuf (tachiyomix Index) ─────────────────────────────────────────

ExtensionIndexDecode _decodeProtobuf(Uint8List bytes, {String? sourceUrl}) {
  try {
    return _readIndexMessage(bytes);
  } catch (e) {
    // Some catalogs ship a bare ExtensionList protobuf.
    try {
      final list = _readExtensionList(bytes);
      return ExtensionIndexDecode(entries: list);
    } catch (_) {
      throw FormatException(
        'Failed to decode protobuf extension index'
        '${sourceUrl != null ? ' ($sourceUrl)' : ''}: $e',
      );
    }
  }
}

ExtensionIndexDecode _readIndexMessage(Uint8List bytes) {
  final r = ProtoReader(bytes);
  String? name;
  String? signingKey;
  String? extensionListUrl;
  List<ExtensionIndexEntry>? entries;

  while (!r.isDone) {
    final (field, wire) = r.readTag();
    switch (field) {
      case 1: // name
        name = r.readString();
      case 2: // badgeLabel
        r.skip(wire);
      case 3: // signingKey
        signingKey = r.readString().trim().toLowerCase();
      case 4: // Contact
        r.skip(wire);
      case 101: // ExtensionList
        entries = _readExtensionList(Uint8List.fromList(r.readBytes()));
      case 102: // extensionListUrl
        extensionListUrl = r.readString();
      default:
        r.skip(wire);
    }
  }

  return ExtensionIndexDecode(
    entries: entries ?? const [],
    signingKey: signingKey,
    extensionListUrl: extensionListUrl,
    storeName: name,
  );
}

List<ExtensionIndexEntry> _readExtensionList(Uint8List bytes) {
  final r = ProtoReader(bytes);
  final out = <ExtensionIndexEntry>[];
  while (!r.isDone) {
    final (field, wire) = r.readTag();
    if (field == 1 && wire == 2) {
      out.add(_readExtension(Uint8List.fromList(r.readBytes())));
    } else {
      r.skip(wire);
    }
  }
  return out;
}

ExtensionIndexEntry _readExtension(Uint8List bytes) {
  final r = ProtoReader(bytes);
  var name = '';
  var packageName = '';
  var apkUrl = '';
  var iconUrl = '';
  var versionName = '0';
  var contentWarning = 1; // SAFE
  final sources = <Map<String, dynamic>>[];

  while (!r.isDone) {
    final (field, wire) = r.readTag();
    switch (field) {
      case 1:
        name = r.readString();
      case 2:
        packageName = r.readString();
      case 3:
        final res = _readResources(Uint8List.fromList(r.readBytes()));
        apkUrl = res.$1;
        iconUrl = res.$2;
      case 4: // extensionLib
        r.skip(wire);
      case 5: // versionCode
        r.skip(wire);
      case 6:
        versionName = r.readString();
      case 7:
        contentWarning = r.readVarint();
      case 8:
        sources.add(_readSource(Uint8List.fromList(r.readBytes())));
      default:
        r.skip(wire);
    }
  }

  final langs = <String>{};
  for (final s in sources) {
    final lang = (s['language'] as String?) ?? (s['lang'] as String?) ?? '';
    if (lang.isNotEmpty) langs.add(lang);
  }
  final lang = langs.length == 1
      ? langs.first
      : (langs.isEmpty ? 'en' : 'all');

  final cw = switch (contentWarning) {
    0 => 'CONTENT_WARNING_UNSPECIFIED',
    2 => 'CONTENT_WARNING_MIXED',
    3 => 'CONTENT_WARNING_NSFW',
    _ => 'CONTENT_WARNING_SAFE',
  };
  final isNsfw = contentWarning >= 2; // MIXED or NSFW (Mihon rule)

  final baseUrl = sources.isNotEmpty
      ? (sources.first['homeUrl'] as String?) ??
            (sources.first['baseUrl'] as String?)
      : null;

  return ExtensionIndexEntry(
    pkg: packageName,
    name: name.isEmpty ? (packageName.isEmpty ? 'Unknown' : packageName) : name,
    apkUrl: apkUrl,
    sourceCodeUrl: null,
    sourceCodeLanguage: SourceCodeLanguage.mihon,
    version: versionName,
    lang: lang,
    contentWarning: cw,
    isNsfw: isNsfw,
    baseUrl: baseUrl,
    iconUrl: iconUrl.isEmpty ? null : iconUrl,
    sources: sources,
  );
}

(String, String) _readResources(Uint8List bytes) {
  final r = ProtoReader(bytes);
  var apk = '';
  var icon = '';
  while (!r.isDone) {
    final (field, wire) = r.readTag();
    switch (field) {
      case 1:
        apk = r.readString();
      case 2:
        icon = r.readString();
      default:
        r.skip(wire); // e.g. jarUrl = 501 on forks
    }
  }
  return (apk, icon);
}

Map<String, dynamic> _readSource(Uint8List bytes) {
  final r = ProtoReader(bytes);
  int? id;
  var name = '';
  var language = '';
  var homeUrl = '';
  while (!r.isDone) {
    final (field, wire) = r.readTag();
    switch (field) {
      case 1:
        id = r.readVarint();
      case 2:
        name = r.readString();
      case 3:
        language = r.readString();
      case 4:
        homeUrl = r.readString();
      case 5: // mirrorUrls
        r.skip(wire);
      case 7: // message
        r.skip(wire);
      default:
        r.skip(wire);
    }
  }
  return {
    'id': ?id,
    'name': name,
    'language': language,
    'lang': language,
    'homeUrl': homeUrl,
    'baseUrl': homeUrl,
  };
}

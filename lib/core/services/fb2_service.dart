import 'dart:convert';
import 'dart:io';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import 'ebook_media_store.dart';
import 'epub_service.dart';

class Fb2Service {
  Future<EpubResult?> parse(String filePath, {int? bookId}) async {
    try {
      final raw = await File(filePath).readAsString();
      // strip XML namespaces so querySelector works
      final cleaned = raw.replaceAll(RegExp(r'\s+xmlns[^>=]*="[^"]*"'), '');
      final doc = html_parser.parse(cleaned);
      if (doc.body == null) throw Exception('No body');

      final bookIdFinal = bookId ?? 0;
      final sessionId = bookId != null && bookId > 0
          ? '$bookId'
          : EbookMediaStore.newSessionId();

      // Prefetch binary images → local paths (id without leading #).
      final binaryPaths = <String, String>{};
      for (final match in RegExp(
        r'''<binary\s+([^>]*)>([\s\S]*?)</binary>''',
        caseSensitive: false,
      ).allMatches(raw)) {
        final attrs = match.group(1) ?? '';
        final idMatch = RegExp(
          r'''\bid\s*=\s*["']([^"']+)["']''',
          caseSensitive: false,
        ).firstMatch(attrs);
        if (idMatch == null) continue;
        final id = idMatch.group(1)!;
        try {
          final bytes = base64Decode(match.group(2)!.trim());
          final path = await EbookMediaStore.storeBytes(
            bookOrSessionId: sessionId,
            bytes: bytes,
            preferredExt: _extFromContentType(attrs),
            logicalName: id,
          );
          binaryPaths[id] = path;
        } catch (_) {}
      }

      // Save cover image
      String? coverPath;
      final coverImg = doc.querySelector('coverpage image');
      if (coverImg != null) {
        final href =
            coverImg.attributes['l:href'] ??
            coverImg.attributes['xlink:href'] ??
            '';
        final binId = href.replaceFirst('#', '');
        coverPath = binaryPaths[binId] ?? await _extractBinary(raw, binId);
      }

      // Metadata
      final titleInfo = doc.querySelector('title-info');
      final bookTitle =
          titleInfo?.querySelector('book-title')?.text.trim() ??
          'Unknown Title';
      final authorEl = titleInfo?.querySelector('author');
      final author = authorEl != null ? _parseAuthor(authorEl) : null;

      // Chapters
      final chapters = <Chapter>[];
      var idx = 0;

      // Find <body> within the FB2 document
      Element? fb2Body;
      for (final el in doc.querySelectorAll('body')) {
        final p = el.parentNode;
        if (p is Element && p.localName?.toLowerCase() == 'fictionbook') {
          fb2Body = el;
          break;
        }
      }
      fb2Body ??= doc.body;
      if (fb2Body == null) throw Exception('No body element');

      for (final section in fb2Body.querySelectorAll(':scope > section')) {
        chapters.add(
          _sectionToChapter(section, bookIdFinal, idx++, binaryPaths),
        );
      }

      if (chapters.isEmpty) {
        final html = _serializeChildren(fb2Body, binaryPaths);
        chapters.add(
          Chapter(
            id: 0,
            bookId: bookIdFinal,
            title: 'Text',
            content: '<div>$html</div>',
            index: 0,
          ),
        );
      }

      final book = Book(
        id: bookIdFinal,
        title: bookTitle,
        author: author,
        coverPath: coverPath,
        source: 'local',
        filePath: filePath,
        totalChapters: chapters.length,
      );

      return EpubResult(
        book: book,
        chapters: chapters,
        mediaSessionId: sessionId,
      );
    } catch (e) {
      throw Exception('Failed to parse FB2: $e');
    }
  }

  Chapter _sectionToChapter(
    Element section,
    int bookId,
    int index,
    Map<String, String> binaryPaths,
  ) {
    final titleEl = section.querySelector('title');
    final title = titleEl?.text.trim() ?? 'Chapter ${index + 1}';
    final html = _serializeChildren(section, binaryPaths);
    return Chapter(
      id: 0,
      bookId: bookId,
      title: title,
      content: '<div>$html</div>',
      index: index,
    );
  }

  String _serializeChildren(Element parent, Map<String, String> binaryPaths) {
    final buf = StringBuffer();
    for (final node in parent.nodes) {
      if (node.nodeType == Node.TEXT_NODE) {
        buf.write(_escape(node.text ?? ''));
      } else if (node is Element) {
        buf.write(_serializeElement(node, binaryPaths));
      }
    }
    return buf.toString();
  }

  String _serializeElement(Element el, Map<String, String> binaryPaths) {
    final tag = el.localName!.toLowerCase();
    switch (tag) {
      case 'title':
      case 'subtitle':
        return '<h3>${_serializeChildren(el, binaryPaths)}</h3>';
      case 'p':
        return '<p>${_serializeChildren(el, binaryPaths)}</p>';
      case 'empty-line':
        return '<br/>';
      case 'emphasis':
        return '<em>${_serializeChildren(el, binaryPaths)}</em>';
      case 'strong':
        return '<strong>${_serializeChildren(el, binaryPaths)}</strong>';
      case 'strikethrough':
        return '<s>${_serializeChildren(el, binaryPaths)}</s>';
      case 'code':
        return '<code>${_serializeChildren(el, binaryPaths)}</code>';
      case 'a':
        final href = el.attributes['l:href'] ?? el.attributes['href'] ?? '';
        return '<a href="${_escape(href)}">${_serializeChildren(el, binaryPaths)}</a>';
      case 'image':
        final href =
            el.attributes['l:href'] ??
            el.attributes['xlink:href'] ??
            el.attributes['href'] ??
            '';
        final binId = href.replaceFirst('#', '');
        final path = binaryPaths[binId];
        if (path == null) return '';
        return '<img src="${Uri.file(path)}"/>';
      case 'section':
      case 'v':
      case 'text-author':
      case 'date':
      case 'style':
        return '<p>${_serializeChildren(el, binaryPaths)}</p>';
      case 'table':
        return '<table>${_serializeChildren(el, binaryPaths)}</table>';
      case 'tr':
        return '<tr>${_serializeChildren(el, binaryPaths)}</tr>';
      case 'td':
      case 'th':
        return '<$tag>${_serializeChildren(el, binaryPaths)}</$tag>';
      default:
        return _serializeChildren(el, binaryPaths);
    }
  }

  String _escape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  String? _extFromContentType(String attrs) {
    final m = RegExp(
      r'''content-type\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(attrs);
    final ct = m?.group(1)?.toLowerCase() ?? '';
    if (ct.contains('jpeg') || ct.contains('jpg')) return 'jpg';
    if (ct.contains('png')) return 'png';
    if (ct.contains('gif')) return 'gif';
    if (ct.contains('webp')) return 'webp';
    return null;
  }

  Future<String?> _extractBinary(String rawXml, String id) async {
    final match = RegExp(
      '<binary\\s+id=["\']$id["\'][^>]*>([\\s\\S]*?)</binary>',
      caseSensitive: false,
    ).firstMatch(rawXml);
    if (match == null) return null;
    try {
      final bytes = base64Decode(match.group(1)!.trim());
      final appDir = await getApplicationDocumentsDirectory();
      final coverDir = Directory('${appDir.path}/covers');
      if (!await coverDir.exists()) await coverDir.create(recursive: true);
      final outFile = File(
        '${coverDir.path}/${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await outFile.writeAsBytes(bytes);
      return outFile.path;
    } catch (_) {
      return null;
    }
  }

  String _parseAuthor(Element el) {
    final parts = [
      el.querySelector('first-name')?.text.trim() ?? '',
      el.querySelector('middle-name')?.text.trim() ?? '',
      el.querySelector('last-name')?.text.trim() ?? '',
    ];
    final name = parts.where((p) => p.isNotEmpty).join(' ');
    return name.isNotEmpty ? name : el.text.trim();
  }
}

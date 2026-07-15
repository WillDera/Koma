import 'dart:convert';
import 'dart:io';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';
import '../models/chapter.dart';
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

      // Save cover image
      String? coverPath;
      final coverImg = doc.querySelector('coverpage image');
      if (coverImg != null) {
        final href = coverImg.attributes['l:href'] ??
            coverImg.attributes['xlink:href'] ??
            '';
        final binId = href.replaceFirst('#', '');
        coverPath = await _extractBinary(raw, binId);
      }

      // Metadata
      final titleInfo = doc.querySelector('title-info');
      final bookTitle =
          titleInfo?.querySelector('book-title')?.text.trim() ?? 'Unknown Title';
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
        chapters.add(_sectionToChapter(section, bookIdFinal, idx++, raw));
      }

      if (chapters.isEmpty) {
        final html = _serializeChildren(fb2Body);
        chapters.add(Chapter(
          id: 0,
          bookId: bookIdFinal,
          title: 'Text',
          content: '<div>$html</div>',
          index: 0,
        ));
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

      return EpubResult(book: book, chapters: chapters);
    } catch (e) {
      throw Exception('Failed to parse FB2: $e');
    }
  }

  Chapter _sectionToChapter(
      Element section, int bookId, int index, String rawFile) {
    final titleEl = section.querySelector('title');
    final title = titleEl?.text.trim() ?? 'Chapter ${index + 1}';
    final html = _serializeChildren(section);
    return Chapter(
      id: 0,
      bookId: bookId,
      title: title,
      content: '<div>$html</div>',
      index: index,
    );
  }

  String _serializeChildren(Element parent) {
    final buf = StringBuffer();
    for (final node in parent.nodes) {
      if (node.nodeType == Node.TEXT_NODE) {
        buf.write(_escape(node.text ?? ''));
      } else if (node is Element) {
        buf.write(_serializeElement(node));
      }
    }
    return buf.toString();
  }

  String _serializeElement(Element el) {
    final tag = el.localName!.toLowerCase();
    switch (tag) {
      case 'title':
      case 'subtitle':
        return '<h3>${_serializeChildren(el)}</h3>';
      case 'p':
        return '<p>${_serializeChildren(el)}</p>';
      case 'empty-line':
        return '<br/>';
      case 'emphasis':
        return '<em>${_serializeChildren(el)}</em>';
      case 'strong':
        return '<strong>${_serializeChildren(el)}</strong>';
      case 'strikethrough':
        return '<s>${_serializeChildren(el)}</s>';
      case 'code':
        return '<code>${_serializeChildren(el)}</code>';
      case 'a':
        final href = el.attributes['l:href'] ?? el.attributes['href'] ?? '';
        return '<a href="$href">${_serializeChildren(el)}</a>';
      case 'image':
        return ''; // ponytail: inline images stripped (reader is text-only)
      case 'section':
      case 'v':
      case 'text-author':
      case 'date':
      case 'style':
        return '<p>${_serializeChildren(el)}</p>';
      case 'table':
        return '<table>${_serializeChildren(el)}</table>';
      case 'tr':
        return '<tr>${_serializeChildren(el)}</tr>';
      case 'td':
      case 'th':
        return '<$tag>${_serializeChildren(el)}</$tag>';
      default:
        return _serializeChildren(el);
    }
  }

  String _escape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  Future<String?> _extractBinary(String rawXml, String id) async {
    final match = RegExp(
        '<binary\\s+id=["\']$id["\'][^>]*>([\\s\\S]*?)</binary>',
        caseSensitive: false).firstMatch(rawXml);
    if (match == null) return null;
    try {
      final bytes = base64Decode(match.group(1)!.trim());
      final appDir = await getApplicationDocumentsDirectory();
      final coverDir = Directory('${appDir.path}/covers');
      if (!await coverDir.exists()) await coverDir.create(recursive: true);
      final outFile =
          File('${coverDir.path}/${DateTime.now().millisecondsSinceEpoch}.png');
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

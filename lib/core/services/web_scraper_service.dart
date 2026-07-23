import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

class WebScrapeResult {
  final String title;
  final String? author;
  final String contentHtml;

  WebScrapeResult({
    required this.title,
    this.author,
    required this.contentHtml,
  });
}

class WebScraperService {
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Koma/1.0';

  Future<WebScrapeResult> fetchContent(String url) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.get(
        uri,
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: Failed to fetch $url');
      }

      final document = html_parser.parse(response.body);

      // Extract title
      String title = _extractTitle(document, uri);

      // Extract author
      String? author = _extractAuthor(document);

      // Extract main content
      String contentHtml = _extractContent(document);

      if (contentHtml.isEmpty) {
        // Fallback: use body content
        final body = document.body;
        if (body != null) {
          contentHtml = body.innerHtml;
        }
      }

      // Clean up the HTML a bit
      contentHtml = _cleanContent(contentHtml);

      return WebScrapeResult(
        title: title,
        author: author,
        contentHtml: contentHtml,
      );
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to fetch content: $e');
    }
  }

  String _extractTitle(dom.Document document, Uri uri) {
    // Try <title> tag
    final titleTag = document.querySelector('title');
    if (titleTag != null && titleTag.text.trim().isNotEmpty) {
      return titleTag.text.trim();
    }
    // Try og:title
    final ogTitle = document.querySelector('meta[property="og:title"]');
    if (ogTitle != null) {
      final content = ogTitle.attributes['content'];
      if (content != null && content.isNotEmpty) return content;
    }
    // Try h1
    final h1 = document.querySelector('h1');
    if (h1 != null && h1.text.trim().isNotEmpty) {
      return h1.text.trim();
    }
    return uri.host;
  }

  String? _extractAuthor(dom.Document document) {
    // Try meta author
    final metaAuthor = document.querySelector('meta[name="author"]');
    if (metaAuthor != null) {
      final content = metaAuthor.attributes['content'];
      if (content != null && content.isNotEmpty) return content;
    }
    // Try og:author
    final ogAuthor = document.querySelector('meta[property="article:author"]');
    if (ogAuthor != null) {
      final content = ogAuthor.attributes['content'];
      if (content != null && content.isNotEmpty) return content;
    }
    return null;
  }

  String _extractContent(dom.Document document) {
    // Try <article> tag first
    final article = document.querySelector('article');
    if (article != null) return article.innerHtml;

    // Try common content containers
    final selectors = [
      '.post-content',
      '.entry-content',
      '.article-content',
      '.content',
      '#content',
      '.post',
      '.article',
      'main',
      '[role="main"]',
    ];

    for (final selector in selectors) {
      final elements = document.querySelectorAll(selector);
      if (elements.isNotEmpty) {
        return elements.map((e) => e.innerHtml).join('\n');
      }
    }

    return '';
  }

  String _cleanContent(String html) {
    // Remove scripts, styles, nav, footer, header, aside
    final document = html_parser.parse(html);
    for (final tag in ['script', 'style', 'nav', 'footer', 'header', 'aside']) {
      for (final element in document.querySelectorAll(tag)) {
        element.remove();
      }
    }

    // Build a clean HTML with just paragraphs, headings, links, lists
    final body = document.body;
    if (body == null) return html;

    final allowedTags = <String>{
      'p', 'br', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
      'ul', 'ol', 'li', 'a', 'strong', 'em', 'b', 'i',
      'blockquote', 'pre', 'code', 'hr', 'div', 'span',
      'img', 'figure', 'figcaption',
    };

    final buffer = StringBuffer();
    _extractAllowedContent(body, allowedTags, buffer);
    return buffer.toString();
  }

  void _extractAllowedContent(dom.Node node, Set<String> allowedTags, StringBuffer buffer) {
    if (node is dom.Element) {
      if (allowedTags.contains(node.localName)) {
        buffer.write('<${node.localName}');
        // Preserve href for links, src for images with sanitization
        if (node.localName == 'a' && node.attributes.containsKey('href')) {
          final href = node.attributes['href']!;
          buffer.write(' href="${_sanitizeAttr(href)}"');
        }
        if (node.localName == 'img' && node.attributes.containsKey('src')) {
          final src = node.attributes['src']!;
          buffer.write(' src="${_sanitizeAttr(src)}"');
          if (node.attributes.containsKey('alt')) {
            buffer.write(' alt="${_sanitizeAttr(node.attributes['alt']!)}"');
          }
        }
        buffer.write('>');
        for (final child in node.nodes) {
          _extractAllowedContent(child, allowedTags, buffer);
        }
        buffer.write('</${node.localName}>');
      } else {
        // Skip disallowed tags but keep their text content
        for (final child in node.nodes) {
          _extractAllowedContent(child, allowedTags, buffer);
        }
      }
    } else if (node is dom.Text) {
      final text = node.text;
      if (text.trim().isNotEmpty) {
        buffer.write(text);
      }
    }
  }

  String _sanitizeAttr(String value) {
    // Strip dangerous URI schemes
    final lower = value.toLowerCase().trim();
    if (lower.startsWith('javascript:') ||
        lower.startsWith('data:') ||
        lower.startsWith('vbscript:')) {
      return '';
    }
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}

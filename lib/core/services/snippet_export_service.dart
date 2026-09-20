import '../models/snippet.dart';

/// Exports snippets as Markdown, CSV, or Anki-compatible TSV.
class SnippetExportService {
  const SnippetExportService();

  /// Groups by [Snippet.sourceTitle] (null/empty → "Ungrouped").
  String exportMarkdown(List<Snippet> snippets) {
    if (snippets.isEmpty) return '';
    final groups = <String, List<Snippet>>{};
    for (final s in snippets) {
      final key = (s.sourceTitle ?? '').trim().isEmpty
          ? 'Ungrouped'
          : s.sourceTitle!.trim();
      (groups[key] ??= []).add(s);
    }
    final buf = StringBuffer();
    final keys = groups.keys.toList()..sort();
    for (var i = 0; i < keys.length; i++) {
      if (i > 0) buf.writeln();
      buf.writeln('# ${keys[i]}');
      buf.writeln();
      for (final s in groups[keys[i]]!) {
        buf.writeln('> ${s.text.replaceAll('\n', '\n> ')}');
        final note = s.note?.trim();
        if (note != null && note.isNotEmpty) {
          buf.writeln();
          buf.writeln(note);
        }
        if (s.tags.isNotEmpty) {
          buf.writeln();
          buf.writeln(s.tags.map((t) => '#$t').join(' '));
        }
        buf.writeln();
      }
    }
    return buf.toString().trimRight();
  }

  String exportCsv(List<Snippet> snippets) {
    final buf = StringBuffer();
    buf.writeln('text,note,source_title,source_url,tags,created_at');
    for (final s in snippets) {
      buf.writeln(
        [
          _csv(s.text),
          _csv(s.note ?? ''),
          _csv(s.sourceTitle ?? ''),
          _csv(s.sourceUrl ?? ''),
          _csv(s.tags.join(';')),
          _csv(s.createdAt.toIso8601String()),
        ].join(','),
      );
    }
    return buf.toString();
  }

  /// Anki-style TSV: front = text, back = note (or sourceTitle if note empty).
  String exportAnkiTsv(List<Snippet> snippets) {
    final buf = StringBuffer();
    for (final s in snippets) {
      final front = _ankiField(s.text);
      final backRaw = (s.note ?? '').trim().isNotEmpty
          ? s.note!.trim()
          : (s.sourceTitle ?? '').trim();
      buf.writeln('$front\t${_ankiField(backRaw)}');
    }
    return buf.toString();
  }

  static String _csv(String value) {
    final needsQuotes =
        value.contains(',') || value.contains('"') || value.contains('\n');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  static String _ankiField(String value) =>
      value.replaceAll('\t', ' ').replaceAll('\r\n', ' ').replaceAll('\n', ' ');
}

import 'package:flutter/material.dart';

/// Builds a [TextSpan] tree for `text` with optional bionic reading:
/// the first 40% of each word is bolded for faster eye-skip reading.
class BionicText {
  BionicText._();

  /// Splits [text] into tokens, with whitespace preserved, and returns
  /// a flat list of [TextSpan]s suitable for embedding in a [TextSpan].
  static List<TextSpan> spans(
    String text, {
    required TextStyle baseStyle,
    required FontWeight bionicWeight,
    required double bionicFraction,
  }) {
    final out = <TextSpan>[];
    final re = RegExp(r'(\s+|[^\s]+)');
    for (final m in re.allMatches(text)) {
      final token = m.group(0)!;
      if (RegExp(r'^\s+$').hasMatch(token)) {
        out.add(TextSpan(text: token, style: baseStyle));
      } else {
        // Skip bionic for single-character tokens (punctuation glued
        // to a word is bolded as part of the word).
        final splitAt = (token.length * bionicFraction).round().clamp(1, token.length);
        final head = token.substring(0, splitAt);
        final tail = token.substring(splitAt);
        out.add(TextSpan(
          text: head,
          style: baseStyle.copyWith(fontWeight: bionicWeight),
        ));
        if (tail.isNotEmpty) {
          out.add(TextSpan(text: tail, style: baseStyle));
        }
      }
    }
    return out;
  }
}

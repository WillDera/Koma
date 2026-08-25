import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koma/features/reader/reader_screen.dart';
import 'package:koma/widgets/reader_bottom_bar.dart';
import 'package:koma/widgets/reader_top_bar.dart';

void main() {
  test('vertical chrome inset is equal and clears the taller bar', () {
    const padding = EdgeInsets.fromLTRB(0, 47, 0, 24);
    final inset = readerVerticalChromeInset(padding);
    expect(inset, padding.top + ReaderTopBar.bodyHeight);
    expect(inset, greaterThanOrEqualTo(padding.bottom + ReaderBottomBar.bodyHeight));
    expect(ReaderTopBar.bodyHeight, 50);
    expect(ReaderBottomBar.bodyHeight, 56);
  });

  test('a taller bottom inset wins', () {
    const padding = EdgeInsets.fromLTRB(0, 10, 0, 48);
    final inset = readerVerticalChromeInset(padding);
    expect(inset, padding.bottom + ReaderBottomBar.bodyHeight);
  });
}

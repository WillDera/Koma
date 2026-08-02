import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class BenchmarkLogger {
  static bool enabled = kDebugMode || kProfileMode;
  static DateTime? _headerLastLog;
  static File? _file;

  static Future<File> _ensureFile() async {
    if (_file != null) return _file!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/benchmark');
    await dir.create(recursive: true);
    _file = File('${dir.path}/results.txt');
    return _file!;
  }

  static Future<void> log(String tag, String message) async {
    if (!enabled) return;
    final ts = DateTime.now().toIso8601String().split('.').first;
    final line = '[$ts] $tag : $message';
    debugPrint(line);
    try {
      final f = await _ensureFile();
      await f.writeAsString('$line\n', mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('[BenchmarkLogger] file write failed: $e');
    }
  }

  static Future<void> clear() async {
    try {
      final f = await _ensureFile();
      await f.delete();
    } catch (_) {}
  }
}

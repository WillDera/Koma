/// Minimal logger for Dart extension `print` bridge (manga-only; no Isar log DB).
class Logger {
  static void add(LoggerLevel level, String message) {
    // ignore: avoid_print
    print('[$level] $message');
  }
}

enum LoggerLevel { warning, info, error }

/// Feature flag used by mangayomi `print` bridge.
bool useLogger = false;

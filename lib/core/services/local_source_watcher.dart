import 'dart:async';
import 'dart:io';

/// Watches local CBZ / ebook drop folders and notifies after a short debounce.
class LocalSourceWatcher {
  LocalSourceWatcher();

  static const debounceMs = 800;

  final List<StreamSubscription<FileSystemEvent>> _subs = [];
  Timer? _debounce;
  void Function()? _onChanged;

  bool get isWatching => _subs.isNotEmpty;

  /// Starts watching [mangaPath] and optional [ebookPath].
  /// Missing or null paths are ignored.
  void start({
    String? mangaPath,
    String? ebookPath,
    required void Function() onChanged,
  }) {
    stop();
    _onChanged = onChanged;
    _attach(mangaPath);
    _attach(ebookPath);
  }

  void stop() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _debounce?.cancel();
    _debounce = null;
    _onChanged = null;
  }

  void _attach(String? path) {
    if (path == null || path.trim().isEmpty) return;
    final dir = Directory(path);
    if (!dir.existsSync()) return;
    _subs.add(
      dir.watch(recursive: true).listen((_) => _schedule()),
    );
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: debounceMs), () {
      _onChanged?.call();
    });
  }
}

/// Apple Books-style interactive page curl.
///
/// ```dart
/// PageCurlView(
///   pageIndex: _index,
///   onPageChanged: (i) => setState(() => _index = i),
///   pageBuilder: (context, i) =>
///       (i < 0 || i >= pages.length) ? null : pages[i],
/// )
/// ```
///
/// The renderer is independent of any book engine — a page is just a widget.
library;

export 'page_curl_config.dart';
export 'page_curl_controller.dart';
export 'page_curl_gesture_handler.dart';
export 'page_curl_mesh.dart';
export 'page_curl_physics.dart';
export 'page_curl_renderer.dart';
export 'page_curl_view.dart';

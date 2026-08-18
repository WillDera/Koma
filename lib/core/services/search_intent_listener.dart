import 'package:flutter/services.dart';

import '../../router/router.dart';

/// Android `ACTION_SEARCH` → catalogue Global Search (Mihon parity).
class SearchIntentListener {
  SearchIntentListener._();

  static const _channel = MethodChannel('com.koma.koma/search');

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSearchIntent') {
        final query = (call.arguments as String?)?.trim() ?? '';
        if (query.isNotEmpty) _openGlobalSearch(query);
      }
      return null;
    });
    _consumeInitial();
  }

  static Future<void> _consumeInitial() async {
    try {
      final query =
          (await _channel.invokeMethod<String>('getInitialSearchQuery'))
              ?.trim() ??
          '';
      if (query.isNotEmpty) _openGlobalSearch(query);
    } catch (_) {}
  }

  static void _openGlobalSearch(String query) {
    appRouter.pushNamed(Routes.globalSearch, extra: query);
  }
}

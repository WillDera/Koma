import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A catalogue hit that can be multi-selected for batch add-to-library.
class CatalogHit {
  const CatalogHit({
    required this.sourceId,
    required this.url,
    required this.title,
    this.imageUrl,
    this.author,
    this.memo,
  });

  final String sourceId;
  final String url;
  final String title;
  final String? imageUrl;
  final String? author;
  final String? memo;

  String get key => '$sourceId\u001f$url';

  factory CatalogHit.fromSearchMap({
    required String sourceId,
    required Map<String, dynamic> manga,
  }) {
    return CatalogHit(
      sourceId: sourceId,
      url: (manga['url'] as String? ?? '').trim(),
      title: manga['title'] as String? ?? '',
      imageUrl: manga['thumbnail_url'] as String?,
      author: manga['author'] as String?,
      memo: manga['memo'] as String?,
    );
  }
}

class CatalogMultiSelectState {
  const CatalogMultiSelectState({
    this.byKey = const {},
  });

  final Map<String, CatalogHit> byKey;

  bool get isSelecting => byKey.isNotEmpty;
  int get count => byKey.length;
  List<CatalogHit> get selected => byKey.values.toList(growable: false);
  bool contains(String key) => byKey.containsKey(key);
}

class CatalogMultiSelectNotifier extends Notifier<CatalogMultiSelectState> {
  @override
  CatalogMultiSelectState build() => const CatalogMultiSelectState();

  void clear() => state = const CatalogMultiSelectState();

  void longPress(CatalogHit hit) {
    if (hit.url.isEmpty) return;
    final next = Map<String, CatalogHit>.from(state.byKey);
    next[hit.key] = hit;
    state = CatalogMultiSelectState(byKey: next);
  }

  void toggle(CatalogHit hit) {
    if (hit.url.isEmpty) return;
    final next = Map<String, CatalogHit>.from(state.byKey);
    if (next.containsKey(hit.key)) {
      next.remove(hit.key);
    } else {
      next[hit.key] = hit;
    }
    state = CatalogMultiSelectState(byKey: next);
  }

  /// Tap while selecting → toggle. Otherwise return false so caller opens detail.
  bool handleTap(CatalogHit hit) {
    if (!state.isSelecting) return false;
    toggle(hit);
    return true;
  }
}

final catalogMultiSelectProvider =
    NotifierProvider<CatalogMultiSelectNotifier, CatalogMultiSelectState>(
  CatalogMultiSelectNotifier.new,
);

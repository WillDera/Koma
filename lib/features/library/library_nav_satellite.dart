import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Callbacks the Library tab registers so [AppBottomNav] can dock + / hide
/// satellites next to the pill (shared vertical band).
@immutable
class LibraryNavSatellite {
  const LibraryNavSatellite({
    this.onAdd,
    this.onHideSelected,
  });

  final VoidCallback? onAdd;
  final VoidCallback? onHideSelected;

  bool get hasAny => onAdd != null || onHideSelected != null;
}

class LibraryNavSatelliteNotifier extends Notifier<LibraryNavSatellite> {
  @override
  LibraryNavSatellite build() => const LibraryNavSatellite();

  void configure({
    VoidCallback? onAdd,
    VoidCallback? onHideSelected,
  }) {
    final next = LibraryNavSatellite(
      onAdd: onAdd,
      onHideSelected: onHideSelected,
    );
    // Identity compare is enough — Library rebinds with fresh closures.
    if (identical(state.onAdd, next.onAdd) &&
        identical(state.onHideSelected, next.onHideSelected)) {
      return;
    }
    state = next;
  }

  void clear() {
    if (!state.hasAny) return;
    state = const LibraryNavSatellite();
  }
}

final libraryNavSatelliteProvider =
    NotifierProvider<LibraryNavSatelliteNotifier, LibraryNavSatellite>(
      LibraryNavSatelliteNotifier.new,
    );

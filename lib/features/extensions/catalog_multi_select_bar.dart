import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/add_manga_hits_to_library.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/toast.dart';
import 'catalog_multi_select.dart';

/// Bottom action bar while catalogue multi-select is active.
class CatalogMultiSelectBar extends ConsumerStatefulWidget {
  const CatalogMultiSelectBar({super.key});

  @override
  ConsumerState<CatalogMultiSelectBar> createState() =>
      _CatalogMultiSelectBarState();
}

class _CatalogMultiSelectBarState extends ConsumerState<CatalogMultiSelectBar> {
  bool _busy = false;

  Future<void> _addSelected() async {
    final sel = ref.read(catalogMultiSelectProvider);
    if (sel.count == 0 || _busy) return;
    setState(() => _busy = true);
    try {
      final result = await AddMangaHitsToLibrary(
        ref.read(repositoriesProvider),
        ref.read(extensionServiceProvider),
      ).call(sel.selected);
      if (!mounted) return;
      ref.read(catalogMultiSelectProvider.notifier).clear();
      await ref.read(libraryProvider.notifier).loadBooks();
      if (!mounted) return;
      final parts = <String>[
        if (result.added > 0)
          'Added ${result.added} title${result.added == 1 ? '' : 's'}',
        if (result.alreadyInLibrary > 0)
          '${result.alreadyInLibrary} already in library',
        if (result.failed > 0) '${result.failed} failed',
      ];
      StashToast.show(
        context,
        message: parts.isEmpty ? 'Nothing to add' : parts.join(' · '),
        icon: result.added > 0 ? Icons.check : Icons.info_outline,
      );
    } catch (e) {
      if (mounted) {
        StashToast.show(
          context,
          message: 'Couldn’t add: $e',
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sel = ref.watch(catalogMultiSelectProvider);
    if (!sel.isSelecting) return const SizedBox.shrink();
    final c = context.colors;
    return Material(
      color: c.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Text(
                '${sel.count} selected',
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _busy
                    ? null
                    : () =>
                        ref.read(catalogMultiSelectProvider.notifier).clear(),
                child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _addSelected,
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: c.onAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppSpacing.brMd,
                  ),
                ),
                child: _busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.onAccent,
                        ),
                      )
                    : const Text('Add to library'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

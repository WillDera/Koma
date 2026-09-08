import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_spacing.dart';
import 'icon_button_round.dart';
import 'library_book_card.dart';
import 'segmented_control.dart';

/// Shared Library / Explore layout sheet (columns + card style).
class LibraryLayoutSheet extends ConsumerWidget {
  const LibraryLayoutSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const LibraryLayoutSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final library = ref.watch(libraryProvider);
    final ln = ref.read(libraryProvider.notifier);
    // Sheet sits above the tab bar (extendBody) — clear nav + system inset.
    final bottomClearance =
        72.0 + MediaQuery.paddingOf(context).bottom + 20;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, bottomClearance),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.textTertiary,
                borderRadius: AppSpacing.brPill,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Library layout',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButtonRound(
                icon: Icons.close_rounded,
                size: 36,
                variant: IconButtonVariant.filled,
                backgroundColor: c.surfaceMuted,
                iconColor: c.textSecondary,
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Columns',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          SegmentedControl<int>(
            segments: const {2: '2 cols', 3: '3 cols'},
            value: library.gridColumns,
            onChanged: ln.setGridColumns,
          ),
          const SizedBox(height: 16),
          Text(
            'Card style',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          SegmentedControl<LibraryCardVariant>(
            segments: const {
              LibraryCardVariant.grid: 'Grid',
              LibraryCardVariant.list: 'List',
              LibraryCardVariant.compact: 'Compact',
              LibraryCardVariant.overlay: 'Overlay',
            },
            value: library.cardVariant,
            onChanged: ln.setCardVariant,
          ),
        ],
      ),
    );
  }
}

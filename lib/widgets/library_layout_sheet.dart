import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_spacing.dart';
import 'icon_button_round.dart';
import 'library_book_card.dart';
import 'segmented_control.dart';

/// Shared Library / Explore layout sheet (columns + card style + badges).
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
    final bottomClearance =
        72.0 + MediaQuery.paddingOf(context).bottom + 20;
    // Material must own the fill so SwitchListTile ink/splash isn't
    // obscured by an intermediate DecoratedBox background.
    return Material(
      color: c.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 10, 20, bottomClearance),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.border, width: 0.5)),
        ),
        child: SingleChildScrollView(
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
                      'Library display',
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
                segments: const {
                  2: '2',
                  3: '3',
                  4: '4',
                  5: '5',
                },
                value: library.gridColumns.clamp(2, 5),
                onChanged: ln.setGridColumns,
              ),
              const SizedBox(height: 16),
              Text(
                'Display mode',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              SegmentedControl<LibraryCardVariant>(
                segments: const {
                  LibraryCardVariant.grid: 'Comfortable',
                  LibraryCardVariant.compact: 'Compact',
                  LibraryCardVariant.overlay: 'Overlay',
                  LibraryCardVariant.coverOnly: 'Cover only',
                  LibraryCardVariant.list: 'List',
                },
                value: library.cardVariant,
                onChanged: ln.setCardVariant,
              ),
              const SizedBox(height: 18),
              Text(
                'Badges',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Source label',
                  style: TextStyle(color: c.textPrimary, fontSize: 14),
                ),
                subtitle: Text(
                  'Extension / source name on covers',
                  style: TextStyle(color: c.textTertiary, fontSize: 12),
                ),
                value: library.showSourcePills,
                onChanged: ln.setShowSourcePills,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Unread badge',
                  style: TextStyle(color: c.textPrimary, fontSize: 14),
                ),
                subtitle: Text(
                  'New / unopened chapter count',
                  style: TextStyle(color: c.textTertiary, fontSize: 12),
                ),
                value: library.showUnreadBadge,
                onChanged: ln.setShowUnreadBadge,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Continue button',
                  style: TextStyle(color: c.textPrimary, fontSize: 14),
                ),
                subtitle: Text(
                  'Play control when a title has new chapters',
                  style: TextStyle(color: c.textTertiary, fontSize: 12),
                ),
                value: library.showContinueButton,
                onChanged: ln.setShowContinueButton,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

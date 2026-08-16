import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/book.dart';
import '../../core/models/library_group.dart';
import '../../core/models/manga.dart';
import '../../core/providers.dart';
import '../../core/utils/image_cache.dart';
import '../../core/utils/image_headers.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens/app_motion.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/catalog_card_layout.dart';
import '../../widgets/library_book_card.dart';
import '../../widgets/library_group_stack_card.dart';

Future<void> showLibraryGroupModal({
  required BuildContext context,
  required WidgetRef ref,
  required LibraryGroupInfo group,
  required Map<int, String?> mangaThumbnails,
  required void Function(Book book) onOpenBook,
  required void Function(Manga manga) onOpenManga,
}) {
  final reduced = ref.read(themeProvider).reducedMotion;
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierLabel: 'Close group',
      barrierColor: Colors.black.withValues(alpha: reduced ? 0.55 : 0.35),
      transitionDuration: reduced
          ? AppMotion.fast
          : const Duration(milliseconds: 420),
      reverseTransitionDuration: reduced
          ? AppMotion.fast
          : const Duration(milliseconds: 360),
      pageBuilder: (ctx, anim, secondary) {
        return _LibraryGroupModal(
          groupId: group.id,
          mangaThumbnails: mangaThumbnails,
          onOpenBook: onOpenBook,
          onOpenManga: onOpenManga,
          reducedMotion: reduced,
          routeAnimation: anim,
        );
      },
      transitionsBuilder: (ctx, anim, secondary, child) {
        if (reduced) {
          return FadeTransition(opacity: anim, child: child);
        }
        // Hero owns the card flight; route only fades the chrome in.
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: AppMotion.decelerate),
          child: child,
        );
      },
    ),
  );
}

class _LibraryGroupModal extends ConsumerStatefulWidget {
  const _LibraryGroupModal({
    required this.groupId,
    required this.mangaThumbnails,
    required this.onOpenBook,
    required this.onOpenManga,
    required this.reducedMotion,
    required this.routeAnimation,
  });

  final int groupId;
  final Map<int, String?> mangaThumbnails;
  final void Function(Book book) onOpenBook;
  final void Function(Manga manga) onOpenManga;
  final bool reducedMotion;
  final Animation<double> routeAnimation;

  @override
  ConsumerState<_LibraryGroupModal> createState() => _LibraryGroupModalState();
}

class _LibraryGroupModalState extends ConsumerState<_LibraryGroupModal> {
  late final TextEditingController _nameCtrl;
  bool _editingName = false;
  bool _reorderMode = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _findGroup()?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  LibraryGroupInfo? _findGroup() {
    for (final g in ref.read(libraryProvider).groups) {
      if (g.id == widget.groupId) return g;
    }
    return null;
  }

  Future<void> _commitName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    await ref.read(libraryProvider.notifier).renameGroup(widget.groupId, name);
    if (mounted) setState(() => _editingName = false);
  }

  Future<void> _setOrder(LibraryGroupMemberInfo member) async {
    final result = await showDialog<Object>(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _ReadingOrderDialog(
        initialText: member.readingOrder?.toString() ?? '',
      ),
    );
    if (result == null || !mounted) return;
    final notifier = ref.read(libraryProvider.notifier);
    if (result == 'clear' || (result is String && result.isEmpty)) {
      await notifier.clearGroupReadingOrder(member.memberKey);
    } else if (result is String) {
      final n = int.tryParse(result);
      if (n != null && n > 0) {
        await notifier.setGroupReadingOrder(member.memberKey, n);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(libraryProvider);
    LibraryGroupInfo? group;
    for (final g in provider.groups) {
      if (g.id == widget.groupId) {
        group = g;
        break;
      }
    }
    final c = context.colors;

    if (group == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const SizedBox.shrink();
    }

    final openGroup = group;
    final ordered = openGroup.orderedMembers;
    final booksById = {for (final b in provider.books) b.id: b};
    final mangasById = {for (final m in provider.mangas) m.id: m};
    return HeroMode(
      enabled: !widget.reducedMotion,
      child: AnimatedBuilder(
        animation: widget.routeAnimation,
        builder: (context, _) {
          final t = widget.routeAnimation.value;
          final chromeOpacity = widget.reducedMotion
              ? 1.0
              : const Interval(
                  0.35,
                  1.0,
                  curve: AppMotion.decelerate,
                ).transform(t);

          return Stack(
            fit: StackFit.expand,
            children: [
              // Blurred / dimmed backdrop — not an opaque card.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: widget.reducedMotion ? 0 : 22,
                    sigmaY: widget.reducedMotion ? 0 : 22,
                  ),
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Opacity(
                        opacity: chromeOpacity.clamp(0.0, 1.0),
                        child: _HeaderBar(
                          nameCtrl: _nameCtrl,
                          editingName: _editingName,
                          reorderMode: _reorderMode,
                          groupName: openGroup.name,
                          colors: c,
                          onToggleEdit: () =>
                              setState(() => _editingName = !_editingName),
                          onCommitName: _commitName,
                          onToggleReorder: () =>
                              setState(() => _reorderMode = !_reorderMode),
                          onDissolve: () async {
                            final nav = Navigator.of(context);
                            await ref
                                .read(libraryProvider.notifier)
                                .dissolveGroup(widget.groupId);
                            if (context.mounted) nav.maybePop();
                          },
                          onClose: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Opacity(
                        opacity: chromeOpacity.clamp(0.0, 1.0),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: Text(
                            _reorderMode
                                ? 'Drag to set reading order'
                                : 'Long-press a cover to set reading order',
                            style: TextStyle(
                              color: c.textSecondary.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _reorderMode
                            ? _ReorderList(
                                ordered: ordered,
                                booksById: booksById,
                                mangasById: mangasById,
                                colors: c,
                                onReorder: (keys) => ref
                                    .read(libraryProvider.notifier)
                                    .reorderGroupMembers(
                                      widget.groupId,
                                      keys,
                                    ),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  8,
                                  0,
                                  8,
                                  24,
                                ),
                                gridDelegate:
                                    CatalogCardLayout.gridDelegate(
                                  columns: 3,
                                  variant: LibraryCardVariant.grid,
                                ),
                                itemCount: ordered.length,
                                itemBuilder: (ctx, i) {
                                  final member = ordered[i];
                                  return _MemberTile(
                                    groupId: widget.groupId,
                                    member: member,
                                    enableHero: !widget.reducedMotion,
                                    book: member.isBook
                                        ? booksById[member.itemId]
                                        : null,
                                    manga: member.isManga
                                        ? mangasById[member.itemId]
                                        : null,
                                    localThumb: member.isManga
                                        ? widget.mangaThumbnails[member.itemId]
                                        : null,
                                    onOpen: () {
                                      if (member.isBook) {
                                        final b = booksById[member.itemId];
                                        if (b != null) {
                                          Navigator.of(context).maybePop();
                                          widget.onOpenBook(b);
                                        }
                                      } else {
                                        final m = mangasById[member.itemId];
                                        if (m != null) {
                                          Navigator.of(context).maybePop();
                                          widget.onOpenManga(m);
                                        }
                                      }
                                    },
                                    onLongPress: () => _setOrder(member),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReadingOrderDialog extends StatefulWidget {
  const _ReadingOrderDialog({required this.initialText});

  final String initialText;

  @override
  State<_ReadingOrderDialog> createState() => _ReadingOrderDialogState();
}

class _ReadingOrderDialogState extends State<_ReadingOrderDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      backgroundColor: c.bgElevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.brXl,
        side: BorderSide(color: c.border, width: 0.5),
      ),
      title: Text('Reading order', style: TextStyle(color: c.textPrimary)),
      content: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        autofocus: true,
        style: TextStyle(color: c.textPrimary),
        decoration: InputDecoration(
          labelText: 'Number (blank to clear)',
          labelStyle: TextStyle(color: c.textSecondary),
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'clear'),
          child: Text('Clear', style: TextStyle(color: c.textTertiary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: c.textTertiary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: Text('Save', style: TextStyle(color: c.accent)),
        ),
      ],
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.nameCtrl,
    required this.editingName,
    required this.reorderMode,
    required this.groupName,
    required this.colors,
    required this.onToggleEdit,
    required this.onCommitName,
    required this.onToggleReorder,
    required this.onDissolve,
    required this.onClose,
  });

  final TextEditingController nameCtrl;
  final bool editingName;
  final bool reorderMode;
  final String groupName;
  final KomaColors colors;
  final VoidCallback onToggleEdit;
  final VoidCallback onCommitName;
  final VoidCallback onToggleReorder;
  final VoidCallback onDissolve;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surface.withValues(alpha: 0.28),
      borderRadius: AppSpacing.brLg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          children: [
            Expanded(
              child: editingName
                  ? TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => onCommitName(),
                    )
                  : GestureDetector(
                      onTap: onToggleEdit,
                      child: Text(
                        groupName,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
            if (editingName)
              IconButton(
                icon: Icon(Icons.check, color: colors.accent),
                onPressed: onCommitName,
              )
            else
              IconButton(
                icon: Icon(Icons.edit_outlined, color: colors.textSecondary),
                tooltip: 'Rename group',
                onPressed: onToggleEdit,
              ),
            IconButton(
              icon: Icon(
                reorderMode ? Icons.check_circle_outline : Icons.swap_vert,
                color: colors.textSecondary,
              ),
              tooltip: reorderMode ? 'Done reordering' : 'Reorder by drag',
              onPressed: onToggleReorder,
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: colors.textTertiary),
              tooltip: 'Dissolve group',
              onPressed: onDissolve,
            ),
            IconButton(
              icon: Icon(Icons.close, color: colors.textSecondary),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReorderList extends StatelessWidget {
  const _ReorderList({
    required this.ordered,
    required this.booksById,
    required this.mangasById,
    required this.colors,
    required this.onReorder,
  });

  final List<LibraryGroupMemberInfo> ordered;
  final Map<int, Book> booksById;
  final Map<int, Manga> mangasById;
  final KomaColors colors;
  final Future<void> Function(List<String> keys) onReorder;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
      itemCount: ordered.length,
      onReorderItem: (oldIndex, newIndex) async {
        final keys = ordered.map((m) => m.memberKey).toList();
        final item = keys.removeAt(oldIndex);
        keys.insert(newIndex, item);
        await onReorder(keys);
      },
      itemBuilder: (ctx, i) {
        final member = ordered[i];
        final title = member.isBook
            ? (booksById[member.itemId]?.title ?? 'Book')
            : (mangasById[member.itemId]?.name ?? 'Manga');
        return Material(
          key: ValueKey(member.memberKey),
          type: MaterialType.transparency,
          child: ListTile(
            leading: ReadingOrderPill(
              order: member.readingOrder ?? (i + 1),
            ),
            title: Text(title, style: TextStyle(color: colors.textPrimary)),
            trailing: Icon(Icons.drag_handle, color: colors.textTertiary),
          ),
        );
      },
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.groupId,
    required this.member,
    required this.onOpen,
    required this.onLongPress,
    required this.enableHero,
    this.book,
    this.manga,
    this.localThumb,
  });

  final int groupId;
  final LibraryGroupMemberInfo member;
  final Book? book;
  final Manga? manga;
  final String? localThumb;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;
  final bool enableHero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final title = book?.title ?? manga?.name ?? 'Item';
    final headers = manga != null
        ? ref.watch(sourceImageHeadersProvider(manga!.sourceId)).value
        : null;

    final cover = ClipRRect(
      borderRadius: AppSpacing.brMd,
      child: book != null
          ? BookCover(
              book: book!,
              variant: BookCoverVariant.grid,
              expand: true,
            )
          : localThumb != null
          ? Image.file(
              File(localThumb!),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(color: c.surfaceMuted),
            )
          : manga?.imageUrl != null && manga!.imageUrl!.isNotEmpty
          ? Image(
              image: cachedCover(manga!.imageUrl!, headers: headers),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(color: c.surfaceMuted),
            )
          : ColoredBox(color: c.surfaceMuted),
    );

    final heroCover = enableHero
        ? Hero(
            tag: LibraryGroupStackCard.coverHeroTag(
              groupId,
              member.memberKey,
            ),
            createRectTween: (begin, end) =>
                MaterialRectArcTween(begin: begin, end: end),
            child: Material(
              type: MaterialType.transparency,
              child: cover,
            ),
          )
        : cover;

    return AnimatedPress(
      onTap: onOpen,
      onLongPress: onLongPress,
      scaleDown: 0.97,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                heroCover,
                if (member.readingOrder != null)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: ReadingOrderPill(order: member.readingOrder!),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

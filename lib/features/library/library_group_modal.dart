import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/book.dart';
import '../../core/models/library_group.dart';
import '../../core/models/manga.dart';
import '../../core/providers.dart';
import '../../core/services/group_display_prefs.dart';
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

enum _GroupMemberSort { readingOrder, alphabetical, author }

LibraryCardVariant _groupCardVariant(GroupDisplayMode mode) =>
    switch (mode) {
      GroupDisplayMode.overlay => LibraryCardVariant.overlay,
      GroupDisplayMode.coverOnly => LibraryCardVariant.coverOnly,
    };

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
  _GroupMemberSort _sort = _GroupMemberSort.readingOrder;

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

  Future<void> _showDisplaySheet() async {
    final current =
        ref.read(groupDisplayProvider).value ??
        const GroupDisplaySettings();
    final result = await showModalBottomSheet<GroupDisplaySettings>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GroupDisplaySheet(settings: current),
    );
    if (result == null || !mounted) return;
    await ref.read(groupDisplayProvider.notifier).setSettings(result);
  }

  List<LibraryGroupMemberInfo> _sortedMembers(
    LibraryGroupInfo group,
    Map<int, Book> booksById,
    Map<int, Manga> mangasById,
  ) {
    final members = List<LibraryGroupMemberInfo>.from(group.orderedMembers);
    if (_sort == _GroupMemberSort.readingOrder) return members;

    String titleOf(LibraryGroupMemberInfo m) {
      if (m.isBook) return booksById[m.itemId]?.title ?? '';
      return mangasById[m.itemId]?.name ?? '';
    }

    String authorOf(LibraryGroupMemberInfo m) {
      if (m.isBook) return booksById[m.itemId]?.author ?? '';
      final manga = mangasById[m.itemId];
      return manga?.author ?? manga?.artist ?? '';
    }

    members.sort((a, b) {
      final cmp = switch (_sort) {
        _GroupMemberSort.alphabetical =>
          titleOf(a).toLowerCase().compareTo(titleOf(b).toLowerCase()),
        _GroupMemberSort.author =>
          authorOf(a).toLowerCase().compareTo(authorOf(b).toLowerCase()),
        _GroupMemberSort.readingOrder => 0,
      };
      if (cmp != 0) return cmp;
      return titleOf(a).toLowerCase().compareTo(titleOf(b).toLowerCase());
    });
    return members;
  }

  Future<void> _memberActions(LibraryGroupMemberInfo member) async {
    final c = context.colors;
    final title = () {
      final group = _findGroup();
      if (group == null) return 'Title';
      final provider = ref.read(libraryProvider);
      if (member.isBook) {
        for (final b in provider.books) {
          if (b.id == member.itemId) return b.title;
        }
      } else {
        for (final m in provider.mangas) {
          if (m.id == member.itemId) return m.name;
        }
      }
      return 'Title';
    }();

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.format_list_numbered, color: c.textSecondary),
              title: Text(
                'Reading order',
                style: TextStyle(color: c.textPrimary),
              ),
              onTap: () => Navigator.pop(ctx, 'order'),
            ),
            ListTile(
              leading: Icon(Icons.remove_circle_outline, color: c.accent),
              title: Text(
                'Remove from group',
                style: TextStyle(color: c.textPrimary),
              ),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'order') {
      await _setOrder(member);
    } else if (action == 'remove') {
      await ref
          .read(libraryProvider.notifier)
          .removeFromGroup(member.memberKey);
    }
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

  Future<void> _addTitles() async {
    final group = _findGroup();
    if (group == null) return;
    final provider = ref.read(libraryProvider);
    final inGroup = {for (final m in group.members) m.memberKey};
    final candidates = <({String key, String title, String subtitle})>[
      for (final b in provider.books)
        if (!inGroup.contains(LibraryGroupMemberInfo.keyForBook(b.id)))
          (
            key: LibraryGroupMemberInfo.keyForBook(b.id),
            title: b.title,
            subtitle: b.author?.isNotEmpty == true ? b.author! : 'Book',
          ),
      for (final m in provider.mangas)
        if (!inGroup.contains(LibraryGroupMemberInfo.keyForManga(m.id)))
          (
            key: LibraryGroupMemberInfo.keyForManga(m.id),
            title: m.name,
            subtitle: m.author?.isNotEmpty == true
                ? m.author!
                : (m.artist ?? 'Manga'),
          ),
    ];
    candidates.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    if (candidates.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Every library title is already here')),
      );
      return;
    }

    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddTitlesSheet(candidates: candidates),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    await ref
        .read(libraryProvider.notifier)
        .addMembersToGroup(widget.groupId, picked.toList());
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
    final booksById = {for (final b in provider.books) b.id: b};
    final mangasById = {for (final m in provider.mangas) m.id: m};
    final ordered = _reorderMode
        ? openGroup.orderedMembers
        : _sortedMembers(openGroup, booksById, mangasById);
    final groupDisplay =
        ref.watch(groupDisplayProvider).value ??
        const GroupDisplaySettings();
    final cardVariant = _groupCardVariant(groupDisplay.mode);
    return HeroMode(
      enabled: !widget.reducedMotion,
      child: Material(
        type: MaterialType.transparency,
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

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Scrim during open — full-screen BackdropFilter over the
                  // IndexedStack shell hitchs the route animation on mid devices.
                  IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black.withValues(
                        alpha: widget.reducedMotion ? 0.45 : 0.45 * t.clamp(0.0, 1.0),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Absorb taps so header controls don't also dismiss.
                          GestureDetector(
                            onTap: () {},
                            child: Opacity(
                              opacity: chromeOpacity.clamp(0.0, 1.0),
                              child: _HeaderBar(
                                nameCtrl: _nameCtrl,
                                editingName: _editingName,
                                reorderMode: _reorderMode,
                                sort: _sort,
                                groupName: openGroup.name,
                                colors: c,
                                onToggleEdit: () => setState(
                                  () => _editingName = !_editingName,
                                ),
                                onCommitName: _commitName,
                                onSortChanged: (s) => setState(() {
                                  _sort = s;
                                  if (s != _GroupMemberSort.readingOrder) {
                                    _reorderMode = false;
                                  }
                                }),
                                onOpenLayout: _showDisplaySheet,
                                onAddTitles: _addTitles,
                                onToggleReorder: () => setState(() {
                                  _reorderMode = !_reorderMode;
                                  if (_reorderMode) {
                                    _sort = _GroupMemberSort.readingOrder;
                                  }
                                }),
                                onDissolve: () async {
                                  final nav = Navigator.of(context);
                                  await ref
                                      .read(libraryProvider.notifier)
                                      .dissolveGroup(widget.groupId);
                                  if (context.mounted) nav.maybePop();
                                },
                                onClose: () =>
                                    Navigator.of(context).maybePop(),
                              ),
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
                                    : _editingName
                                        ? 'Edit the name, then tap the check'
                                        : 'Tap the title to rename · long-press a cover to reorder or remove',
                                style: TextStyle(
                                  color: c.textSecondary.withValues(
                                    alpha: 0.9,
                                  ),
                                  fontSize: 12,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: _reorderMode
                                ? GestureDetector(
                                    onTap: () {},
                                    child: _ReorderList(
                                      ordered: openGroup.orderedMembers,
                                      booksById: booksById,
                                      mangasById: mangasById,
                                      colors: c,
                                      onReorder: (keys) => ref
                                          .read(libraryProvider.notifier)
                                          .reorderGroupMembers(
                                            widget.groupId,
                                            keys,
                                          ),
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
                                      columns: groupDisplay.columns,
                                      variant: cardVariant,
                                    ),
                                    itemCount: ordered.length,
                                    itemBuilder: (ctx, i) {
                                      final member = ordered[i];
                                      return _MemberTile(
                                        groupId: widget.groupId,
                                        member: member,
                                        display: groupDisplay.mode,
                                        enableHero: !widget.reducedMotion,
                                        book: member.isBook
                                            ? booksById[member.itemId]
                                            : null,
                                        manga: member.isManga
                                            ? mangasById[member.itemId]
                                            : null,
                                        localThumb: member.isManga
                                            ? widget.mangaThumbnails[
                                                member.itemId]
                                            : null,
                                        onOpen: () {
                                          if (member.isBook) {
                                            final b =
                                                booksById[member.itemId];
                                            if (b != null) {
                                              Navigator.of(context)
                                                  .maybePop();
                                              widget.onOpenBook(b);
                                            }
                                          } else {
                                            final m =
                                                mangasById[member.itemId];
                                            if (m != null) {
                                              Navigator.of(context)
                                                  .maybePop();
                                              widget.onOpenManga(m);
                                            }
                                          }
                                        },
                                        onLongPress: () =>
                                            _memberActions(member),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
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
    required this.sort,
    required this.groupName,
    required this.colors,
    required this.onToggleEdit,
    required this.onCommitName,
    required this.onSortChanged,
    required this.onOpenLayout,
    required this.onAddTitles,
    required this.onToggleReorder,
    required this.onDissolve,
    required this.onClose,
  });

  final TextEditingController nameCtrl;
  final bool editingName;
  final bool reorderMode;
  final _GroupMemberSort sort;
  final String groupName;
  final KomaColors colors;
  final VoidCallback onToggleEdit;
  final VoidCallback onCommitName;
  final ValueChanged<_GroupMemberSort> onSortChanged;
  final VoidCallback onOpenLayout;
  final VoidCallback onAddTitles;
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
                        decoration: TextDecoration.none,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
            ),
            if (editingName)
              IconButton(
                icon: Icon(Icons.check, color: colors.accent),
                onPressed: onCommitName,
              )
            else ...[
              PopupMenuButton<_GroupMemberSort>(
                tooltip: 'Sort titles',
                icon: Icon(Icons.sort_rounded, color: colors.textSecondary),
                onSelected: onSortChanged,
                itemBuilder: (ctx) => [
                  CheckedPopupMenuItem(
                    value: _GroupMemberSort.readingOrder,
                    checked: sort == _GroupMemberSort.readingOrder,
                    child: const Text('Reading order'),
                  ),
                  CheckedPopupMenuItem(
                    value: _GroupMemberSort.alphabetical,
                    checked: sort == _GroupMemberSort.alphabetical,
                    child: const Text('A–Z'),
                  ),
                  CheckedPopupMenuItem(
                    value: _GroupMemberSort.author,
                    checked: sort == _GroupMemberSort.author,
                    child: const Text('Author'),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.playlist_add_outlined, color: colors.accent),
                tooltip: 'Add titles',
                onPressed: onAddTitles,
              ),
              IconButton(
                icon: Icon(Icons.grid_view_rounded, color: colors.textSecondary),
                tooltip: 'Group display',
                onPressed: onOpenLayout,
              ),
              IconButton(
                icon: Icon(
                  reorderMode ? Icons.check_circle_outline : Icons.swap_vert,
                  color: colors.textSecondary,
                ),
                tooltip: reorderMode ? 'Done reordering' : 'Reorder by drag',
                onPressed: onToggleReorder,
              ),
            ],
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
            title: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                decoration: TextDecoration.none,
              ),
            ),
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
    required this.display,
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
  final GroupDisplayMode display;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final title = book?.title ?? manga?.name ?? 'Item';
    final headers = manga != null
        ? ref.watch(sourceImageHeadersProvider(manga!.sourceId)).value
        : null;
    final showTitle = display == GroupDisplayMode.overlay;

    final mangaImage = manga == null
        ? null
        : mangaCoverProvider(
            manga!,
            localThumbPath: localThumb,
            headers: headers,
          );
    final cover = ClipRRect(
      borderRadius: AppSpacing.brMd,
      child: book != null
          ? BookCover(
              book: book!,
              variant: BookCoverVariant.grid,
              expand: true,
            )
          : mangaImage != null
          ? Image(
              image: mangaImage,
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
      child: ClipRRect(
        borderRadius: AppSpacing.brMd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            heroCover,
            if (showTitle) ...[
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xBF000000),
                      Color(0x59000000),
                      Color(0x00000000),
                    ],
                    stops: [0.0, 0.4, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    decoration: TextDecoration.none,
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black54,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (member.readingOrder != null)
              Positioned(
                top: 6,
                left: 6,
                child: ReadingOrderPill(order: member.readingOrder!),
              ),
          ],
        ),
      ),
    );
  }
}

/// Minimal group-only layout sheet: columns (2/3) + overlay / cover-only.
class _GroupDisplaySheet extends StatefulWidget {
  const _GroupDisplaySheet({required this.settings});

  final GroupDisplaySettings settings;

  @override
  State<_GroupDisplaySheet> createState() => _GroupDisplaySheetState();
}

class _GroupDisplaySheetState extends State<_GroupDisplaySheet> {
  late int _columns = widget.settings.columns;
  late GroupDisplayMode _display = widget.settings.mode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Group display',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Columns',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 2, label: Text('2')),
                  ButtonSegment(value: 3, label: Text('3')),
                ],
                selected: {_columns},
                onSelectionChanged: (s) => setState(() => _columns = s.first),
              ),
              const SizedBox(height: 18),
              Text(
                'Display mode',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<GroupDisplayMode>(
                segments: const [
                  ButtonSegment(
                    value: GroupDisplayMode.overlay,
                    label: Text('Overlay'),
                    icon: Icon(Icons.title_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: GroupDisplayMode.coverOnly,
                    label: Text('Cover only'),
                    icon: Icon(Icons.image_outlined, size: 18),
                  ),
                ],
                selected: {_display},
                onSelectionChanged: (s) => setState(() => _display = s.first),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  GroupDisplaySettings(columns: _columns, mode: _display),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: c.onAccent,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTitlesSheet extends StatefulWidget {
  const _AddTitlesSheet({required this.candidates});

  final List<({String key, String title, String subtitle})> candidates;

  @override
  State<_AddTitlesSheet> createState() => _AddTitlesSheetState();
}

class _AddTitlesSheetState extends State<_AddTitlesSheet> {
  final Set<String> _selected = {};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final q = _query.trim().toLowerCase();
    final filtered = [
      for (final item in widget.candidates)
        if (q.isEmpty ||
            item.title.toLowerCase().contains(q) ||
            item.subtitle.toLowerCase().contains(q))
          item,
    ];
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add titles',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selected),
                    child: Text(
                      _selected.isEmpty
                          ? 'Add'
                          : 'Add (${_selected.length})',
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search library…',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No matching titles',
                        style: TextStyle(color: c.textTertiary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final item = filtered[i];
                        final on = _selected.contains(item.key);
                        return CheckboxListTile(
                          value: on,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(item.key);
                            } else {
                              _selected.remove(item.key);
                            }
                          }),
                          title: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.textPrimary),
                          ),
                          subtitle: Text(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/library_group.dart';
import '../../core/providers.dart';
import '../../core/utils/image_cache.dart';
import '../../router/book_navigation.dart';
import '../../router/router.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../widgets/catalog_card_layout.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_button_round.dart';
import '../../widgets/library_group_stack_card.dart';
import '../../widgets/screen_chrome.dart';
import 'library_group_modal.dart';
import 'library_provider.dart';

/// Kenji-style Collections hub over [LibraryGroupInfo] stacks.
class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<LibraryGroupInfo> _filtered(List<LibraryGroupInfo> groups) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return groups;
    return groups.where((g) => g.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _createCollectionHint() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        return AlertDialog(
          backgroundColor: c.surface,
          title: Text(
            'Create a collection',
            style: TextStyle(color: c.textPrimary),
          ),
          content: Text(
            'In Library, long-press titles to multi-select (2+), then tap the '
            'layers icon to create a collection.',
            style: TextStyle(color: c.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Got it', style: TextStyle(color: c.accent)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final library = ref.watch(libraryProvider);
    final groups = library.groups;
    final visible = _filtered(groups);

    return ScreenBackdrop(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  IconButtonRound(
                    icon: Icons.arrow_back_ios_new,
                    size: 40,
                    variant: IconButtonVariant.plain,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _searching
                        ? TextField(
                            controller: _searchCtrl,
                            autofocus: true,
                            style: TextStyle(color: c.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Search collections',
                              hintStyle: TextStyle(color: c.textTertiary),
                              border: InputBorder.none,
                            ),
                            onChanged: (_) => setState(() {}),
                          )
                        : Text(
                            'Collections',
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.5,
                            ),
                          ),
                  ),
                  IconButtonRound(
                    icon: _searching ? Icons.close : Icons.search,
                    size: 40,
                    variant: IconButtonVariant.plain,
                    onPressed: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) {
                        _searchCtrl.clear();
                      }
                    }),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: c.surfaceMuted,
                    borderRadius: BorderRadius.circular(64),
                    child: InkWell(
                      onTap: _createCollectionHint,
                      borderRadius: BorderRadius.circular(64),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.create_new_folder_outlined,
                              size: 22,
                              color: c.textPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Add',
                              style: TextStyle(
                                color: c.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? EmptyState(
                      icon: AppIcons.library,
                      emoji: '📂',
                      title: groups.isEmpty
                          ? 'You have not made a collection'
                          : 'No matching collections',
                      subtitle: groups.isEmpty
                          ? 'You have not created collections for your titles yet.'
                          : 'Try another search.',
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.72,
                          ),
                      itemCount: visible.length,
                      itemBuilder: (context, i) {
                        final g = visible[i];
                        return StaggeredFadeScale(
                          index: i,
                          child: LibraryGroupStackCard(
                            groupId: g.id,
                            name: g.name,
                            memberCount: g.members.length,
                            covers: _covers(g, library),
                            variant: CatalogCardLayout.gridVariant(
                              library.cardVariant,
                            ),
                            minimalChrome: library.minimalCards,
                            showSourcePills: library.showCardChrome,
                            onTap: () => showLibraryGroupModal(
                              context: context,
                              ref: ref,
                              group: g,
                              mangaThumbnails: const {},
                              onOpenBook: (book) =>
                                  openBookFromCollection(context, book.id),
                              onOpenManga: (manga) {
                                context.pushNamed(
                                  Routes.mangaDetail,
                                  extra: (
                                    sourceId: manga.sourceId,
                                    url: manga.url,
                                    title: manga.name,
                                    manga: manga,
                                    memo: manga.memo,
                                  ) as MangaDetailArgs,
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<GroupCoverSlot> _covers(LibraryGroupInfo group, LibraryState library) {
    final booksById = {for (final b in library.books) b.id: b};
    final mangasById = {for (final m in library.mangas) m.id: m};
    final slots = <GroupCoverSlot>[];
    for (final m in group.orderedMembers) {
      if (m.isBook) {
        final book = booksById[m.itemId];
        if (book == null) continue;
        final path = book.coverPath;
        final ext = book.fileExtension.trim();
        slots.add(
          GroupCoverSlot(
            title: book.title,
            memberKey: m.memberKey,
            readingOrder: m.readingOrder,
            image: path != null && path.isNotEmpty && File(path).existsSync()
                ? FileImage(File(path))
                : null,
            badge: ext.isNotEmpty ? ext.toUpperCase() : null,
          ),
        );
      } else {
        final manga = mangasById[m.itemId];
        if (manga == null) continue;
        ImageProvider? image;
        final custom = manga.customCoverPath;
        if (custom != null && custom.isNotEmpty && File(custom).existsSync()) {
          image = FileImage(File(custom));
        } else if (manga.imageUrl != null && manga.imageUrl!.isNotEmpty) {
          image = cachedCover(manga.imageUrl!);
        }
        slots.add(
          GroupCoverSlot(
            title: manga.name,
            memberKey: m.memberKey,
            readingOrder: m.readingOrder,
            image: image,
            badge: library.isNovelManga(manga)
                ? 'Novel'
                : (library.extensionNames[manga.sourceId] ?? manga.sourceId),
          ),
        );
      }
    }
    return slots;
  }
}

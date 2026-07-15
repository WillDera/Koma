import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/book.dart';
import '../../core/services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/dialog_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/library_header.dart';
import '../../widgets/one_hand_spacer.dart';
import '../../widgets/progress_ring.dart';
import '../reader/reader_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Book> _books = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = context.read<DatabaseService>();
    _books = await db.getInProgressBooks();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _clearProgress(Book book) async {
    final confirmed = await StashDialog.show<bool>(
      context,
      title: 'Clear reading history?',
      content:
          'Remove "${book.title}" from your history. '
          'The book and its chapters will be kept.',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Clear'),
        ),
      ],
    );
    if (confirmed != true) return;
    final db = context.read<DatabaseService>();
    await db.clearProgress(book.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_books.isEmpty) {
      return SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const OneHandSpacer(),
            const LibraryHeader(title: 'History'),
            const SizedBox(height: 80),
            const EmptyState(
              icon: Icons.history,
              title: 'No reading history',
              subtitle: 'Books you\'re reading will appear here',
            ),
          ],
        ),
      );
    }
    final count = _books.length;
    return SafeArea(
      bottom: false,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: count + 1,
        separatorBuilder: (_, i) =>
            i == 0 ? const SizedBox.shrink() : const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return Column(
              children: [
                const OneHandSpacer(),
                LibraryHeader(title: 'History', subtitle: '$count in progress'),
                const SizedBox(height: 8),
              ],
            );
          }
          final book = _books[i - 1];
          final pct = (book.progress * 100).toInt();
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: AnimatedPress(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReaderScreen(bookId: book.id),
                ),
              ).then((_) => _load()),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 64,
                      child: BookCover(
                        book: book,
                        variant: BookCoverVariant.compact,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (book.author != null && book.author!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                book.author!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ThinProgressBar(
                                  progress: book.progress,
                                  height: 4,
                                  color: c.accent,
                                  trackColor: c.border,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$pct%',
                                style: TextStyle(
                                  color: c.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: c.textTertiary,
                        ),
                        onPressed: () => _clearProgress(book),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';

export 'book_navigation_policy.dart';

/// Opens collection-level book metadata consistently across library/history.
///
/// The detail screen itself decides whether to show persisted sections. Its
/// Read/Continue action always opens the reader, including for books with no
/// usable section structure.
void openBookFromCollection(BuildContext context, int bookId) {
  context.pushNamed(Routes.bookDetail, extra: (bookId: bookId));
}

/// Opens the existing reader with an optional real persisted chapter target.
void openBookReader(
  BuildContext context, {
  required int bookId,
  int? chapterId,
}) {
  context.pushNamed(
    Routes.reader,
    extra:
        (
              bookId: bookId,
              snippetChapterId: chapterId,
              snippetScrollOffset: null,
              snippetStartOffset: null,
              snippetEndOffset: null,
            )
            as ReaderArgs,
  );
}

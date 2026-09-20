import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/services/library_duplicate_detector.dart';
import 'package:koma/core/services/merge_manga_use_case.dart';

void main() {
  group('normTitle', () {
    test('lowercase, strip punctuation, collapse spaces', () {
      expect(
        LibraryDuplicateDetector.normTitle('  The  Night!  '),
        'the night',
      );
    });

    test('strips trailing volume/chapter noise and brackets', () {
      expect(
        LibraryDuplicateDetector.normTitle('Solo Leveling Vol. 2'),
        'solo leveling',
      );
      expect(
        LibraryDuplicateDetector.normTitle('Title Chapter 12'),
        'title',
      );
      expect(
        LibraryDuplicateDetector.normTitle('Foo (Official)'),
        'foo',
      );
    });

    test('compatible with titlesLookCompatible base cases', () {
      expect(MergeMangaUseCase.titlesLookCompatible('Overlord!', 'overlord'), isTrue);
      expect(
        MergeMangaUseCase.titlesLookCompatible(
          'Absolute Wonder Woman (2024-)',
          'Absolute Batman (2024-)',
        ),
        isFalse,
      );
    });
  });

  group('fingerprint', () {
    test('title only (author ignored for key)', () {
      expect(LibraryDuplicateDetector.fingerprint('Foo Bar'), 'foo bar');
      expect(
        LibraryDuplicateDetector.fingerprint('Foo', 'Jane Doe'),
        'foo',
      );
    });
  });

  group('isLikelyDuplicate', () {
    test('cross-source same title', () {
      expect(
        LibraryDuplicateDetector.isLikelyDuplicate(
          const LibraryDuplicateCandidate(
            id: 1,
            name: 'One Piece',
            author: 'Oda',
            sourceId: 'a',
            url: '/a',
          ),
          const LibraryDuplicateCandidate(
            id: 2,
            name: 'One Piece',
            sourceId: 'b',
            url: '/b',
          ),
        ),
        isTrue,
      );
    });

    test('same-source different urls still counts', () {
      expect(
        LibraryDuplicateDetector.isLikelyDuplicate(
          const LibraryDuplicateCandidate(
            id: 1,
            name: 'One Piece',
            sourceId: 'a',
            url: '/1',
          ),
          const LibraryDuplicateCandidate(
            id: 2,
            name: 'One Piece',
            sourceId: 'a',
            url: '/2',
          ),
        ),
        isTrue,
      );
    });

    test('identical row does not', () {
      expect(
        LibraryDuplicateDetector.isLikelyDuplicate(
          const LibraryDuplicateCandidate(
            id: 1,
            name: 'One Piece',
            sourceId: 'a',
            url: '/1',
          ),
          const LibraryDuplicateCandidate(
            id: 1,
            name: 'One Piece',
            sourceId: 'a',
            url: '/1',
          ),
        ),
        isFalse,
      );
    });

    test('matches via alternate title', () {
      expect(
        LibraryDuplicateDetector.isLikelyDuplicate(
          const LibraryDuplicateCandidate(
            id: 1,
            name: 'SL',
            sourceId: 'a',
            url: '/a',
            alternateTitles: ['Solo Leveling'],
          ),
          const LibraryDuplicateCandidate(
            id: 2,
            name: 'Solo Leveling',
            sourceId: 'b',
            url: '/b',
          ),
        ),
        isTrue,
      );
    });

    test('Absolute Wonder Woman vs Absolute Batman are not duplicates', () {
      expect(
        LibraryDuplicateDetector.isLikelyDuplicate(
          const LibraryDuplicateCandidate(
            id: 1,
            name: 'Absolute Wonder Woman (2024-)',
            sourceId: 'a',
            url: '/ww',
          ),
          const LibraryDuplicateCandidate(
            id: 2,
            name: 'Absolute Batman (2024-)',
            sourceId: 'b',
            url: '/bat',
          ),
        ),
        isFalse,
      );
    });
  });

  group('findGroups', () {
    test('returns cross-source groups of 2+', () {
      final groups = LibraryDuplicateDetector.findGroups([
        const LibraryDuplicateCandidate(
          id: 1,
          name: 'Solo Leveling',
          author: 'Chugong',
          sourceId: 'src-a',
          url: '/a',
        ),
        const LibraryDuplicateCandidate(
          id: 2,
          name: 'Solo Leveling Vol. 1',
          author: 'Chugong',
          sourceId: 'src-b',
          url: '/b',
        ),
        const LibraryDuplicateCandidate(
          id: 3,
          name: 'Other',
          sourceId: 'src-a',
          url: '/c',
        ),
      ]);
      expect(groups, hasLength(1));
      expect(groups.first.items.map((e) => e.id).toSet(), {1, 2});
    });
  });
}

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/manga.dart';
import '../core/models/manga_chapter.dart';
import '../core/providers.dart';
import '../core/recommendations/library_hub_models.dart';
import '../core/recommendations/library_hub_providers.dart';
import '../core/recommendations/recommendation_navigation.dart';
import '../core/utils/chapter_recognition.dart';
import '../core/utils/cached_network.dart';
import '../core/utils/image_cache.dart';
import '../core/utils/image_headers.dart';
import '../router/book_navigation.dart';
import '../router/router.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';
import 'catalog_card_layout.dart';
import 'catalog_cover_card.dart';
import 'screen_chrome.dart';
import 'toast.dart';

/// Three-face circular hub for Continue / Library for you / Explore.
class LibraryHubRing extends ConsumerStatefulWidget {
  const LibraryHubRing({
    super.key,
    required this.snapshot,
    this.mangaThumbnails = const {},
    this.minimalChrome = false,
    this.loading = false,
  });

  final LibraryHubSnapshot snapshot;
  final Map<int, String?> mangaThumbnails;
  final bool minimalChrome;
  final bool loading;

  @override
  ConsumerState<LibraryHubRing> createState() => _LibraryHubRingState();
}

class _LibraryHubRingState extends ConsumerState<LibraryHubRing>
    with SingleTickerProviderStateMixin {
  /// Radians; 0 = face 0 in front.
  double _angle = 0;
  double _dragStartAngle = 0;
  double _pointerStartX = 0;
  double _lastPointerX = 0;
  double _lastPointerAtMs = 0;
  double _velocity = 0; // rad / ms
  bool _dragMoved = false;
  bool _suppressCardTap = false;
  /// Hide orbit cards while the expand overlay owns the peel animation so we
  /// don't show ghost duplicates behind the barrier.
  bool _orbitSuppressed = false;
  final GlobalKey _orbitStackKey = GlobalKey();
  late final AnimationController _settle;
  Animation<double>? _settleAnim;

  static const _cardW = 168.0;
  static const _cardH = 260.0;
  static const _radius = 128.0;
  static const _step = 2 * math.pi / 3;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(vsync: this);
    _settle.addListener(_onSettleTick);
    loadHubAngle().then((a) {
      if (mounted) setState(() => _angle = a);
    });
  }

  @override
  void dispose() {
    _settle.removeListener(_onSettleTick);
    _settle.dispose();
    super.dispose();
  }

  void _onSettleTick() {
    final anim = _settleAnim;
    if (anim == null || !mounted) return;
    setState(() => _angle = anim.value);
  }

  void _snapToNearest({double velocityRadPerMs = 0}) {
    // Bias snap in the fling direction when the user released with speed.
    var target = (_angle / _step).round() * _step;
    if (velocityRadPerMs.abs() > 0.0015) {
      final dir = velocityRadPerMs.isNegative ? -1.0 : 1.0;
      final projected = _angle + dir * _step * 0.35;
      target = (projected / _step).round() * _step;
    }

    final begin = _angle;
    final distance = (target - begin).abs();
    if (distance < 0.001) {
      _angle = target;
      saveHubAngle(_angle);
      return;
    }

    // Longer, softer settle — distance-aware so short nudges aren't sluggish.
    final ms = (280 + distance * 180).clamp(280, 520).round();
    _settle.stop();
    _settle.duration = Duration(milliseconds: ms);
    _settleAnim = Tween<double>(begin: begin, end: target).animate(
      CurvedAnimation(
        parent: _settle,
        // Soft deceleration — less "snappy" than emphasized.
        curve: Curves.easeOutCubic,
      ),
    );
    _settle.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() => _angle = target);
      _settleAnim = null;
      saveHubAngle(_angle);
    });
  }

  int get _frontIndex {
    var best = 0;
    var bestCos = -2.0;
    for (var i = 0; i < 3; i++) {
      final c = math.cos(_angle - i * _step);
      if (c > bestCos) {
        bestCos = c;
        best = i;
      }
    }
    return best;
  }

  Future<void> _onRead(LibraryHubFace face) async {
    if (face.isEmpty) {
      if (!mounted) return;
      StashToast.show(
        context,
        message: 'Nothing to read in ${face.title} yet',
        icon: Icons.info_outline,
      );
      return;
    }
    // Continue: most-recent title. Other faces: cover match what the card shows.
    final entry = face.kind == LibraryHubKind.continueReading
        ? face.entries.first
        : (face.coverEntry ?? face.entries.first);
    await openLibraryHubRead(context, ref, entry);
  }

  Future<void> _onOpenCover(LibraryHubFace face) async {
    if (face.isEmpty) {
      if (!mounted) return;
      StashToast.show(
        context,
        message: 'Nothing in ${face.title} yet',
        icon: Icons.info_outline,
      );
      return;
    }
    final entry = face.coverEntry ?? face.entries.first;
    await openLibraryHubEntry(context, ref, entry);
  }

  Future<void> _onViewMore(LibraryHubFace face) async {
    if (face.isEmpty) {
      if (!mounted) return;
      StashToast.show(
        context,
        message: 'Nothing in ${face.title} yet',
        icon: Icons.info_outline,
      );
      return;
    }
    final faces = widget.snapshot.faces;
    final front = _frontIndex;
    // Neighbors on the ring (sin < 0 → left, sin > 0 → right).
    final leftIdx = (front + 1) % 3;
    final rightIdx = (front + 2) % 3;
    final leftRect = _orbitFaceGlobalRect(leftIdx);
    final rightRect = _orbitFaceGlobalRect(rightIdx);
    // Hide orbit and present peel cards in the same frame so the side
    // cards appear to detach rather than leave ghost copies behind.
    setState(() => _orbitSuppressed = true);
    try {
      await showLibraryHubExpand(
        context,
        face: face,
        leftFace: faces[leftIdx],
        leftCover: _coverImage(faces[leftIdx].coverEntry),
        leftRect: leftRect,
        rightFace: faces[rightIdx],
        rightCover: _coverImage(faces[rightIdx].coverEntry),
        rightRect: rightRect,
        mangaThumbnails: widget.mangaThumbnails,
        onOpenEntry: (e) => openLibraryHubEntry(context, ref, e),
        onRead: () => _onRead(face),
        // Restore orbit as soon as dismiss starts — no peel-in on close.
        onDismissStart: () {
          if (mounted) setState(() => _orbitSuppressed = false);
        },
      );
    } finally {
      if (mounted) setState(() => _orbitSuppressed = false);
    }
  }

  /// Screen rect of an orbit card (Transform is paint-only, so we compute).
  Rect? _orbitFaceGlobalRect(int faceIndex) {
    final box = _orbitStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    final localAngle = _angle - faceIndex * _step;
    final rawDepth = ((math.cos(localAngle) + 1) / 2).clamp(0.0, 1.0);
    final depth = Curves.easeOut.transform(rawDepth);
    final x = math.sin(localAngle) * _radius;
    final scale = 0.78 + 0.22 * depth;
    final y = (1 - depth) * 10;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    return Rect.fromCenter(
      center: center + Offset(x, y),
      width: _cardW * scale,
      height: _cardH * scale,
    );
  }

  ImageProvider? _coverImage(LibraryHubEntry? entry) {
    if (entry == null) return null;
    final manga = entry.mangaRef;
    if (manga != null) {
      final headers =
          ref.watch(sourceImageHeadersProvider(manga.sourceId)).value;
      final thumb = widget.mangaThumbnails[manga.id];
      return mangaCoverProvider(
        manga,
        localThumbPath: thumb,
        headers: headers,
      );
    }
    final bookPath = entry.book?.coverPath?.trim();
    if (bookPath != null && bookPath.isNotEmpty) {
      // Match library rails: only require the file when treating as local.
      if (hubCoverIsLocalFile(bookPath)) {
        if (hubLocalCoverExists(bookPath)) {
          return FileImage(File(hubLocalCoverPath(bookPath)));
        }
      } else {
        return coverProvider(bookPath);
      }
    }
    final url = hubCoverUrl(entry);
    if (url == null || url.isEmpty) return null;
    if (hubCoverIsLocalFile(url)) {
      if (!hubLocalCoverExists(url)) return null;
      return FileImage(File(hubLocalCoverPath(url)));
    }
    return coverProvider(url);
  }

  @override
  Widget build(BuildContext context) {
    final faces = widget.snapshot.faces;
    if (faces.length < 3) return const SizedBox.shrink();

    final c = context.colors;
    final front = _frontIndex;
    final frontFace = faces[front];

    final order = List<int>.generate(3, (i) => i)
      ..sort((a, b) {
        final da = math.cos(_angle - a * _step);
        final db = math.cos(_angle - b * _step);
        return da.compareTo(db);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'For you',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (widget.loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        // Listener for swipe (doesn't compete with InkWell taps on cards /
        // buttons). Front card opens the cover title's details.
        SizedBox(
          height: _cardH + 24,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) {
              _settle.stop();
              _settleAnim = null;
              _pointerStartX = e.position.dx;
              _lastPointerX = e.position.dx;
              _lastPointerAtMs =
                  DateTime.now().millisecondsSinceEpoch.toDouble();
              _dragStartAngle = _angle;
              _velocity = 0;
              _dragMoved = false;
            },
            onPointerMove: (e) {
              final now = DateTime.now().millisecondsSinceEpoch.toDouble();
              final dx = e.position.dx - _pointerStartX;
              final dt = (now - _lastPointerAtMs).clamp(1, 64);
              final dFinger = e.position.dx - _lastPointerX;
              // Finger → radians; smoothed velocity for fling snap.
              final instant = (dFinger / _radius) / dt;
              _velocity = _velocity * 0.65 + instant * 0.35;
              _lastPointerX = e.position.dx;
              _lastPointerAtMs = now;
              if (dx.abs() > 8) _dragMoved = true;
              if (!_dragMoved) return;
              // Positive dx (finger right) → rotate so left card comes forward.
              setState(() => _angle = _dragStartAngle + dx / _radius);
            },
            onPointerUp: (_) {
              if (_dragMoved) {
                _snapToNearest(velocityRadPerMs: _velocity);
                _suppressCardTap = true;
              }
              _dragMoved = false;
              _velocity = 0;
            },
            onPointerCancel: (_) {
              if (_dragMoved) {
                _snapToNearest(velocityRadPerMs: _velocity);
                _suppressCardTap = true;
              }
              _dragMoved = false;
              _velocity = 0;
            },
            child: ClipRect(
              child: Stack(
                key: _orbitStackKey,
                alignment: Alignment.center,
                children: [
                  if (!_orbitSuppressed)
                    for (final i in order)
                      _orbitFace(
                        face: faces[i],
                        localAngle: _angle - i * _step,
                        isFront: i == front,
                        cover: _coverImage(faces[i].coverEntry),
                        onTap: i == front
                            ? () {
                                if (_suppressCardTap) {
                                  _suppressCardTap = false;
                                  return;
                                }
                                _onOpenCover(frontFace);
                              }
                            : null,
                      ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.md,
            AppSpacing.xxl,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: _HubActionButton(
                  label: 'Read',
                  primary: true,
                  onTap: () => _onRead(frontFace),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HubActionButton(
                  label: 'View more',
                  primary: false,
                  onTap: () => _onViewMore(frontFace),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text(
            'Swipe to turn · ${frontFace.title}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: c.textTertiary,
                ),
          ),
        ),
      ],
    );
  }

  Widget _orbitFace({
    required LibraryHubFace face,
    required double localAngle,
    required bool isFront,
    required ImageProvider? cover,
    VoidCallback? onTap,
  }) {
    // Soft depth curve — ease toward front so side cards don't pop.
    final rawDepth = ((math.cos(localAngle) + 1) / 2).clamp(0.0, 1.0);
    final depth = Curves.easeOut.transform(rawDepth);
    final x = math.sin(localAngle) * _radius;
    final scale = 0.78 + 0.22 * depth;
    final opacity = 0.55 + 0.45 * depth;
    final y = (1 - depth) * 10;

    Widget card = _HubSectionCard(
      face: face,
      width: _cardW,
      height: _cardH,
      cover: cover,
    );
    if (onTap != null) {
      card = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.brLg,
          child: card,
        ),
      );
    } else {
      card = IgnorePointer(child: card);
    }

    return Transform.translate(
      offset: Offset(x, y),
      filterQuality: FilterQuality.low,
      child: Transform.scale(
        scale: scale,
        filterQuality: FilterQuality.low,
        child: Opacity(
          opacity: opacity.clamp(0.45, 1.0),
          child: card,
        ),
      ),
    );
  }
}

class _HubActionButton extends StatelessWidget {
  const _HubActionButton({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Same language as manga-detail status / chapter meta pills: theme
    // tint + stadium, not a flat Material fill that ignores pack muted tones.
    final bg = primary ? c.accentMuted : c.surfaceMuted;
    final fg = primary ? c.accent : c.textSecondary;
    return AnimatedPress(
      onTap: onTap,
      scaleDown: 0.97,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppSpacing.brPill,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _HubSectionCard extends StatelessWidget {
  const _HubSectionCard({
    required this.face,
    required this.width,
    required this.height,
    this.cover,
  });

  final LibraryHubFace face;
  final double width;
  final double height;
  final ImageProvider? cover;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: c.surface,
        elevation: 6,
        shadowColor: Colors.black54,
        borderRadius: AppSpacing.brLg,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cover != null)
              Image(
                image: cover!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: c.surface,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: c.textTertiary,
                  ),
                ),
              )
            else
              ColoredBox(
                color: c.surface,
                child: Icon(
                  Icons.menu_book_rounded,
                  color: c.textTertiary,
                  size: 40,
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.78),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 28, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        face.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.2,
                        ),
                      ),
                      if (face.subtitle.isNotEmpty)
                        Text(
                          face.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
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
    );
  }
}

/// Opens last-read chapter / reader for a hub entry.
Future<void> openLibraryHubRead(
  BuildContext context,
  WidgetRef ref,
  LibraryHubEntry entry,
) async {
  final book = entry.book;
  if (book != null) {
    openBookReader(
      context,
      bookId: book.id,
      fileExtension: book.fileExtension,
      initialPage: book.fileExtension.toLowerCase() == 'pdf'
          ? book.currentChapterIndex
          : null,
    );
    return;
  }

  final row = entry.inProgressManga;
  if (row != null) {
    await _openMangaContinue(context, ref, row.manga);
    return;
  }

  final manga = entry.manga;
  if (manga != null) {
    await _openMangaContinue(context, ref, manga);
    return;
  }

  final rec = entry.recommendation;
  if (rec != null) {
    if (rec.inLibrary) {
      final id = rec.id;
      if (id != null && id.startsWith('book:')) {
        final bookId = int.tryParse(id.substring(5));
        if (bookId != null) {
          final b = await ref.read(repositoriesProvider).books.getBook(bookId);
          if (b != null && context.mounted) {
            openBookReader(
              context,
              bookId: b.id,
              fileExtension: b.fileExtension,
              initialPage: b.fileExtension.toLowerCase() == 'pdf'
                  ? b.currentChapterIndex
                  : null,
            );
            return;
          }
        }
      }
      if (id != null && id.startsWith('manga:')) {
        final mangaId = int.tryParse(id.substring(6));
        if (mangaId != null) {
          final m =
              await ref.read(repositoriesProvider).manga.getMangaById(mangaId);
          if (m != null && context.mounted) {
            await _openMangaContinue(context, ref, m);
            return;
          }
        }
      }
    }
    if (context.mounted) await openRecommendationItem(context, ref, rec);
  }
}

Future<void> openLibraryHubEntry(
  BuildContext context,
  WidgetRef ref,
  LibraryHubEntry entry,
) async {
  if (entry.book != null) {
    openBookFromCollection(context, entry.book!.id);
    return;
  }
  if (entry.manga != null) {
    final m = entry.manga!;
    context.pushNamed(
      Routes.mangaDetail,
      extra: (
        sourceId: m.sourceId,
        url: m.url,
        title: m.name,
        manga: m,
        memo: m.memo,
      ) as MangaDetailArgs,
    );
    return;
  }
  if (entry.recommendation != null) {
    await openRecommendationItem(context, ref, entry.recommendation!);
  }
}

/// Resume the furthest chapter in the user's real reading run.
///
/// Progress is clustered by chapter number so a stray open of the latest
/// release (ch 243) cannot override having read through ch 1–17.
MangaChapter _hubReadTargetChapter(List<MangaChapter> chapters, {String? mangaTitle}) {
  assert(chapters.isNotEmpty);
  final title = mangaTitle ?? '';

  double numberOf(MangaChapter ch) {
    if (ch.isRecognizedNumber && ch.chapterNumber >= 0) {
      return ch.chapterNumber;
    }
    return ChapterRecognition.parseFromName(title, ch.name);
  }

  final progressed = <MangaChapter>[
    for (final ch in chapters)
      if (ch.isRead ||
          ch.lastPageRead > 0 ||
          ch.scrollPosition > 0 ||
          ch.readAt != null)
        ch,
  ];

  if (progressed.isEmpty) {
    return _hubChapterOne(chapters, title);
  }

  // Sort by resolved chapter number; fall back to index for unknowns.
  final ranked = [...progressed]..sort((a, b) {
      final na = numberOf(a);
      final nb = numberOf(b);
      final aOk = ChapterRecognition.isRecognized(na);
      final bOk = ChapterRecognition.isRecognized(nb);
      if (aOk && bOk && na != nb) return na.compareTo(nb);
      if (aOk && !bOk) return -1;
      if (!aOk && bOk) return 1;
      return a.index.compareTo(b.index);
    });

  // Longest contiguous run by chapter number — the actual reading streak.
  // A single peeked latest chapter is a run of length 1 and loses to 1–17.
  var bestStart = 0;
  var bestLen = 1;
  var runStart = 0;
  for (var i = 1; i < ranked.length; i++) {
    final prev = numberOf(ranked[i - 1]);
    final cur = numberOf(ranked[i]);
    final contiguous = ChapterRecognition.isRecognized(prev) &&
        ChapterRecognition.isRecognized(cur) &&
        (cur - prev) <= 1.5 &&
        (cur - prev) >= -0.01;
    // Also treat same-index neighbors without numbers as contiguous.
    final indexContiguous = !ChapterRecognition.isRecognized(prev) &&
        !ChapterRecognition.isRecognized(cur) &&
        (ranked[i].index - ranked[i - 1].index).abs() <= 1;
    if (contiguous || indexContiguous) {
      final len = i - runStart + 1;
      if (len > bestLen) {
        bestLen = len;
        bestStart = runStart;
      }
    } else {
      runStart = i;
      if (1 > bestLen) {
        bestLen = 1;
        bestStart = i;
      }
    }
  }
  final runEnd = bestStart + bestLen - 1;
  final run = ranked.sublist(bestStart, runEnd + 1);

  // Furthest chapter in the winning run (highest resolved number).
  MangaChapter frontier = run.first;
  var frontierNum = numberOf(frontier);
  var anyNumbered = ChapterRecognition.isRecognized(frontierNum);
  for (final ch in run.skip(1)) {
    final n = numberOf(ch);
    if (ChapterRecognition.isRecognized(n)) {
      if (!anyNumbered || n >= frontierNum) {
        frontier = ch;
        frontierNum = n;
        anyNumbered = true;
      }
    }
  }
  if (!anyNumbered) {
    // Newest-first lists: lower index = later chapter.
    final sample = [
      for (final ch in chapters)
        if (ChapterRecognition.isRecognized(numberOf(ch))) ch,
    ]..sort((a, b) => a.index.compareTo(b.index));
    final newestFirst = sample.length >= 2 &&
        numberOf(sample.first) > numberOf(sample.last);
    frontier = newestFirst
        ? run.reduce((a, b) => a.index <= b.index ? a : b)
        : run.reduce((a, b) => a.index >= b.index ? a : b);
  }

  // If the frontier chapter is fully read, prefer an in-progress chapter
  // immediately after it when present.
  if (frontier.isRead) {
    final frontierNum = numberOf(frontier);
    MangaChapter? next;
    for (final ch in chapters) {
      if (ch.isRead) continue;
      if (ch.lastPageRead <= 0 && ch.scrollPosition <= 0) continue;
      final n = numberOf(ch);
      if (!ChapterRecognition.isRecognized(frontierNum) ||
          !ChapterRecognition.isRecognized(n)) {
        continue;
      }
      final gap = n - frontierNum;
      if (gap >= -0.01 && gap <= 1.01) {
        if (next == null || n >= numberOf(next)) next = ch;
      }
    }
    if (next != null) return next;
  }
  return frontier;
}

MangaChapter _hubChapterOne(List<MangaChapter> chapters, String mangaTitle) {
  MangaChapter? best;
  var bestNum = double.infinity;
  for (final ch in chapters) {
    var n = ch.isRecognizedNumber && ch.chapterNumber >= 0
        ? ch.chapterNumber
        : ChapterRecognition.parseFromName(mangaTitle, ch.name);
    if (!ChapterRecognition.isRecognized(n) || n <= 0) continue;
    if (n < bestNum) {
      bestNum = n;
      best = ch;
    }
  }
  if (best != null) return best;

  // Detect newest-first vs oldest-first via recognized numbers when possible.
  final numbered = [
    for (final ch in chapters)
      if (ch.isRecognizedNumber && ch.chapterNumber >= 0) ch,
  ]..sort((a, b) => a.index.compareTo(b.index));
  final indexFollowsNumber = numbered.length < 2 ||
      numbered.first.chapterNumber <= numbered.last.chapterNumber;
  if (indexFollowsNumber) {
    return chapters.reduce((a, b) => a.index <= b.index ? a : b);
  }
  return chapters.reduce((a, b) => a.index >= b.index ? a : b);
}

Future<void> _openMangaContinue(
  BuildContext context,
  WidgetRef ref,
  Manga manga,
) async {
  final repos = ref.read(repositoriesProvider);
  final chapters = await repos.manga.getMangaChapters(manga.id);
  if (!context.mounted) return;
  if (chapters.isEmpty) {
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
    return;
  }

  final target = _hubReadTargetChapter(chapters, mangaTitle: manga.name);

  if (ref.read(libraryProvider).isNovelSource(manga.sourceId)) {
    context.pushNamed(
      Routes.novelReader,
      extra: (
        mangaId: manga.id,
        sourceId: manga.sourceId,
        mangaUrl: manga.url,
        mangaName: manga.name,
        chapterUrl: target.url,
        chapterName: target.name,
        seekStartOffset: null,
        seekEndOffset: null,
      ) as NovelReaderArgs,
    );
    return;
  }

  context.pushNamed(
    Routes.mangaReader,
    extra: (
      mangaId: manga.id,
      sourceId: manga.sourceId,
      mangaUrl: manga.url,
      chapterUrl: target.url,
      chapterName: target.name,
      pageNumber: target.lastPageRead > 0 ? target.lastPageRead : null,
    ) as MangaReaderArgs,
  );
}

Future<void> showLibraryHubExpand(
  BuildContext context, {
  required LibraryHubFace face,
  required LibraryHubFace leftFace,
  required ImageProvider? leftCover,
  Rect? leftRect,
  required LibraryHubFace rightFace,
  required ImageProvider? rightCover,
  Rect? rightRect,
  Map<int, String?> mangaThumbnails = const {},
  required Future<void> Function(LibraryHubEntry) onOpenEntry,
  required Future<void> Function() onRead,
  VoidCallback? onDismissStart,
}) {
  const expandDuration = Duration(milliseconds: 780);
  const dismissDuration = Duration(milliseconds: 220);
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: expandDuration,
      reverseTransitionDuration: dismissDuration,
      pageBuilder: (ctx, anim, secondary) {
        return _HubExpandPage(
          face: face,
          leftFace: leftFace,
          leftCover: leftCover,
          leftRect: leftRect,
          rightFace: rightFace,
          rightCover: rightCover,
          rightRect: rightRect,
          mangaThumbnails: mangaThumbnails,
          animation: anim,
          onOpenEntry: onOpenEntry,
          onRead: onRead,
          onDismissStart: onDismissStart,
        );
      },
      transitionsBuilder: (ctx, anim, secondary, child) => child,
    ),
  );
}

class _HubExpandPage extends ConsumerStatefulWidget {
  const _HubExpandPage({
    required this.face,
    required this.leftFace,
    required this.leftCover,
    this.leftRect,
    required this.rightFace,
    required this.rightCover,
    this.rightRect,
    required this.mangaThumbnails,
    required this.animation,
    required this.onOpenEntry,
    required this.onRead,
    this.onDismissStart,
  });

  final LibraryHubFace face;
  final LibraryHubFace leftFace;
  final ImageProvider? leftCover;
  final Rect? leftRect;
  final LibraryHubFace rightFace;
  final ImageProvider? rightCover;
  final Rect? rightRect;
  final Map<int, String?> mangaThumbnails;
  final Animation<double> animation;
  final Future<void> Function(LibraryHubEntry) onOpenEntry;
  final Future<void> Function() onRead;
  final VoidCallback? onDismissStart;

  @override
  ConsumerState<_HubExpandPage> createState() => _HubExpandPageState();
}

class _HubExpandPageState extends ConsumerState<_HubExpandPage> {
  static const _fg = Colors.white;
  static const _fgMuted = Color(0xB3FFFFFF);
  static const _fallbackCardW = 168.0;
  static const _fallbackCardH = 260.0;

  bool _dismissNotified = false;

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_onAnimStatus);
  }

  @override
  void didUpdateWidget(covariant _HubExpandPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeStatusListener(_onAnimStatus);
      widget.animation.addStatusListener(_onAnimStatus);
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onAnimStatus);
    super.dispose();
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse) {
      _notifyDismissStart();
    }
  }

  void _notifyDismissStart() {
    if (_dismissNotified) return;
    _dismissNotified = true;
    widget.onDismissStart?.call();
  }

  ImageProvider? _entryCover(LibraryHubEntry entry) {
    final manga = entry.mangaRef;
    if (manga != null) {
      final headers =
          ref.watch(sourceImageHeadersProvider(manga.sourceId)).value;
      return mangaCoverProvider(
        manga,
        localThumbPath: widget.mangaThumbnails[manga.id],
        headers: headers,
      );
    }
    final bookPath = entry.book?.coverPath?.trim();
    if (bookPath != null && bookPath.isNotEmpty) {
      if (hubCoverIsLocalFile(bookPath)) {
        if (hubLocalCoverExists(bookPath)) {
          return FileImage(File(hubLocalCoverPath(bookPath)));
        }
      } else {
        return coverProvider(bookPath);
      }
    }
    final url = hubCoverUrl(entry);
    if (url == null || url.isEmpty) return null;
    if (hubCoverIsLocalFile(url)) {
      if (!hubLocalCoverExists(url)) return null;
      return FileImage(File(hubLocalCoverPath(url)));
    }
    return coverProvider(url);
  }

  Rect _fallbackSideRect(BuildContext context, {required bool left}) {
    final size = MediaQuery.sizeOf(context);
    final w = _fallbackCardW * 0.835;
    final h = _fallbackCardH * 0.835;
    final cy = size.height * 0.28;
    final cx = left ? size.width * 0.22 : size.width * 0.78;
    return Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
  }

  Widget _peelCard({
    required BuildContext context,
    required LibraryHubFace sideFace,
    required ImageProvider? cover,
    required Rect? origin,
    required bool left,
    required double side,
  }) {
    final start = origin ?? _fallbackSideRect(context, left: left);
    final dx = left ? -220.0 * side : 220.0 * side;
    final dy = -36.0 * side;
    return Positioned(
      left: start.left + dx,
      top: start.top + dy,
      width: start.width,
      height: start.height,
      child: Opacity(
        opacity: (1.0 - side * 0.85).clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: (left ? -0.55 : 0.55) * side,
          child: Transform.scale(
            scale: 1.0 - 0.08 * side,
            child: _HubSectionCard(
              face: sideFace,
              width: start.width,
              height: start.height,
              cover: cover,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final animation = widget.animation;
    final breakAway = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.45, curve: AppMotion.accelerate),
    );
    // Close: quick fade only — no peel reverse curve.
    final fadeIn = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.48, 1.0, curve: AppMotion.decelerate),
      reverseCurve: Curves.easeOut,
    );
    final barrier = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      reverseCurve: Curves.easeOut,
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final closing = animation.status == AnimationStatus.reverse ||
            _dismissNotified;
        final side = breakAway.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: Color.lerp(
                Colors.transparent,
                const Color(0xF2000000),
                barrier.value,
              )!,
            ),
            // Peel only on open. On close the real orbit is already restored.
            if (!closing) ...[
              _peelCard(
                context: context,
                sideFace: widget.leftFace,
                cover: widget.leftCover,
                origin: widget.leftRect,
                left: true,
                side: side,
              ),
              _peelCard(
                context: context,
                sideFace: widget.rightFace,
                cover: widget.rightCover,
                origin: widget.rightRect,
                left: false,
                side: side,
              ),
            ],
            Opacity(
              opacity: fadeIn.value,
              child: SafeArea(
                child: Material(
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                _notifyDismissStart();
                                Navigator.of(context).maybePop();
                              },
                              icon: const Icon(Icons.close, color: _fg),
                            ),
                            Expanded(
                              child: Text(
                                widget.face.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: _fg,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                if (widget.face.isEmpty) {
                                  StashToast.show(
                                    context,
                                    message: 'Nothing to read yet',
                                    icon: Icons.info_outline,
                                  );
                                  return;
                                }
                                _notifyDismissStart();
                                widget.onRead();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: _fg,
                                backgroundColor: Colors.white24,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text('Read'),
                            ),
                          ],
                        ),
                        if (widget.face.subtitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 12,
                              bottom: AppSpacing.sm,
                            ),
                            child: Text(
                              widget.face.subtitle,
                              style: const TextStyle(
                                color: _fgMuted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final library = ref.watch(libraryProvider);
                              final variant = CatalogCardLayout.gridVariant(
                                library.cardVariant,
                              );
                              return GridView.builder(
                                padding: const EdgeInsets.only(bottom: 24),
                                gridDelegate:
                                    CatalogCardLayout.gridDelegate(
                                  columns: library.gridColumns,
                                  variant: variant,
                                ),
                                itemCount: widget.face.entries.length,
                                itemBuilder: (context, i) {
                                  final e = widget.face.entries[i];
                                  final image = _entryCover(e);
                                  final url = hubCoverUrl(e);
                                  return StaggeredFadeScale(
                                    index: i,
                                    duration: const Duration(milliseconds: 520),
                                    delayStepMs: 70,
                                    child: CatalogCoverCard(
                                      minimalChrome: false,
                                      title: e.title,
                                      subtitle: e.subtitle,
                                      imageProvider: image,
                                      imageUrl: (url != null &&
                                              (url.startsWith('http://') ||
                                                  url.startsWith('https://')))
                                          ? url
                                          : null,
                                      variant: variant,
                                      onTap: () {
                                        _notifyDismissStart();
                                        widget.onOpenEntry(e);
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/isar/collections/track.dart';
import '../../core/providers.dart';
import '../../core/repositories/track_repository.dart';
import '../../core/services/trackers/base_tracker.dart';
import '../../core/services/trackers/track_enrichment.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/toast.dart';
import '../../widgets/tracker_brand_icon.dart';

class TrackMangaScreen extends ConsumerStatefulWidget {
  final int mangaId;

  const TrackMangaScreen({super.key, required this.mangaId});

  @override
  ConsumerState<TrackMangaScreen> createState() => _TrackMangaScreenState();
}

class _TrackMangaScreenState extends ConsumerState<TrackMangaScreen> {
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final _queryCtrl = TextEditingController();

  List<Track> _tracks = const [];
  bool _loadingTracks = true;
  BaseTracker? _selected;
  List<TrackSearchResult> _results = const [];
  bool _searching = false;
  String? _error;
  bool _binding = false;

  static const _services = [
    (TrackIds.mal, 'MyAnimeList'),
    (TrackIds.anilist, 'AniList'),
  ];

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTracks() async {
    final tracks = await ref
        .read(repositoriesProvider)
        .tracks
        .getTracksForManga(widget.mangaId);
    if (!mounted) return;
    setState(() {
      _tracks = tracks;
      _loadingTracks = false;
    });
  }

  BaseTracker _tracker(int syncId) {
    final repos = ref.read(repositoriesProvider);
    return TrackEnrichment.trackerFor(repos, syncId);
  }

  String _serviceName(int? syncId) {
    return switch (syncId) {
      TrackIds.mal => 'MyAnimeList',
      TrackIds.anilist => 'AniList',
      TrackIds.mangaUpdates => 'MangaUpdates',
      _ => 'Tracker',
    };
  }

  Track? _trackFor(int syncId) {
    for (final t in _tracks) {
      if (t.syncId == syncId) return t;
    }
    return null;
  }

  void _showLocalSnack(String message) {
    if (!mounted) return;
    StashToast.show(context, message: message, icon: Icons.check);
  }

  void _showError(String message) {
    if (!mounted) return;
    StashToast.show(
      context,
      message: message,
      icon: Icons.error_outline,
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> _pickService(int syncId) async {
    final linked = _trackFor(syncId);
    if (linked != null) {
      await _openManage(linked);
      return;
    }
    await _openSearch(syncId);
  }

  Future<void> _openSearch(int syncId) async {
    final t = _tracker(syncId);
    if (!await t.isLoggedIn()) {
      if (!mounted) return;
      _showLocalSnack('Log in to ${t.name} in Settings → Tracking');
      return;
    }
    setState(() {
      _selected = t;
      _results = const [];
      _error = null;
    });
    final manga = await ref.read(repositoriesProvider).manga.getMangaById(
          widget.mangaId,
        );
    if (manga != null && manga.name.isNotEmpty) {
      _queryCtrl.text = manga.name;
      await _search();
    }
  }

  Future<void> _search() async {
    final t = _selected;
    if (t == null) return;
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await t.search(q);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = '$e';
      });
      _showError('Search failed: $e');
    }
  }

  Future<void> _bind(TrackSearchResult hit) async {
    final t = _selected;
    if (t == null || _binding) return;
    setState(() => _binding = true);
    try {
      final repos = ref.read(repositoriesProvider);
      final chapters = await repos.manga.getMangaChapters(widget.mangaId);
      var last = 0;
      for (final c in chapters) {
        if (!c.isRead || !c.isRecognizedNumber) continue;
        final n = c.chapterNumber.floor();
        if (n > last) last = n;
      }
      final track = await t.bind(
        mangaId: widget.mangaId,
        hit: hit,
        lastChapterRead: last,
      );
      await TrackEnrichment.refreshTrackMedia(repos, track);
      if (!mounted) return;
      _showLocalSnack('Tracked on ${t.name}');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _showError('Bind failed: $e');
    } finally {
      if (mounted) setState(() => _binding = false);
    }
  }

  Future<void> _unlink(Track track) async {
    final id = track.id;
    if (id == null) return;
    final name = _serviceName(track.syncId);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        return AlertDialog(
          backgroundColor: c.surface,
          title: const Text('Unlink tracker?'),
          content: Text('Remove the $name link for this title?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Unlink', style: TextStyle(color: c.accent)),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(repositoriesProvider).tracks.deleteTrack(id);
      await _loadTracks();
      if (!mounted) return;
      _showLocalSnack('Unlinked from $name');
    } catch (e) {
      if (!mounted) return;
      _showError('Unlink failed: $e');
    }
  }

  Future<void> _openManage(Track track) async {
    final syncId = track.syncId;
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _TrackManageSheet(
          track: track,
          tracker: _tracker(syncId ?? 0),
          serviceName: _serviceName(syncId),
          onUnlink: () => Navigator.pop(ctx, 'unlink'),
          onChangeTitle: () => Navigator.pop(ctx, 'change'),
          onChanged: () async {
            await _loadTracks();
          },
          onError: _showError,
          onSnack: _showLocalSnack,
        );
      },
    );
    if (!mounted) return;
    if (action == 'unlink') {
      await _unlink(track);
    } else if (action == 'change' && syncId != null) {
      await _openSearch(syncId);
    } else {
      await _loadTracks();
    }
  }

  void _exitSearch() {
    setState(() {
      _selected = null;
      _results = const [];
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          title: Text(
            _selected == null ? 'Track' : 'Search ${_selected!.name}',
          ),
          backgroundColor: c.bg,
          leading: _selected != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _exitSearch,
                )
              : null,
        ),
        body: _selected == null ? _buildPicker(c) : _buildSearch(c),
      ),
    );
  }

  Widget _buildPicker(KomaColors c) {
    if (_loadingTracks) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        if (_tracks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              'Linked',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          for (final track in _tracks)
            ListTile(
              leading: TrackerBrandIcon(
                syncId: track.syncId ?? 0,
                size: 40,
              ),
              title: Text(_serviceName(track.syncId)),
              subtitle: Text(
                [
                  if ((track.title ?? '').trim().isNotEmpty) track.title!.trim(),
                  'Ch. ${track.lastChapterRead ?? 0}'
                      '${(track.totalChapter ?? 0) > 0 ? '/${track.totalChapter}' : ''}',
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: 'Unlink',
                icon: Icon(Icons.link_off, color: c.textSecondary),
                onPressed: () => _unlink(track),
              ),
              onTap: () => _openManage(track),
            ),
          const Divider(height: AppSpacing.xxl),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Text(
            'Services',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        for (final entry in _services)
          Builder(
            builder: (_) {
              final syncId = entry.$1;
              final name = entry.$2;
              final linked = _trackFor(syncId);
              return ListTile(
                leading: TrackerBrandIcon(syncId: syncId, size: 40),
                title: Text(name),
                subtitle: linked != null ? const Text('Linked') : null,
                trailing: linked != null
                    ? Icon(Icons.check_circle, color: c.accent, size: 22)
                    : Icon(Icons.chevron_right, color: c.textSecondary),
                onTap: () => _pickService(syncId),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSearch(KomaColors c) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Search title…',
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: _searching || _binding ? null : _search,
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(_error!, style: TextStyle(color: c.accent)),
          ),
        if (_searching || _binding)
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final hit = _results[i];
                return ListTile(
                  title: Text(hit.title),
                  subtitle: hit.summary == null
                      ? null
                      : Text(
                          hit.summary!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  onTap: () => _bind(hit),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _TrackManageSheet extends StatefulWidget {
  const _TrackManageSheet({
    required this.track,
    required this.tracker,
    required this.serviceName,
    required this.onUnlink,
    required this.onChangeTitle,
    required this.onChanged,
    required this.onError,
    required this.onSnack,
  });

  final Track track;
  final BaseTracker tracker;
  final String serviceName;
  final VoidCallback onUnlink;
  final VoidCallback onChangeTitle;
  final Future<void> Function() onChanged;
  final void Function(String message) onError;
  final void Function(String message) onSnack;

  @override
  State<_TrackManageSheet> createState() => _TrackManageSheetState();
}

class _TrackManageSheetState extends State<_TrackManageSheet> {
  late double _score;
  bool _savingScore = false;
  bool _savingReview = false;
  bool _postingComment = false;
  int? _myReviewId;
  List<TrackerComment> _comments = const [];
  bool _loadingComments = false;

  final _reviewTitleCtrl = TextEditingController();
  final _reviewBodyCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  bool get _isAnilist => widget.track.syncId == TrackIds.anilist;
  bool get _isMal => widget.track.syncId == TrackIds.mal;

  double get _scoreMax => _isAnilist ? 100 : 10;
  int get _scoreDivisions => _isAnilist ? 100 : 10;

  @override
  void initState() {
    super.initState();
    final raw = (widget.track.score ?? 0).toDouble();
    if (_isAnilist) {
      _score = raw.clamp(0, 100);
    } else {
      // MAL 0–10; AniList-stored 0–100 values should not appear here.
      _score = raw > 10 ? (raw / 10).clamp(0, 10) : raw.clamp(0, 10);
    }
    if (_isAnilist) {
      _loadMyReview();
    }
  }

  @override
  void dispose() {
    _reviewTitleCtrl.dispose();
    _reviewBodyCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMyReview() async {
    final mediaId = widget.track.mediaId;
    if (mediaId == null) return;
    try {
      final reviews = await widget.tracker.listReviews(mediaId);
      final mine = reviews.cast<TrackerReview?>().firstWhere(
            (r) => r?.isMine == true,
            orElse: () => null,
          );
      if (!mounted) return;
      if (mine != null) {
        setState(() {
          _myReviewId = mine.id;
          _reviewTitleCtrl.text = mine.title ?? '';
          _reviewBodyCtrl.text = mine.body;
        });
        await _loadComments(mine.id);
      }
    } catch (_) {}
  }

  Future<void> _loadComments(int reviewId) async {
    setState(() => _loadingComments = true);
    try {
      final comments = await widget.tracker.listComments(reviewId);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loadingComments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingComments = false);
    }
  }

  Future<void> _saveScore() async {
    if (_savingScore) return;
    setState(() => _savingScore = true);
    try {
      await widget.tracker.updateScore(widget.track, _score.round());
      await widget.onChanged();
      if (!mounted) return;
      widget.onSnack('Score updated');
    } catch (e) {
      widget.onError('Score update failed: $e');
    } finally {
      if (mounted) setState(() => _savingScore = false);
    }
  }

  Future<void> _saveReview() async {
    final mediaId = widget.track.mediaId;
    if (mediaId == null || _savingReview) return;
    final body = _reviewBodyCtrl.text.trim();
    if (body.isEmpty) {
      widget.onError('Review body is required');
      return;
    }
    setState(() => _savingReview = true);
    try {
      final saved = await widget.tracker.upsertReview(
        mediaId: mediaId,
        body: body,
        title: _reviewTitleCtrl.text.trim().isEmpty
            ? null
            : _reviewTitleCtrl.text.trim(),
        score: _score.round(),
        existingReviewId: _myReviewId,
      );
      if (!mounted) return;
      if (saved != null) {
        setState(() => _myReviewId = saved.id);
        await _loadComments(saved.id);
      }
      await widget.onChanged();
      widget.onSnack('Review saved');
    } catch (e) {
      widget.onError('Review failed: $e');
    } finally {
      if (mounted) setState(() => _savingReview = false);
    }
  }

  Future<void> _postComment() async {
    final reviewId = _myReviewId;
    final body = _commentCtrl.text.trim();
    if (reviewId == null || body.isEmpty || _postingComment) return;
    setState(() => _postingComment = true);
    try {
      await widget.tracker.postComment(reviewId: reviewId, body: body);
      _commentCtrl.clear();
      await _loadComments(reviewId);
      if (!mounted) return;
      widget.onSnack('Comment posted');
    } catch (e) {
      widget.onError('Comment failed: $e');
    } finally {
      if (mounted) setState(() => _postingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Material(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: AppSpacing.sheetLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: c.textSecondary.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    TrackerBrandIcon(
                      syncId: widget.track.syncId ?? 0,
                      size: 36,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.serviceName,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          if ((widget.track.title ?? '').isNotEmpty)
                            Text(
                              widget.track.title!,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Progress  Ch. ${widget.track.lastChapterRead ?? 0}'
                  '${(widget.track.totalChapter ?? 0) > 0 ? ' / ${widget.track.totalChapter}' : ''}',
                  style: TextStyle(color: c.textSecondary, fontSize: 13),
                ),
                if (_isMal || _isAnilist) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Score',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _score,
                          min: 0,
                          max: _scoreMax,
                          divisions: _scoreDivisions,
                          label: _score.round().toString(),
                          onChanged: _savingScore
                              ? null
                              : (v) => setState(() => _score = v),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${_score.round()}',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _savingScore ? null : _saveScore,
                      child: _savingScore
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save score'),
                    ),
                  ),
                ],
                if (_isAnilist) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Write review',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _reviewTitleCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Summary (optional)',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _reviewBodyCtrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'Review body',
                      isDense: true,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _savingReview ? null : _saveReview,
                      child: _savingReview
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_myReviewId == null ? 'Post review' : 'Update review'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Comments',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_myReviewId == null)
                    Text(
                      'Save a review first to comment on it.',
                      style: TextStyle(color: c.textSecondary, fontSize: 13),
                    )
                  else ...[
                    if (_loadingComments)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (_comments.isEmpty)
                      Text(
                        'No comments yet.',
                        style: TextStyle(color: c.textSecondary, fontSize: 13),
                      )
                    else
                      ..._comments.map(
                        (cm) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cm.userName ?? 'User',
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                cm.body,
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Add a comment…',
                              isDense: true,
                            ),
                            onSubmitted: (_) => _postComment(),
                          ),
                        ),
                        IconButton(
                          icon: _postingComment
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send),
                          onPressed: _postingComment ? null : _postComment,
                        ),
                      ],
                    ),
                  ],
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    TextButton(
                      onPressed: widget.onChangeTitle,
                      child: const Text('Change title'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: widget.onUnlink,
                      child: Text(
                        'Unlink',
                        style: TextStyle(color: c.accent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

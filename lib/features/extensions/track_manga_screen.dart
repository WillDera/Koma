import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/repositories/track_repository.dart';
import '../../core/services/trackers/anilist.dart';
import '../../core/services/trackers/base_tracker.dart';
import '../../core/services/trackers/manga_updates.dart';
import '../../core/services/trackers/myanimelist.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tracker_brand_icon.dart';

class TrackMangaScreen extends ConsumerStatefulWidget {
  final int mangaId;

  const TrackMangaScreen({super.key, required this.mangaId});

  @override
  ConsumerState<TrackMangaScreen> createState() => _TrackMangaScreenState();
}

class _TrackMangaScreenState extends ConsumerState<TrackMangaScreen> {
  BaseTracker? _selected;
  final _queryCtrl = TextEditingController();
  List<TrackSearchResult> _results = const [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  BaseTracker _tracker(int syncId) {
    final repos = ref.read(repositoriesProvider);
    return switch (syncId) {
      TrackIds.mal => MyAnimeListTracker(repos),
      TrackIds.anilist => AnilistTracker(repos),
      _ => MangaUpdatesTracker(repos),
    };
  }

  Future<void> _pickService(int syncId) async {
    final t = _tracker(syncId);
    if (!await t.isLoggedIn()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Log in to ${t.name} in Settings → Tracking')),
      );
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
    }
  }

  Future<void> _bind(TrackSearchResult hit) async {
    final t = _selected;
    if (t == null) return;
    try {
      final chapters = await ref
          .read(repositoriesProvider)
          .manga
          .getMangaChapters(widget.mangaId);
      var last = 0;
      for (final c in chapters) {
        if (!c.isRead || !c.isRecognizedNumber) continue;
        final n = c.chapterNumber.floor();
        if (n > last) last = n;
      }
      await t.bind(
        mangaId: widget.mangaId,
        hit: hit,
        lastChapterRead: last,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tracked on ${t.name}')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bind failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(_selected == null ? 'Track' : 'Search ${_selected!.name}'),
        backgroundColor: c.bg,
      ),
      body: _selected == null
          ? ListView(
              children: [
                ListTile(
                  leading: const TrackerBrandIcon(syncId: TrackIds.mal, size: 40),
                  title: const Text('MyAnimeList'),
                  onTap: () => _pickService(TrackIds.mal),
                ),
                ListTile(
                  leading:
                      const TrackerBrandIcon(syncId: TrackIds.anilist, size: 40),
                  title: const Text('AniList'),
                  onTap: () => _pickService(TrackIds.anilist),
                ),
                ListTile(
                  leading: const TrackerBrandIcon(
                    syncId: TrackIds.mangaUpdates,
                    size: 40,
                  ),
                  title: const Text('MangaUpdates'),
                  onTap: () => _pickService(TrackIds.mangaUpdates),
                ),
              ],
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
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
                        onPressed: _searching ? null : _search,
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(_error!, style: TextStyle(color: c.accent)),
                  ),
                if (_searching)
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
            ),
    );
  }
}

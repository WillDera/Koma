import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/download/chapter_download.dart';
import '../../theme/app_theme.dart';
import '../../widgets/library_header.dart';
import '../../widgets/one_hand_spacer.dart';
import '../../widgets/screen_chrome.dart';

/// Mihon-style download queue: pause / resume, clear, cancel per item, retry.
class DownloadQueueScreen extends ConsumerWidget {
  const DownloadQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final snap = ref.watch(downloadManagerProvider);
    final mgr = ref.read(downloadManagerProvider.notifier);
    final queue = snap.queue;
    final running = snap.isRunning;
    final paused = snap.isPaused;

    // Group by manga title for readability (Mihon groups by manga).
    final groups = <String, List<ChapterDownload>>{};
    for (final d in queue) {
      final key = '${d.sourceId}|${d.mangaUrl}';
      groups.putIfAbsent(key, () => []).add(d);
    }

    // Match Settings → Data title chrome: SafeArea + OneHandSpacer +
    // LibraryHeader with sub-screen padding (not flush under the status bar).
    return Material(
      type: MaterialType.transparency,
      child: ScreenBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const OneHandSpacer(),
              LibraryHeader(
                title: queue.isEmpty
                    ? 'Download queue'
                    : 'Download queue (${queue.length})',
                showBackButton: true,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              ),
              if (queue.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      if (paused || !running)
                        FilledButton.tonalIcon(
                          onPressed: () => mgr.startDownloads(),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Resume'),
                        )
                      else
                        FilledButton.tonalIcon(
                          onPressed: () => mgr.pauseDownloads(),
                          icon: const Icon(Icons.pause),
                          label: const Text('Pause'),
                        ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => mgr.clearQueue(),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: queue.isEmpty
                    ? Center(
                        child: Text(
                          'No chapters queued',
                          style: TextStyle(
                            color: c.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final entries = groups.entries.toList();
                          final group = entries[index];
                          final items = group.value;
                          final title = items.first.mangaTitle;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                child: Text(
                                  title.isEmpty ? 'Unknown title' : title,
                                  style: TextStyle(
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              ...items.map((d) => _DownloadTile(download: d)),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadTile extends ConsumerWidget {
  const _DownloadTile({required this.download});

  final ChapterDownload download;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final mgr = ref.read(downloadManagerProvider.notifier);
    final status = download.status;
    final progress = download.pagesTotal > 0
        ? '${download.pagesDone}/${download.pagesTotal}'
        : null;

    String subtitle;
    switch (status) {
      case DownloadState.queue:
        subtitle = 'Queued';
      case DownloadState.downloading:
        subtitle = progress != null ? 'Downloading $progress' : 'Downloading…';
      case DownloadState.error:
        subtitle = 'Error — tap retry';
      case DownloadState.downloaded:
        subtitle = 'Done';
      case DownloadState.notDownloaded:
        subtitle = '';
    }

    return ListTile(
      title: Text(
        download.chapterName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: c.textPrimary, fontSize: 14),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: TextStyle(color: c.textSecondary, fontSize: 12),
          ),
          if (status == DownloadState.downloading && download.pagesTotal > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(
                value: download.progressFraction,
                minHeight: 3,
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == DownloadState.error)
            IconButton(
              tooltip: 'Retry',
              icon: const Icon(Icons.refresh),
              onPressed: () {
                download.status = DownloadState.queue;
                mgr.startDownloads();
              },
            ),
          if (status == DownloadState.queue ||
              status == DownloadState.downloading)
            IconButton(
              tooltip: 'Download now',
              icon: const Icon(Icons.vertical_align_top),
              onPressed: () => mgr.startDownloadNow(download.chapterKey),
            ),
          IconButton(
            tooltip: 'Cancel',
            icon: const Icon(Icons.close),
            onPressed: () => mgr.cancelQueuedDownloads([download]),
          ),
        ],
      ),
    );
  }
}

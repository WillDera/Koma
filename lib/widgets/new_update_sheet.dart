import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/providers.dart';
import '../core/services/app_update/app_release.dart';
import '../core/services/app_update/app_update_manager.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_spacing.dart';

/// Mihon [NewUpdateScreen] parity: changelog + Download → Install flow.
///
/// Download progress lives in [AppUpdateManager] so closing this sheet does
/// not cancel the transfer — the system notification shows progress instead.
class NewUpdateSheet extends ConsumerStatefulWidget {
  const NewUpdateSheet({super.key, required this.release});

  final AppRelease release;

  static Future<void> show(BuildContext context, AppRelease release) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => NewUpdateSheet(release: release),
    );
  }

  @override
  ConsumerState<NewUpdateSheet> createState() => _NewUpdateSheetState();
}

class _NewUpdateSheetState extends ConsumerState<NewUpdateSheet> {
  @override
  void initState() {
    super.initState();
    ref.read(appUpdateProvider.notifier).offerUpdate(widget.release);
  }

  Future<void> _onAccept() async {
    final notifier = ref.read(appUpdateProvider.notifier);
    final stage = ref.read(appUpdateProvider).stage;
    switch (stage) {
      case AppUpdateStage.available:
      case AppUpdateStage.failed:
        await notifier.startDownload();
      case AppUpdateStage.downloaded:
        await _install();
      case AppUpdateStage.downloading:
      case AppUpdateStage.idle:
        break;
    }
  }

  Future<void> _install() async {
    try {
      await ref.read(appUpdateProvider.notifier).install();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open installer: $e')),
      );
    }
  }

  Future<void> _openReleasePage() async {
    final uri = Uri.tryParse(widget.release.releaseLink);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _acceptLabel(AppUpdateStage stage, int progress) => switch (stage) {
        AppUpdateStage.available => 'Download',
        AppUpdateStage.downloading => 'Downloading $progress%',
        AppUpdateStage.downloaded => 'Install',
        AppUpdateStage.failed => 'Retry',
        AppUpdateStage.idle => 'Download',
      };

  @override
  Widget build(BuildContext context) {
    final update = ref.watch(appUpdateProvider);
    final stage = update.release?.version == widget.release.version
        ? update.stage
        : AppUpdateStage.available;
    final progress = update.progress;
    final c = context.colors;
    final canAccept = stage != AppUpdateStage.downloading;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: c.bgElevated,
            borderRadius: const BorderRadius.vertical(top: AppSpacing.rXl),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.14),
                        borderRadius: AppSpacing.brMd,
                      ),
                      child: Icon(
                        Icons.new_releases_outlined,
                        color: c.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Update available',
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.release.version,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (stage == AppUpdateStage.downloading)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 4,
                      backgroundColor: c.border.withValues(alpha: 0.55),
                      color: c.accent,
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  children: [
                    if (widget.release.info.trim().isNotEmpty)
                      MarkdownBody(
                        data: widget.release.info,
                        styleSheet: MarkdownStyleSheet.fromTheme(
                          Theme.of(context),
                        ).copyWith(
                          p: TextStyle(
                            color: c.textSecondary,
                            fontSize: 13,
                            height: 1.45,
                          ),
                          h1: TextStyle(
                            color: c.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          h2: TextStyle(
                            color: c.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          h3: TextStyle(
                            color: c.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          listBullet: TextStyle(color: c.textSecondary),
                        ),
                        onTapLink: (text, href, title) {
                          if (href == null) return;
                          final uri = Uri.tryParse(href);
                          if (uri != null) {
                            launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                      )
                    else
                      Text(
                        'A new version of Koma is ready to install.',
                        style: TextStyle(color: c.textSecondary, fontSize: 13),
                      ),
                    if (stage == AppUpdateStage.downloading)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'You can close this sheet — download continues in the '
                          'notification shade.',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _openReleasePage,
                        icon: Icon(
                          Icons.open_in_new,
                          size: 16,
                          color: c.accent,
                        ),
                        label: Text(
                          'Open release page',
                          style: TextStyle(color: c.accent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Not now'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: canAccept ? _onAccept : null,
                          child: Text(_acceptLabel(stage, progress)),
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
    );
  }
}

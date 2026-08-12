import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/services/app_update/app_release.dart';
import '../core/services/app_update/app_update_installer.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_spacing.dart';

enum NewUpdateStage { available, downloading, downloaded, failed }

/// Mihon [NewUpdateScreen] parity: changelog + Download → Install flow.
class NewUpdateSheet extends StatefulWidget {
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
  State<NewUpdateSheet> createState() => _NewUpdateSheetState();
}

class _NewUpdateSheetState extends State<NewUpdateSheet> {
  final _installer = AppUpdateInstaller();
  NewUpdateStage _stage = NewUpdateStage.available;
  int _progress = 0;

  Future<void> _onAccept() async {
    switch (_stage) {
      case NewUpdateStage.available:
      case NewUpdateStage.failed:
        await _startDownload();
      case NewUpdateStage.downloaded:
        await _install();
      case NewUpdateStage.downloading:
        break;
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _stage = NewUpdateStage.downloading;
      _progress = 0;
    });
    try {
      await _installer.downloadApk(
        widget.release.downloadLink,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _progress = 100;
        _stage = NewUpdateStage.downloaded;
      });
    } catch (_) {
      await _installer.deleteDownloadedApk();
      if (!mounted) return;
      setState(() => _stage = NewUpdateStage.failed);
    }
  }

  Future<void> _install() async {
    try {
      await _installer.installUpdate();
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

  String get _acceptLabel => switch (_stage) {
        NewUpdateStage.available => 'Download',
        NewUpdateStage.downloading => 'Downloading $_progress%',
        NewUpdateStage.downloaded => 'Install',
        NewUpdateStage.failed => 'Retry',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final canAccept = _stage != NewUpdateStage.downloading;

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
              if (_stage == NewUpdateStage.downloading)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: _progress / 100,
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
                          child: Text(_acceptLabel),
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

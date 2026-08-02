import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';
import 'dialog_sheet.dart';
import 'premium_button.dart';

class ImportOption {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const ImportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class ImportSheet extends StatelessWidget {
  final List<ImportOption> options;
  const ImportSheet({super.key, required this.options});

  static Future<void> show(
    BuildContext context, {
    required List<ImportOption> options,
  }) {
    return StashSheet.show<void>(
      context,
      title: 'Add to library',
      subtitle: 'Pick a source — we handle the rest.',
      initialChildSize: 0.55,
      maxChildSize: 0.7,
      child: ImportSheet(options: options),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: options.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final o = options[i];
        return AnimatedPress(
          onTap: () {
            Navigator.pop(ctx);
            // Slight delay for the sheet dismiss animation.
            Future.delayed(AppMotion.base, o.onTap);
          },
          scaleDown: 0.99,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: AppSpacing.brLg,
              border: Border.all(color: c.border, width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accentMuted,
                    borderRadius: AppSpacing.brMd,
                  ),
                  child: Icon(o.icon, color: c.accent, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.title,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        o.subtitle,
                        style: TextStyle(color: c.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: c.textTertiary, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

class UrlImportDialog extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final List<String> recentUrls;
  const UrlImportDialog({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.recentUrls = const [],
  });

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<String> onSubmit,
    List<String> recentUrls = const [],
  }) {
    final controller = TextEditingController();

    return StashDialog.show<void>(
      context,
      title: 'Add URL',
      contentWidget: UrlImportDialog(
        controller: controller,
        onSubmit: onSubmit,
        recentUrls: recentUrls,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
        PremiumButton(
          label: 'Fetch',
          onPressed: () {
            final url = controller.text.trim();
            if (url.isEmpty) return;
            Navigator.pop(context);
            onSubmit(url);
          },
          size: PremiumButtonSize.sm,
        ),
      ],
    );
  }

  @override
  State<UrlImportDialog> createState() => _UrlImportDialogState();
}

class _UrlImportDialogState extends State<UrlImportDialog> {
  TextEditingController get _controller => widget.controller;

  @override
  void dispose() {
    // controller is owned by the caller; don't dispose here
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: 'https://example.com/article',
            prefixIcon: Icon(Icons.link, color: c.textTertiary, size: 18),
          ),
          onSubmitted: (v) {
            if (v.trim().isEmpty) return;
            Navigator.pop(context);
            widget.onSubmit(v.trim());
          },
        ),
        if (widget.recentUrls.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Recent',
            style: TextStyle(
              color: c.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.recentUrls.take(3).map((url) {
              return AnimatedPress(
                onTap: () {
                  _controller.text = url;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.surfaceMuted,
                    borderRadius: AppSpacing.brPill,
                  ),
                  child: Text(
                    url,
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

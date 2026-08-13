import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_spacing.dart';

/// A full-height draggable bottom sheet with consistent styling.
class StashSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final bool showHandle;
  final double initialChildSize;
  final double maxChildSize;
  final bool isDismissible;

  const StashSheet({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.showHandle = true,
    this.initialChildSize = 0.6,
    this.maxChildSize = 0.95,
    this.isDismissible = true,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    String? subtitle,
    Widget? leading,
    List<Widget> actions = const [],
    bool showHandle = true,
    double initialChildSize = 0.6,
    double maxChildSize = 0.95,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => StashSheet(
        title: title,
        subtitle: subtitle,
        leading: leading,
        actions: actions,
        showHandle: showHandle,
        initialChildSize: initialChildSize,
        maxChildSize: maxChildSize,
        isDismissible: isDismissible,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: 0.3,
      maxChildSize: maxChildSize,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: c.bgElevated,
            borderRadius: const BorderRadius.vertical(top: AppSpacing.rXl),
            boxShadow: AppSpacing.shadow4(
              isDark: c.bg.computeLuminance() < 0.5,
            ),
          ),
          child: Column(
            children: [
              if (showHandle)
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              if (title != null || actions.isNotEmpty || leading != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                  child: Row(
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title ?? '',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: c.textPrimary),
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: c.textSecondary),
                              ),
                          ],
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                ),
              Expanded(
                child: PrimaryScrollController(
                  controller: scrollController,
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Convenience builder for a center dialog with our default styling.
class StashDialog extends StatelessWidget {
  final String title;
  final String? content;
  final Widget? contentWidget;
  final List<Widget> actions;

  const StashDialog({
    super.key,
    required this.title,
    this.content,
    this.contentWidget,
    this.actions = const [],
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    String? content,
    Widget? contentWidget,
    List<Widget> actions = const [],
  }) {
    return showDialog<T>(
      context: context,
      useRootNavigator: false,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => StashDialog(
        title: title,
        content: content,
        contentWidget: contentWidget,
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Dialog(
      backgroundColor: c.bgElevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.brXl,
        side: BorderSide(color: c.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: c.textPrimary),
            ),
            if (content != null) ...[
              const SizedBox(height: 8),
              Text(
                content!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: c.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
            if (contentWidget != null) ...[
              const SizedBox(height: 16),
              contentWidget!,
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children:
                  actions.expand((w) => [w, const SizedBox(width: 8)]).toList()
                    ..removeLast(),
            ),
          ],
        ),
      ),
    );
  }
}

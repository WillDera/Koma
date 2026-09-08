import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';
import '../theme/tokens/app_spacing.dart';
import 'icon_button_round.dart';
import 'library_stats_panel.dart';
import 'reading_calendar_sheet.dart';

/// Long-press You → floating stats popup (blurred backdrop, not a sheet).
Future<void> showStatsPopup(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Stats',
    barrierColor: Colors.transparent,
    transitionDuration: AppMotion.slow,
    pageBuilder: (context, animation, secondaryAnimation) {
      return const _StatsPopupPage();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.decelerate,
        reverseCurve: AppMotion.accelerate,
      );
      final blur = Tween<double>(begin: 0, end: 18).animate(curved);
      return AnimatedBuilder(
        animation: curved,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                behavior: HitTestBehavior.opaque,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: blur.value,
                    sigmaY: blur.value,
                  ),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.38 * curved.value),
                  ),
                ),
              ),
              FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
                  child: child,
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _StatsPopupPage extends ConsumerWidget {
  const _StatsPopupPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
            child: Material(
              color: c.surface,
              elevation: 12,
              shadowColor: Colors.black54,
              borderRadius: AppSpacing.brXl,
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Your stats',
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButtonRound(
                          icon: Icons.close_rounded,
                          size: 36,
                          variant: IconButtonVariant.filled,
                          backgroundColor: c.surfaceMuted,
                          iconColor: c.textSecondary,
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LibraryStatsPanel(
                        embedded: true,
                        onOpenCalendar: () {
                          showReadingCalendarSheet(
                            context,
                            ref.read(statsServiceProvider),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

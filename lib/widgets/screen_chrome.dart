import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';
import '../theme/tokens/app_spacing.dart';

class ScreenBackdrop extends StatelessWidget {
  final Widget child;

  const ScreenBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: c.bg)),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.85, -0.92),
                  radius: 1.05,
                  colors: [
                    c.accent.withValues(alpha: isDark ? 0.22 : 0.14),
                    c.accent.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.68],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    c.surfaceMuted.withValues(alpha: isDark ? 0.10 : 0.34),
                    c.bg.withValues(alpha: 0.0),
                    c.accentMuted.withValues(alpha: isDark ? 0.08 : 0.16),
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class StaggeredEntrance extends StatefulWidget {
  final Widget child;
  final int index;
  final Offset offset;

  const StaggeredEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = const Offset(0, 0.08),
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.page);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.decelerate,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(curved);
    Future<void>.delayed(Duration(milliseconds: 35 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) return widget.child;
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class FeaturePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> stats;

  const FeaturePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.stats = const [],
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: isDark ? 0.76 : 0.88),
          borderRadius: AppSpacing.brXl,
          border: Border.all(
            color: c.border.withValues(alpha: isDark ? 0.9 : 0.72),
            width: 0.5,
          ),
          boxShadow: AppSpacing.shadow3(isDark: isDark),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              c.accentMuted.withValues(alpha: isDark ? 0.34 : 0.48),
              c.surface.withValues(alpha: 0.96),
              c.surfaceMuted.withValues(alpha: isDark ? 0.34 : 0.55),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.14),
                    borderRadius: AppSpacing.brMd,
                    border: Border.all(color: c.accent.withValues(alpha: 0.22)),
                  ),
                  child: Icon(icon, color: c.accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (stats.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(children: stats),
            ],
          ],
        ),
      ),
    );
  }
}

class PanelStat extends StatelessWidget {
  final String value;
  final String label;

  const PanelStat({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: c.bg.withValues(alpha: 0.36),
          borderRadius: AppSpacing.brMd,
          border: Border.all(
            color: c.border.withValues(alpha: 0.55),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String title;
  final String? meta;
  final Widget? action;

  const SectionLabel({super.key, required this.title, this.meta, this.action});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          if (meta != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: c.accentMuted,
                borderRadius: AppSpacing.brPill,
              ),
              child: Text(
                meta!,
                style: TextStyle(
                  color: c.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const Spacer(),
          ?action,
        ],
      ),
    );
  }
}

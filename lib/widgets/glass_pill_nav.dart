import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';
import '../theme/tokens/app_spacing.dart';

class NavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  const NavItem({required this.icon, this.activeIcon, required this.label});
}

class GlassPillNav extends StatelessWidget {
  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final double height;
  final EdgeInsets margin;

  const GlassPillNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.height = 60,
    this.margin = const EdgeInsets.fromLTRB(20, 0, 20, 12),
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = c.bg.computeLuminance() < 0.5;
    final glassColor = isDark
        ? const Color(0xB316171A)
        : const Color(0xB3FBFAF6);
    return SafeArea(
      top: false,
      child: Padding(
        padding: margin,
        child: ClipRRect(
          borderRadius: AppSpacing.brPill,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: glassColor,
                borderRadius: AppSpacing.brPill,
                border: Border.all(
                  color: c.border.withValues(alpha: isDark ? 0.45 : 0.65),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: List.generate(items.length, (i) {
                  final item = items[i];
                  final isActive = i == currentIndex;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: AppMotion.fast,
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: anim,
                            child: FadeTransition(opacity: anim, child: child),
                          ),
                          child: Column(
                            key: ValueKey('${item.label}-$isActive'),
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isActive
                                    ? (item.activeIcon ?? item.icon)
                                    : item.icon,
                                size: 22,
                                color: isActive ? c.accent : c.textTertiary,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.label,
                                style: TextStyle(
                                  color: isActive ? c.accent : c.textTertiary,
                                  fontSize: 10,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

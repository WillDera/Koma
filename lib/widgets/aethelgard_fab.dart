import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';

/// Aethelgard-style Floating Action Button.
///
/// Circular, filled with the primary accent, and carrying the signature
/// soft outer glow (`0 0 20px rgba(accent, 0.3)`) — the only element in the
/// Aethelgard system that uses a physical-style shadow. Renders a Hugeicon
/// by default (pass [iconData]).
class AethelgardFab extends StatelessWidget {
  final AppIconData iconData;
  final VoidCallback? onPressed;
  final double size;

  const AethelgardFab({
    super.key,
    required this.iconData,
    this.onPressed,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: onPressed,
      scaleDown: 0.90,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c.accent,
          shape: BoxShape.circle,
          boxShadow: AppSpacing.fabGlow(accent: c.accent),
        ),
        child: Center(
          child: AppIcon(data: iconData, size: size * 0.46, color: c.onAccent),
        ),
      ),
    );
  }
}

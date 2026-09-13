import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../theme/presets/theme_packs.dart';
import '../../theme/presets/theme_palette.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens/app_motion.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/animated_press.dart';

/// Family + variant picker for community color themes.
class ThemePackPicker extends ConsumerWidget {
  const ThemePackPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final theme = ref.watch(themeProvider);
    final tn = ref.read(themeProvider.notifier);
    final selectedId = theme.themePackId;
    final selected = ThemePacks.tryGet(selectedId);
    final family = selected?.family ?? 'Koma';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Color theme',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Applies surfaces, text, and accent across the whole app. '
            'Sepia replaces a pack while it is on.',
            style: TextStyle(color: c.textSecondary, fontSize: 11, height: 1.35),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < ThemePacks.familyOrder.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _FamilyChip(
                    label: ThemePacks.familyOrder[i],
                    selected: family == ThemePacks.familyOrder[i],
                    swatches: _familySwatches(ThemePacks.familyOrder[i]),
                    onTap: () {
                      final packs =
                          ThemePacks.forFamily(ThemePacks.familyOrder[i]);
                      if (packs.isEmpty) return;
                      if (ThemePacks.familyOrder[i] == 'Koma') {
                        tn.setThemePackId(kDefaultThemePackId);
                        return;
                      }
                      // Keep current variant if already in family; else first.
                      final keep = packs.any((p) => p.id == selectedId);
                      tn.setThemePackId(keep ? selectedId : packs.first.id);
                    },
                  ),
                ],
              ],
            ),
          ),
          if (family != 'Koma') ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final pack in ThemePacks.forFamily(family))
                  _VariantChip(
                    pack: pack,
                    selected: selectedId == pack.id,
                    onTap: () => tn.setThemePackId(pack.id),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Color> _familySwatches(String family) {
    if (family == 'Koma') {
      return const [Color(0xFFF5F5FA), Color(0xFF0F0F0F), Color(0xFF9852FF)];
    }
    final packs = ThemePacks.forFamily(family);
    if (packs.isEmpty) return const [];
    final first = packs.first.palette;
    final accent = packs
        .map((p) => p.palette.accent)
        .fold<Color?>(null, (a, b) => a ?? b)!;
    return [first.bg, first.surface, accent];
  }
}

class _FamilyChip extends StatelessWidget {
  const _FamilyChip({
    required this.label,
    required this.selected,
    required this.swatches,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final List<Color> swatches;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        decoration: BoxDecoration(
          color: selected ? c.accent.withValues(alpha: 0.16) : c.surfaceMuted,
          borderRadius: AppSpacing.brPill,
          border: Border.all(
            color: selected ? c.accent : c.border,
            width: selected ? 1.2 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SwatchStack(colors: swatches),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? c.accent : c.textPrimary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VariantChip extends StatelessWidget {
  const _VariantChip({
    required this.pack,
    required this.selected,
    required this.onTap,
  });

  final ThemePack pack;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = pack.palette;
    return AnimatedPress(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        width: 108,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: p.bg,
          borderRadius: AppSpacing.brMd,
          border: Border.all(
            color: selected ? c.accent : p.border,
            width: selected ? 2 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Dot(p.accent),
                const SizedBox(width: 4),
                _Dot(p.surfaceMuted),
                const SizedBox(width: 4),
                _Dot(p.textPrimary),
                const Spacer(),
                if (selected)
                  Icon(Icons.check_circle, size: 14, color: c.accent),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              pack.variant,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              pack.isDark ? 'Dark' : 'Light',
              style: TextStyle(color: p.textTertiary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwatchStack extends StatelessWidget {
  const _SwatchStack({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final shown = colors.take(3).toList();
    return SizedBox(
      width: 22,
      height: 14,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 5.0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: shown[i],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black26, width: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black26, width: 0.4),
      ),
    );
  }
}

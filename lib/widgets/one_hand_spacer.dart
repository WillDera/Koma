import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/theme_provider.dart';

/// When one-hand mode is on, this takes up ~30 % of the usable screen
/// height. Place it as the first child inside a **non-sliver** scrollable
/// (ListView / Column). For [CustomScrollView], use [SliverOneHandSpacer].
class OneHandSpacer extends ConsumerWidget {
  const OneHandSpacer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(themeProvider).oneHandMode;
    if (!on) return const SizedBox.shrink();
    final screenHeight = MediaQuery.of(context).size.height;
    final topInset = MediaQuery.of(context).padding.top;
    final available = screenHeight - topInset;
    return SizedBox(height: available * 0.30);
  }
}

/// Sliver wrapper for [OneHandSpacer] — safe as a [CustomScrollView] child.
class SliverOneHandSpacer extends StatelessWidget {
  const SliverOneHandSpacer({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(child: OneHandSpacer());
  }
}

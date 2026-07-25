import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';

/// When one-hand mode is on, this takes up 50 % of the usable screen
/// height.  Place it as the first child inside a scrollable widget so
/// it scrolls away when the user pulls up — it is not a fixed header.
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

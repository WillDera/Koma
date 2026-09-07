import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/icon_button_round.dart';
import '../../widgets/screen_chrome.dart';
import '../../widgets/text_field.dart';
import 'global_search_provider.dart';
import 'global_search_widgets.dart';

/// Mihon-parity catalogue Global Search: per-source horizontal rows,
/// Pinned/All + Has-results chips, progressive Loading/Success/Error.
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  late final TextEditingController _ctrl;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery ?? '');
    final q = widget.initialQuery?.trim() ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Ensure migrate-only source exclude does not leak into Global Search.
      ref.read(globalSearchProvider.notifier).setExcludeSourceId(null);
      if (q.isNotEmpty) {
        ref.read(globalSearchProvider.notifier).search(q);
      } else {
        _focus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final q = _ctrl.text.trim();
    ref.read(globalSearchProvider.notifier).search(q);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final notifier = ref.read(globalSearchProvider.notifier);

    return ScreenBackdrop(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
              child: Row(
                children: [
                  IconButtonRound(
                    iconData: AppIcons.back,
                    size: 40,
                    variant: IconButtonVariant.plain,
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Global search',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: StashTextField(
                controller: _ctrl,
                focusNode: _focus,
                hint: 'Search installed sources…',
                leadingIcon: Icons.search,
                showClearButton: true,
                textInputAction: TextInputAction.search,
                onChanged: notifier.setQuery,
                onSubmitted: (_) => _submit(),
                trailing: AnimatedPress(
                  onTap: _submit,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.search, color: c.accent, size: 20),
                  ),
                ),
              ),
            ),
            const GlobalSearchFilterBar(),
            const Expanded(child: GlobalSearchResultsList()),
          ],
        ),
      ),
    );
  }
}

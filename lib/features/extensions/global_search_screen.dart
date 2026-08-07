import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
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
    if (q.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(globalSearchProvider.notifier).search(q);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
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
    final state = ref.watch(globalSearchProvider);
    final notifier = ref.read(globalSearchProvider.notifier);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: TextField(
          controller: _ctrl,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onChanged: notifier.setQuery,
          onSubmitted: (_) => _submit(),
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: 'Global search',
            hintStyle: TextStyle(color: c.textSecondary),
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: Icon(Icons.search, color: c.textSecondary),
              onPressed: _submit,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(state.searching ? 52 : 48),
          child: const GlobalSearchFilterBar(),
        ),
      ),
      body: const GlobalSearchResultsList(),
    );
  }
}

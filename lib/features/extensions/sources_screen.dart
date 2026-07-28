import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/models/extension_source.dart';
import '../../core/utils/custom_extended_image_provider.dart';
import '../../core/utils/language.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/animated_press.dart';
import 'source_browse_screen.dart';

/// Browse all installed sources — ported from mangayomi's SourcesScreen.
///
/// Shows sources in three sections:
///   1. Last Used (sources previously tapped)
///   2. Pinned (user-pinned sources)
///   3. By Language (all remaining sources grouped by language)
class SourcesScreen extends ConsumerStatefulWidget {
  const SourcesScreen({super.key});

  @override
  ConsumerState<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends ConsumerState<SourcesScreen> {
  List<ExtensionSource> _sources = [];
  bool _loading = true;
  String? _lastUsedId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repos = ref.watch(repositoriesProvider);
    final sources = await repos.extensions.getInstalledExtensions();
    if (!mounted) return;
    setState(() {
      _sources = sources;
      _loading = false;
    });
  }

  Future<void> _navigateToSource(ExtensionSource src) async {
    setState(() => _lastUsedId = src.id);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SourceBrowseScreen(
          sourceId: src.id,
          sourceName: src.name,
        ),
      ),
    );
  }

  Future<void> _navigateToLatest(ExtensionSource src) async {
    setState(() => _lastUsedId = src.id);
    if (!mounted) return;
    // Browse with a pre-applied search of "latest" (mangayomi's "Latest" button)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SourceBrowseScreen(
          sourceId: src.id,
          sourceName: src.name,
        ),
      ),
    );
  }

  Future<void> _togglePin(ExtensionSource src) async {
    final repos = ref.watch(repositoriesProvider);
    final updated = src.copyWith(
      isPinned: !src.isPinned,
      updatedAt: DateTime.now(),
    );
    await repos.extensions.insertExtensionSource(updated);
    setState(() {
      _sources = _sources.map((s) => s.id == src.id ? updated : s).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        title: Text('Sources', style: TextStyle(color: c.textPrimary)),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sources.isEmpty
              ? _EmptyState(c)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── Last Used ──
                    ..._buildLastUsedSection(c),
                    // ── Pinned ──
                    ..._buildPinnedSection(c),
                    // ── By Language ──
                    ..._buildLanguageSection(c),
                  ],
                ),
    );
  }

  List<Widget> _buildLastUsedSection(KomaColors c) {
    if (_lastUsedId == null) return [];
    final src = _sources.where((s) => s.id == _lastUsedId).firstOrNull;
    if (src == null) return [];
    return [
      _sectionHeader(c, 'Last Used'),
      _SourceTile(
        source: src,
        c: c,
        onTap: () => _navigateToSource(src),
        onLatest: () => _navigateToLatest(src),
        onPinToggle: () => _togglePin(src),
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildPinnedSection(KomaColors c) {
    final pinned = _sources.where((s) => s.isPinned).toList();
    if (pinned.isEmpty) return [];
    // Remove the last used from pinned to avoid dupes (mangayomi allows dupes though)
    return [
      _sectionHeader(c, 'Pinned'),
      ...pinned.map((src) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _SourceTile(
              source: src,
              c: c,
              onTap: () => _navigateToSource(src),
              onLatest: () => _navigateToLatest(src),
              onPinToggle: () => _togglePin(src),
            ),
          )),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildLanguageSection(KomaColors c) {
    final unpinned = _sources
        .where((s) => !s.isPinned && s.id != _lastUsedId)
        .toList();
    if (unpinned.isEmpty) return [];

    // Group by language
    final groups = <String, List<ExtensionSource>>{};
    for (final src in unpinned) {
      final lang = src.lang.toLowerCase();
      groups.putIfAbsent(lang, () => []);
      groups[lang]!.add(src);
    }

    final sortedKeys = groups.keys.toList()
      ..sort((a, b) => completeLanguageName(a).compareTo(completeLanguageName(b)));

    final widgets = <Widget>[];
    for (final langKey in sortedKeys) {
      final langName = completeLanguageName(langKey);
      final group = groups[langKey]!;
      group.sort((a, b) => a.name.compareTo(b.name));

      widgets.add(_sectionHeader(c, langName));
      for (final src in group) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _SourceTile(
            source: src,
            c: c,
            onTap: () => _navigateToSource(src),
            onLatest: () => _navigateToLatest(src),
            onPinToggle: () => _togglePin(src),
          ),
        ));
      }
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  Widget _sectionHeader(KomaColors c, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: c.textPrimary,
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final ExtensionSource source;
  final KomaColors c;
  final VoidCallback onTap;
  final VoidCallback onLatest;
  final VoidCallback onPinToggle;

  const _SourceTile({
    required this.source,
    required this.c,
    required this.onTap,
    required this.onLatest,
    required this.onPinToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: AppSpacing.brMd,
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            _buildIcon(source.iconUrl, c, size: 37),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          source.name,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (source.isNsfw) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(204),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NSFW',
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    completeLanguageName(source.lang),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300, color: c.textSecondary),
                  ),
                ],
              ),
            ),
            // "Latest" button (mangayomi pattern)
            TextButton(
              style: ButtonStyle(padding: WidgetStateProperty.all(const EdgeInsets.all(10))),
              onPressed: onLatest,
              child: Text('Latest', style: TextStyle(fontSize: 12, color: c.accent)),
            ),
            const SizedBox(width: 4),
            // Pin toggle (mangayomi pattern)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(
                Icons.push_pin_outlined,
                size: 18,
                color: source.isPinned ? c.accent : c.textTertiary,
              ),
              onPressed: onPinToggle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(String? iconUrl, KomaColors c, {double size = 37}) {
    if (iconUrl == null || iconUrl.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.extension_rounded, color: c.accent, size: size * 0.75),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Image(
          image: CustomExtendedNetworkImageProvider(iconUrl),
          fit: BoxFit.contain,
          width: size,
          height: size,
          errorBuilder: (_, __, ___) => SizedBox(
            width: size,
            height: size,
            child: Icon(Icons.extension_rounded, color: c.accent, size: size * 0.75),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final KomaColors c;
  const _EmptyState(this.c);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.extension_off_outlined, size: 56, color: c.textTertiary),
            const SizedBox(height: 16),
            Text(
              'No sources installed',
              style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Install extensions from the Extensions tab first.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/models/extension_source.dart';
import '../../core/services/extension_icon_cache.dart';
import '../../core/utils/custom_extended_image_provider.dart';
import '../../core/utils/language.dart';
import '../../theme/app_theme.dart';
import 'source_browse_screen.dart';

/// Extract the package name from an installed extension's on-disk APK path,
/// where the file is stored as `{extensionsDir}/{pkg}.apk`.
String _extractPkgFromApkPath(String apkPath) {
  final fileName = apkPath.split('/').last;
  if (fileName.endsWith('.apk')) {
    return fileName.substring(0, fileName.length - 4);
  }
  return fileName;
}

/// Extension detail screen — ported from mangayomi's ExtensionDetail.
///
/// Shows the extension icon, name, version, language, and uninstall action.
class ExtensionDetailScreen extends StatelessWidget {
  final ExtensionSource source;
  final VoidCallback onUninstall;

  const ExtensionDetailScreen({
    super.key,
    required this.source,
    required this.onUninstall,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        title: Text(
          'Extension Detail',
          style: TextStyle(color: c.textPrimary),
        ),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Icon
            Container(
              decoration: BoxDecoration(
                color: c.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: _buildLargeIcon(_extractPkgFromApkPath(source.apkPath), c),
            ),
            const SizedBox(height: 12),
            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                source.name,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            // Info cards: Version + Language
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.accent.withAlpha(51),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoCard(c, source.version, 'Version'),
                    _infoCard(
                      c,
                      completeLanguageName(source.lang),
                      'Language',
                    ),
                  ],
                ),
              ),
            ),
            // Base URL
            if (source.baseUrl != null && source.baseUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link, size: 16, color: c.textTertiary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          source.baseUrl!,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (source.versionLast != null) ...[
              const SizedBox(height: 16),
              // Browse button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SourceBrowseScreen(
                          sourceId: source.sourceId,
                          sourceName: source.name,
                        ),
                      ),
                    ),
                    icon: Icon(Icons.explore_outlined, color: c.accent),
                    label: Text(
                      'Browse ${source.name}',
                      style: TextStyle(color: c.accent),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Uninstall button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmUninstall(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.redAccent.withAlpha(128)),
                  ),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  label: const Text(
                     'Unload',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(KomaColors c, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: c.textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  void _confirmUninstall(BuildContext context) {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(source.name, style: TextStyle(color: c.textPrimary)),
        content: Text(
          'Unload ${source.name}? This will remove all sources sharing its APK.',
          style: TextStyle(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              onUninstall();
            },
            child: Text('OK', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeIcon(String pkg, KomaColors c) {
    return _LargePkgExtensionIcon(pkg: pkg, colors: c);
  }
}

/// Large (140×140) variant of the pkg-resolving icon widget for the detail
/// screen. Resolves the icon URL via [ExtensionIconCache] (cache-first, with
/// a deterministic CDN derivation fallback), so already-installed extensions
/// with a stale `.../repo/icon/${pkg}.png` iconUrl self-heal. See Q5.
class _LargePkgExtensionIcon extends StatefulWidget {
  final String pkg;
  final KomaColors colors;

  const _LargePkgExtensionIcon({required this.pkg, required this.colors});

  @override
  State<_LargePkgExtensionIcon> createState() => _LargePkgExtensionIconState();
}

class _LargePkgExtensionIconState extends State<_LargePkgExtensionIcon> {
  String? _url = ExtensionIconCache.iconUrlForPkg('');

  @override
  void initState() {
    super.initState();
    _url = ExtensionIconCache.iconUrlForPkg(widget.pkg);
    _resolveFromCache();
  }

  Future<void> _resolveFromCache() async {
    final cached =
        await ExtensionIconCache.instance.cachedIconUrl(widget.pkg);
    if (!mounted) return;
    if (cached != null && cached.isNotEmpty && cached != _url) {
      setState(() => _url = cached);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (url == null || url.isEmpty) {
      return const SizedBox(
        width: 140,
        height: 140,
        child: Icon(Icons.source_outlined, size: 140),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image(
        image: CustomExtendedNetworkImageProvider(url, printError: false),
        fit: BoxFit.contain,
        width: 140,
        height: 140,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const SizedBox(
          width: 140,
          height: 140,
          child: Icon(Icons.source_outlined, size: 140),
        ),
      ),
    );
  }
}

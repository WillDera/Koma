import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../features/extensions/extensions_catalog_provider.dart';
import '../../router/router.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/screen_chrome.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/toast.dart';

/// In-app Plugin SDK hub — docs + sample installs for any source platform.
class PluginSdkScreen extends ConsumerStatefulWidget {
  const PluginSdkScreen({super.key});

  @override
  ConsumerState<PluginSdkScreen> createState() => _PluginSdkScreenState();
}

class _PluginSdkScreenState extends ConsumerState<PluginSdkScreen> {
  bool _installing = false;

  /// Manga-oriented JS starter (image chapters via getPageList).
  static const _mangaStarter = r'''
const mangayomiSources = [{
  "name": "My Source",
  "lang": "en",
  "baseUrl": "https://example.com",
  "apiUrl": "",
  "version": "1.0.0",
  "itemType": 0,
  "sourceCodeLanguage": 1,
  "hasCloudflare": false,
}];

class DefaultExtension extends MProvider {
  get supportsLatest() { return true; }

  getHeaders(url) {
    return {
      "User-Agent":
        "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/124.0.0.0 Mobile Safari/537.36",
    };
  }

  async getPopular(page) {
    return { list: [], hasNextPage: false };
  }

  async getLatestUpdates(page) {
    return { list: [], hasNextPage: false };
  }

  async search(query, page, filters) {
    return { list: [], hasNextPage: false };
  }

  async getDetail(url) {
    return {
      name: "Title",
      link: url,
      imageUrl: "",
      description: "",
      author: "",
      genre: [],
      status: 0,
      chapters: [{ name: "Chapter 1", url: url + "/1" }],
    };
  }

  async getPageList(url) {
    // Return image page URLs for the manga reader.
    return [];
  }

  getFilterList() { return []; }
  getSourcePreferences() { return []; }
}
''';

  /// Novel-oriented JS starter (HTML chapters via getHtmlContent).
  static const _novelStarter = r'''
const mangayomiSources = [{
  "name": "My Novel Source",
  "lang": "en",
  "baseUrl": "https://example.com",
  "apiUrl": "https://api.example.com",
  "version": "1.0.0",
  "itemType": 2,
  "sourceCodeLanguage": 1,
  "hasCloudflare": false,
}];

class DefaultExtension extends MProvider {
  get supportsLatest() { return true; }

  getHeaders(url) {
    return { "User-Agent": "Koma" };
  }

  async getPopular(page) {
    return { list: [], hasNextPage: false };
  }

  async getLatestUpdates(page) {
    return { list: [], hasNextPage: false };
  }

  async search(query, page, filters) {
    return { list: [], hasNextPage: false };
  }

  async getDetail(url) {
    return {
      name: "Title",
      link: url,
      imageUrl: "",
      description: "",
      author: "",
      genre: [],
      status: 0,
      chapters: [{ name: "Chapter 1", url: url + "/1" }],
    };
  }

  async getPageList(url) { return []; }

  async getHtmlContent(name, url) {
    return await this.cleanHtmlContent("<p>Hello from Koma.</p>");
  }

  async cleanHtmlContent(html) {
    return '<html><body>' + html + '</body></html>';
  }

  getFilterList() { return []; }
  getSourcePreferences() { return []; }
}
''';

  Future<void> _installNovelBuddy() async {
    if (_installing) return;
    setState(() => _installing = true);
    try {
      final code = await rootBundle.loadString(
        'assets/extensions/novelbuddy.js',
      );
      final mgr = ref.read(extensionManagerProvider);
      await mgr.installJsFromSourceCode(
        sourceCode: code,
        pkg: 'koma.novelbuddy',
      );
      // Extensions hub / Sources keep session caches — refresh so Loaded
      // shows the new source without an app restart.
      await ref.read(extensionsCatalogProvider.notifier).refreshInstalled();
      if (!mounted) return;
      StashToast.show(
        context,
        message: 'NovelBuddy installed — open Sources to browse',
        icon: Icons.check,
      );
    } catch (e) {
      if (!mounted) return;
      StashToast.show(
        context,
        message: 'Install failed: $e',
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  Future<void> _copyTemplate(String label, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    StashToast.show(
      context,
      message: '$label copied',
      icon: Icons.content_copy_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ScreenBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Plugin SDK'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Text(
              'Build sources for any site',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ship a JavaScript, Dart, or Mihon APK extension that implements '
              'MProvider (Mangayomi-compatible). Point it at any catalog or '
              'reader site — Koma will browse, search, library-update, and open '
              'chapters the same way.',
              style: TextStyle(color: c.textSecondary, height: 1.45),
            ),
            const SizedBox(height: 20),
            SettingsSection(
              title: 'Get started',
              children: [
                SettingsRow(
                  icon: Icons.content_copy_outlined,
                  title: 'Copy manga starter',
                  subtitle:
                      'DefaultExtension skeleton with getPageList '
                      '(itemType 0)',
                  trailing: const Icon(Icons.copy_all_outlined, size: 18),
                  onTap: () => _copyTemplate('Manga starter', _mangaStarter),
                ),
                SettingsRow(
                  icon: Icons.menu_book_outlined,
                  title: 'Copy novel starter',
                  subtitle:
                      'Same ABI + getHtmlContent / cleanHtmlContent '
                      '(itemType 2)',
                  trailing: const Icon(Icons.copy_all_outlined, size: 18),
                  onTap: () => _copyTemplate('Novel starter', _novelStarter),
                ),
                SettingsRow(
                  icon: Icons.auto_stories_outlined,
                  title: 'Install NovelBuddy sample',
                  subtitle:
                      'Working novel source against api.novelbuddy.me — '
                      'reference for HTTP JSON plugins',
                  trailing: _installing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined, size: 18),
                  onTap: _installing ? null : _installNovelBuddy,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingsSection(
              title: 'Where plugins live',
              children: [
                SettingsRow(
                  icon: Icons.extension_outlined,
                  title: 'Extensions',
                  subtitle: 'Loaded / Available / Repos',
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => context.pushNamed(Routes.extensions),
                ),
                SettingsRow(
                  icon: Icons.layers_outlined,
                  title: 'Sources',
                  subtitle: 'Browse installed manga & novel sources',
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => context.pushNamed(Routes.sources),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingsSection(
              title: 'ABI quick reference',
              footer:
                  'Full notes: docs/plugin-sdk/README.md in the repo.',
              children: [
                _DocBlock(
                  title: 'Catalog (all item types)',
                  body:
                      'getPopular · getLatestUpdates · search · getDetail · '
                      'getFilterList · getSourcePreferences\n'
                      'getDetail must return chapters[]. Library updates '
                      're-fetch that list to find new chapters.',
                ),
                _DocBlock(
                  title: 'Manga chapters (itemType 0)',
                  body:
                      'getPageList(url) → image page URLs for the manga reader.',
                ),
                _DocBlock(
                  title: 'Novel chapters (itemType 2)',
                  body:
                      'getHtmlContent(name, url) · cleanHtmlContent(html)\n'
                      'Return HTML; Koma opens the novel reader and caches '
                      'under novels/.',
                ),
                _DocBlock(
                  title: 'Runtimes',
                  body:
                      'JavaScript (flutter_qjs) · Dart (d4rt) · Mihon APK '
                      '(Dalvik). Prefer JS for HTTP + JSON/HTML sites.',
                ),
                _DocBlock(
                  title: 'Header',
                  body:
                      'const mangayomiSources = [{ "name", "lang", "baseUrl", '
                      '"apiUrl", "itemType": 0|1|2, "sourceCodeLanguage": 1 }]\n'
                      '0 manga · 1 anime (unsupported) · 2 novel. '
                      'Class must be DefaultExtension extends MProvider.',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surfaceMuted,
                borderRadius: AppSpacing.brLg,
              ),
              child: Text(
                'Tip: after Install / sideload, the source shows under '
                'Extensions → Loaded and Sources immediately. Open it, browse '
                'or search, add a title to library — Updates will poll '
                'getDetail chapters like any other source.',
                style: TextStyle(
                  color: c.textSecondary,
                  height: 1.45,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocBlock extends StatelessWidget {
  const _DocBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

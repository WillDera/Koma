import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../core/models/extension_repo.dart';
import '../../core/providers.dart';
import '../../features/extensions/extensions_catalog_provider.dart';
import '../../router/router.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/screen_chrome.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/toast.dart';

/// Official hosted catalog (GitHub Pages). Raw GitHub works as a fallback
/// before Pages is enabled.
class KomaOfficialExtensions {
  static const pagesIndex =
      'https://willdera.github.io/Koma/extensions/index.json';
  static const pagesNovelBuddy =
      'https://willdera.github.io/Koma/extensions/novelbuddy.js';
  static const rawIndex =
      'https://raw.githubusercontent.com/WillDera/Koma/main/extensions/index.json';
  static const rawNovelBuddy =
      'https://raw.githubusercontent.com/WillDera/Koma/main/extensions/novelbuddy.js';
  static const siteHome = 'https://willdera.github.io/Koma/';
}

/// In-app Plugin SDK hub — docs + sample installs for any source platform.
class PluginSdkScreen extends ConsumerStatefulWidget {
  const PluginSdkScreen({super.key});

  @override
  ConsumerState<PluginSdkScreen> createState() => _PluginSdkScreenState();
}

class _PluginSdkScreenState extends ConsumerState<PluginSdkScreen> {
  bool _busy = false;

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

  Future<String> _fetchText(List<String> urls) async {
    Object? last;
    for (final u in urls) {
      try {
        final res = await http.get(Uri.parse(u));
        if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
          return res.body;
        }
        last = 'HTTP ${res.statusCode} for $u';
      } catch (e) {
        last = e;
      }
    }
    throw StateError('Download failed: $last');
  }

  Future<void> _addOfficialRepo() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final mgr = ref.read(extensionManagerProvider);
      // Prefer Pages; fall back to raw GitHub if Pages is not live yet.
      String indexUrl = KomaOfficialExtensions.pagesIndex;
      try {
        final probe = await http.head(Uri.parse(indexUrl));
        if (probe.statusCode < 200 || probe.statusCode >= 300) {
          indexUrl = KomaOfficialExtensions.rawIndex;
        }
      } catch (_) {
        indexUrl = KomaOfficialExtensions.rawIndex;
      }
      await mgr.addRepo(
        name: 'Koma Official',
        url: indexUrl,
        kind: ExtensionRepoKind.javascript,
      );
      final catalog = ref.read(extensionsCatalogProvider.notifier);
      await catalog.refreshInstalled();
      final repos = await mgr.listRepos();
      final repo = repos.where((r) => r.url == indexUrl).firstOrNull ??
          repos.where((r) => r.name == 'Koma Official').firstOrNull;
      if (repo != null) {
        await catalog.fetchIndex(repo);
      }
      if (!mounted) return;
      StashToast.show(
        context,
        message: 'Official repo added — install from Extensions → Available',
        icon: Icons.check,
      );
    } catch (e) {
      if (!mounted) return;
      StashToast.show(
        context,
        message: 'Could not add repo: $e',
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _installNovelBuddy() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final code = await _fetchText([
        KomaOfficialExtensions.pagesNovelBuddy,
        KomaOfficialExtensions.rawNovelBuddy,
      ]);
      final mgr = ref.read(extensionManagerProvider);
      await mgr.installJsFromSourceCode(
        sourceCode: code,
        pkg: 'koma.novelbuddy',
        repoUrl: KomaOfficialExtensions.pagesIndex,
      );
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
      if (mounted) setState(() => _busy = false);
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

  Future<void> _copyRepoUrl() async {
    await Clipboard.setData(
      const ClipboardData(text: KomaOfficialExtensions.pagesIndex),
    );
    if (!mounted) return;
    StashToast.show(
      context,
      message: 'Repo URL copied',
      icon: Icons.link,
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
              title: 'Official catalog',
              footer:
                  'Hosted on GitHub Pages (${KomaOfficialExtensions.siteHome}). '
                  'Extensions live in the repo under extensions/.',
              children: [
                SettingsRow(
                  icon: Icons.cloud_download_outlined,
                  title: 'Add official extensions repo',
                  subtitle: KomaOfficialExtensions.pagesIndex,
                  trailing: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_link, size: 18),
                  onTap: _busy ? null : _addOfficialRepo,
                ),
                SettingsRow(
                  icon: Icons.link,
                  title: 'Copy repo URL',
                  subtitle: 'Paste into Extensions → Repos → Add repo',
                  trailing: const Icon(Icons.content_copy_outlined, size: 18),
                  onTap: _copyRepoUrl,
                ),
                SettingsRow(
                  icon: Icons.auto_stories_outlined,
                  title: 'Install NovelBuddy',
                  subtitle:
                      'Fetches novelbuddy.js from the official catalog '
                      '(not bundled in the APK)',
                  trailing: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined, size: 18),
                  onTap: _busy ? null : _installNovelBuddy,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingsSection(
              title: 'Starters',
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
                'Tip: after adding the official repo, install sources from '
                'Extensions → Available. Updates poll getDetail / getChapterList '
                'like any other catalog.',
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

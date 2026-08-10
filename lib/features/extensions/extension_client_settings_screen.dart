import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/extension_source.dart';
import '../../core/providers.dart';
import '../../core/services/extension_client_settings.dart';
import '../../core/services/source_webview_bridge.dart';
import '../../core/utils/language.dart';
import '../../theme/app_theme.dart';
import 'extension_code_editor_screen.dart';

/// App-owned extension client settings (URL, UA, language, cover, code, web).
/// Separate from Mihon/JS source preference screens.
class ExtensionClientSettingsScreen extends ConsumerStatefulWidget {
  const ExtensionClientSettingsScreen({super.key, required this.source});

  final ExtensionSource source;

  @override
  ConsumerState<ExtensionClientSettingsScreen> createState() =>
      _ExtensionClientSettingsScreenState();
}

class _ExtensionClientSettingsScreenState
    extends ConsumerState<ExtensionClientSettingsScreen> {
  late ExtensionSource _source;
  ExtensionClientSettings _settings = const ExtensionClientSettings();
  bool _loading = true;
  final _urlCtrl = TextEditingController();
  final _uaCtrl = TextEditingController();
  final _langCtrl = TextEditingController();

  bool get _canEditCode => _source.isJs || _source.isDart;

  @override
  void initState() {
    super.initState();
    _source = widget.source;
    _urlCtrl.text = _source.baseUrl ?? '';
    _load();
  }

  Future<void> _load() async {
    final s = await ExtensionClientSettings.load(_source.sourceId);
    if (!mounted) return;
    setState(() {
      _settings = s;
      _uaCtrl.text = s.userAgent;
      _langCtrl.text = s.filterLanguage;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _uaCtrl.dispose();
    _langCtrl.dispose();
    super.dispose();
  }

  Future<void> _persistSettings(ExtensionClientSettings next) async {
    await next.save(_source.sourceId);
    if (!mounted) return;
    setState(() => _settings = next);
  }

  Future<void> _saveBaseUrl() async {
    final url = _urlCtrl.text.trim();
    final updated = _source.copyWith(
      baseUrl: url.isEmpty ? null : url,
      updatedAt: DateTime.now(),
    );
    await ref
        .read(repositoriesProvider)
        .extensions
        .insertExtensionSource(updated);
    if (!mounted) return;
    setState(() => _source = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Source URL saved')),
    );
  }

  Future<void> _openWebsite() async {
    final url = (_urlCtrl.text.trim().isNotEmpty
            ? _urlCtrl.text.trim()
            : (_source.baseUrl ?? ''))
        .trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No website URL set')),
      );
      return;
    }
    try {
      await SourceWebViewBridge.open(
        url: url,
        sourceId: _source.sourceId,
        title: _source.name,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WebView failed: $e')),
      );
    }
  }

  Future<void> _openCodeEditor() async {
    if (!_canEditCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mihon APK sources cannot be edited as text'),
        ),
      );
      return;
    }
    final updated = await Navigator.push<ExtensionSource>(
      context,
      MaterialPageRoute(
        builder: (_) => ExtensionCodeEditorScreen(source: _source),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _source = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_loading) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.bg,
          title: Text('Client settings', style: TextStyle(color: c.textPrimary)),
          iconTheme: IconThemeData(color: c.textPrimary),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        title: Text('Client settings', style: TextStyle(color: c.textPrimary)),
        iconTheme: IconThemeData(color: c.textPrimary),
        actions: [
          IconButton(
            tooltip: 'Open website',
            onPressed: _openWebsite,
            icon: Icon(Icons.public, color: c.accent),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            _source.name,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            completeLanguageName(_source.lang),
            style: TextStyle(color: c.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),
          _sectionLabel(c, 'Source URL'),
          const SizedBox(height: 8),
          TextField(
            controller: _urlCtrl,
            style: TextStyle(color: c.textPrimary, fontSize: 13),
            decoration: _fieldDeco(
              c,
              hint: 'https://…',
              suffix: IconButton(
                tooltip: 'Save URL',
                onPressed: _saveBaseUrl,
                icon: Icon(Icons.check, color: c.accent, size: 20),
              ),
            ),
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _saveBaseUrl(),
          ),
          const SizedBox(height: 4),
          Text(
            'Overrides the site the extension calls (e.g. mangadex.com → mangadex.ru).',
            style: TextStyle(color: c.textTertiary, fontSize: 11),
          ),
          const SizedBox(height: 20),
          _sectionLabel(c, 'User-Agent'),
          const SizedBox(height: 8),
          TextField(
            controller: _uaCtrl,
            style: TextStyle(color: c.textPrimary, fontSize: 13),
            decoration: _fieldDeco(
              c,
              hint: 'Leave empty for default browser UA',
              suffix: IconButton(
                tooltip: 'Save UA',
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await _persistSettings(
                    _settings.copyWith(userAgent: _uaCtrl.text.trim()),
                  );
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(content: Text('User-Agent saved')),
                  );
                },
                icon: Icon(Icons.check, color: c.accent, size: 20),
              ),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          _sectionLabel(c, 'Filter language'),
          const SizedBox(height: 8),
          TextField(
            controller: _langCtrl,
            style: TextStyle(color: c.textPrimary, fontSize: 13),
            decoration: _fieldDeco(
              c,
              hint: 'e.g. en, es — empty = all',
              suffix: IconButton(
                tooltip: 'Save language',
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final lang = _langCtrl.text.trim().toLowerCase();
                  await _persistSettings(
                    _settings.copyWith(filterLanguage: lang),
                  );
                  if (lang.isNotEmpty && lang != _source.lang) {
                    final updated = _source.copyWith(
                      lang: lang,
                      updatedAt: DateTime.now(),
                    );
                    await ref
                        .read(repositoriesProvider)
                        .extensions
                        .insertExtensionSource(updated);
                    if (mounted) setState(() => _source = updated);
                  }
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Filter language saved')),
                  );
                },
                icon: Icon(Icons.check, color: c.accent, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel(c, 'Manga cover quality'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final q in CoverQuality.values)
                ChoiceChip(
                  label: Text(q.label),
                  selected: _settings.coverQuality == q,
                  onSelected: (_) => _persistSettings(
                    _settings.copyWith(coverQuality: q),
                  ),
                  selectedColor: c.accent.withValues(alpha: 0.25),
                  labelStyle: TextStyle(
                    color: _settings.coverQuality == q
                        ? c.accent
                        : c.textSecondary,
                    fontSize: 13,
                  ),
                  side: BorderSide(
                    color: _settings.coverQuality == q ? c.accent : c.border,
                  ),
                  backgroundColor: c.surface,
                ),
            ],
          ),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.code, color: c.accent),
            title: Text(
              'View / edit source code',
              style: TextStyle(color: c.textPrimary, fontSize: 14),
            ),
            subtitle: Text(
              _canEditCode
                  ? 'Edit the installed ${_source.isJs ? 'JavaScript' : 'Dart'} body'
                  : 'Not available for Mihon APK extensions',
              style: TextStyle(color: c.textTertiary, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: c.textTertiary),
            onTap: _openCodeEditor,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.public, color: c.accent),
            title: Text(
              'Open extension website',
              style: TextStyle(color: c.textPrimary, fontSize: 14),
            ),
            subtitle: Text(
              _urlCtrl.text.trim().isNotEmpty
                  ? _urlCtrl.text.trim()
                  : (_source.baseUrl ?? 'No URL'),
              style: TextStyle(color: c.textTertiary, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Icon(Icons.open_in_new, color: c.textTertiary, size: 18),
            onTap: _openWebsite,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(KomaColors c, String text) {
    return Text(
      text,
      style: TextStyle(
        color: c.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }

  InputDecoration _fieldDeco(
    KomaColors c, {
    required String hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: c.textTertiary, fontSize: 13),
      filled: true,
      fillColor: c.surface,
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c.accent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}

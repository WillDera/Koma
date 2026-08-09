import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/extension_source.dart';
import '../../core/providers.dart';
import '../../eval/javascript/bridges/prefs_bridge.dart';
import '../../eval/models/m_source.dart';
import '../../eval/models/source_preference.dart';
import '../../theme/app_theme.dart';

/// Flutter source-settings UI for JS extensions (mangayomi
/// [SourcePreferenceWidget] patterns + PrefsCache persistence).
class JsSourcePreferencesScreen extends ConsumerStatefulWidget {
  final ExtensionSource source;

  const JsSourcePreferencesScreen({super.key, required this.source});

  @override
  ConsumerState<JsSourcePreferencesScreen> createState() =>
      _JsSourcePreferencesScreenState();
}

class _JsSourcePreferencesScreenState
    extends ConsumerState<JsSourcePreferencesScreen> {
  List<SourcePreference>? _prefs;
  String? _error;
  bool _loading = true;

  String get _sourceId => widget.source.sourceId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await hydrateJsPrefsCache();
      final service = ref.read(extensionServiceProvider);
      final mSource = MSource.fromExtensionSource(widget.source);
      final prefs = await service.getSourcePreferences(mSource);
      for (final p in prefs) {
        final key = p.key;
        if (key == null || key.isEmpty) continue;
        p.applyStoredValue(getJsPreferenceValue(_sourceId, key));
      }
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _persist(SourcePreference preference) {
    final key = preference.key;
    if (key == null || key.isEmpty) return;
    final value = preference.typedValue;
    if (value == null) return;
    setJsPreferenceValue(_sourceId, key, value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        title: Text(
          'Source settings',
          style: TextStyle(color: c.textPrimary),
        ),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.accent))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      style: TextStyle(color: c.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : (_prefs == null || _prefs!.isEmpty)
                  ? Center(
                      child: Text(
                        'No settings for this source',
                        style: TextStyle(color: c.textSecondary),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final preference in _prefs!)
                          _PreferenceTile(
                            preference: preference,
                            colors: c,
                            onPersist: () {
                              _persist(preference);
                              setState(() {});
                            },
                          ),
                      ],
                    ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  final SourcePreference preference;
  final KomaColors colors;
  final VoidCallback onPersist;

  const _PreferenceTile({
    required this.preference,
    required this.colors,
    required this.onPersist,
  });

  TextStyle get _subtitleStyle => TextStyle(
        fontSize: 11,
        color: colors.textSecondary,
      );

  @override
  Widget build(BuildContext context) {
    if (preference.editTextPreference != null) {
      final pref = preference.editTextPreference!;
      return ListTile(
        title: Text(
          pref.title ?? '',
          style: TextStyle(color: colors.textPrimary),
        ),
        subtitle: Text(pref.summary ?? '', style: _subtitleStyle),
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => _EditTextDialog(
              text: pref.value ?? '',
              dialogTitle: pref.dialogTitle ?? pref.title ?? '',
              dialogMessage: pref.dialogMessage ?? '',
              colors: colors,
              onChanged: (value) {
                pref.value = value;
                onPersist();
              },
            ),
          );
        },
      );
    }

    if (preference.checkBoxPreference != null) {
      final pref = preference.checkBoxPreference!;
      return CheckboxListTile(
        title: Text(
          pref.title ?? '',
          style: TextStyle(color: colors.textPrimary),
        ),
        subtitle: Text(pref.summary ?? '', style: _subtitleStyle),
        value: pref.value ?? false,
        activeColor: colors.accent,
        onChanged: (value) {
          pref.value = value;
          onPersist();
        },
        controlAffinity: ListTileControlAffinity.trailing,
      );
    }

    if (preference.switchPreferenceCompat != null) {
      final pref = preference.switchPreferenceCompat!;
      return SwitchListTile(
        title: Text(
          pref.title ?? '',
          style: TextStyle(color: colors.textPrimary),
        ),
        subtitle: Text(pref.summary ?? '', style: _subtitleStyle),
        value: pref.value ?? false,
        activeThumbColor: colors.accent,
        onChanged: (value) {
          pref.value = value;
          onPersist();
        },
        controlAffinity: ListTileControlAffinity.trailing,
      );
    }

    if (preference.listPreference != null) {
      final pref = preference.listPreference!;
      final entries = pref.entries ?? const <String>[];
      final idx = (pref.valueIndex ?? 0).clamp(
        0,
        entries.isEmpty ? 0 : entries.length - 1,
      );
      final subtitle = entries.isEmpty ? (pref.summary ?? '') : entries[idx];
      return ListTile(
        title: Text(
          pref.title ?? '',
          style: TextStyle(color: colors.textPrimary),
        ),
        subtitle: Text(subtitle, style: _subtitleStyle),
        onTap: () async {
          if (entries.isEmpty) return;
          final res = await showDialog<int>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: colors.bgElevated,
              title: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: pref.title ?? '',
                      style: TextStyle(color: colors.textPrimary),
                    ),
                    if (pref.summary?.isNotEmpty ?? false)
                      TextSpan(
                        text: '\n\n${pref.summary!}',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              content: SizedBox(
                width: MediaQuery.sizeOf(context).width * 0.8,
                child: RadioGroup<int>(
                  groupValue: pref.valueIndex,
                  onChanged: (value) => Navigator.pop(context, value),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      return RadioListTile<int>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: index,
                        activeColor: colors.accent,
                        title: Text(
                          entries[index],
                          style: TextStyle(color: colors.textPrimary),
                        ),
                      );
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: colors.accent)),
                ),
              ],
            ),
          );
          if (res != null) {
            pref.valueIndex = res;
            onPersist();
          }
        },
      );
    }

    if (preference.multiSelectListPreference != null) {
      final pref = preference.multiSelectListPreference!;
      return ListTile(
        title: Text(
          pref.title ?? '',
          style: TextStyle(color: colors.textPrimary),
        ),
        subtitle: Text(pref.summary ?? '', style: _subtitleStyle),
        onTap: () {
          final entries = pref.entries ?? const <String>[];
          final entryValues = pref.entryValues ?? const <String>[];
          final indexList = List<String>.from(pref.values ?? const []);
          showDialog(
            context: context,
            builder: (context) {
              return StatefulBuilder(
                builder: (context, setDialogState) {
                  return AlertDialog(
                    backgroundColor: colors.bgElevated,
                    title: Text(
                      pref.title ?? '',
                      style: TextStyle(color: colors.textPrimary),
                    ),
                    content: SizedBox(
                      width: MediaQuery.sizeOf(context).width * 0.8,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entryValue = index < entryValues.length
                              ? entryValues[index]
                              : entries[index];
                          final selected = indexList.contains(entryValue);
                          return CheckboxListTile(
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: selected,
                            activeColor: colors.accent,
                            title: Text(
                              entries[index],
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            onChanged: (_) {
                              setDialogState(() {
                                if (selected) {
                                  indexList.remove(entryValue);
                                } else {
                                  indexList.add(entryValue);
                                }
                                pref.values = List<String>.from(indexList);
                              });
                              onPersist();
                            },
                          );
                        },
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: colors.accent),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'OK',
                          style: TextStyle(color: colors.accent),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      );
    }

    return const SizedBox.shrink();
  }
}

class _EditTextDialog extends StatefulWidget {
  final String text;
  final String dialogTitle;
  final String dialogMessage;
  final KomaColors colors;
  final ValueChanged<String> onChanged;

  const _EditTextDialog({
    required this.text,
    required this.dialogTitle,
    required this.dialogMessage,
    required this.colors,
    required this.onChanged,
  });

  @override
  State<_EditTextDialog> createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<_EditTextDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return AlertDialog(
      backgroundColor: c.bgElevated,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.dialogTitle, style: TextStyle(color: c.textPrimary)),
          if (widget.dialogMessage.isNotEmpty)
            Text(
              widget.dialogMessage,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
        ],
      ),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(
          controller: _controller,
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: c.accent),
            ),
            border: const OutlineInputBorder(borderSide: BorderSide()),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: c.accent)),
        ),
        TextButton(
          onPressed: () {
            widget.onChanged(_controller.text);
            Navigator.pop(context);
          },
          child: Text('OK', style: TextStyle(color: c.accent)),
        ),
      ],
    );
  }
}

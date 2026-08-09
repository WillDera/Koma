import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/extension_source.dart';
import '../../core/providers.dart';
import '../../theme/app_theme.dart';

/// View/edit the installed JS or Dart [ExtensionSource.sourceCode].
class ExtensionCodeEditorScreen extends ConsumerStatefulWidget {
  const ExtensionCodeEditorScreen({super.key, required this.source});

  final ExtensionSource source;

  @override
  ConsumerState<ExtensionCodeEditorScreen> createState() =>
      _ExtensionCodeEditorScreenState();
}

class _ExtensionCodeEditorScreenState
    extends ConsumerState<ExtensionCodeEditorScreen> {
  late final TextEditingController _ctrl;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.source.sourceCode);
    _ctrl.addListener(() {
      final dirty = _ctrl.text != widget.source.sourceCode;
      if (dirty != _dirty) setState(() => _dirty = dirty);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final updated = widget.source.copyWith(
        sourceCode: _ctrl.text,
        updatedAt: DateTime.now(),
      );
      await ref
          .read(repositoriesProvider)
          .extensions
          .insertExtensionSource(updated);
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Extension code saved')),
      );
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lang = widget.source.isJs ? 'JavaScript' : 'Dart';
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        title: Text(
          'Edit $lang',
          style: TextStyle(color: c.textPrimary),
        ),
        iconTheme: IconThemeData(color: c.textPrimary),
        actions: [
          TextButton(
            onPressed: _dirty && !_saving ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: _dirty ? c.accent : c.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              widget.source.name,
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(
                  color: c.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.35,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: c.surface,
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
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

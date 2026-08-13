import 'package:flutter/material.dart';
import '../core/models/snippet.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_colors.dart';
import '../theme/tokens/app_spacing.dart';
import '../theme/tokens/app_type.dart';
import 'dialog_sheet.dart';
import 'highlight_color_picker.dart';
import 'icon_button_round.dart';
import 'premium_button.dart';
import 'tag_pill.dart';
import 'text_field.dart';

class SnippetDetailSheet extends StatefulWidget {
  final Snippet? snippet;
  final String? defaultSourceTitle;
  final String? defaultSourceUrl;
  final ValueChanged<Snippet> onSave;
  final ValueChanged<int>? onDelete;
  final bool creating;

  const SnippetDetailSheet({
    super.key,
    required this.snippet,
    required this.onSave,
    this.onDelete,
    this.defaultSourceTitle,
    this.defaultSourceUrl,
    this.creating = false,
  });

  static Future<Snippet?> show(
    BuildContext context, {
    Snippet? snippet,
    bool creating = false,
    String? defaultSourceTitle,
    String? defaultSourceUrl,
    required ValueChanged<Snippet> onSave,
    ValueChanged<int>? onDelete,
  }) {
    return StashSheet.show<Snippet>(
      context,
      title: creating ? 'New snippet' : 'Edit snippet',
      subtitle: creating ? 'Capture a thought' : 'Refine your note',
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      child: SnippetDetailSheet(
        snippet: snippet,
        creating: creating,
        defaultSourceTitle: defaultSourceTitle,
        defaultSourceUrl: defaultSourceUrl,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<SnippetDetailSheet> createState() => _SnippetDetailSheetState();
}

class _SnippetDetailSheetState extends State<SnippetDetailSheet> {
  late TextEditingController _textCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _sourceCtrl;
  late TextEditingController _tagCtrl;
  late String _color;
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.snippet?.text ?? '');
    _noteCtrl = TextEditingController(text: widget.snippet?.note ?? '');
    _sourceCtrl = TextEditingController(
      text: widget.snippet?.sourceTitle ?? widget.defaultSourceTitle ?? '',
    );
    _tagCtrl = TextEditingController();
    _color = widget.snippet?.color ?? 'yellow';
    _tags = List.from(widget.snippet?.tags ?? const []);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _noteCtrl.dispose();
    _sourceCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final t = tag.trim();
    if (t.isEmpty || _tags.contains(t)) {
      _tagCtrl.clear();
      return;
    }
    setState(() {
      _tags.add(t);
      _tagCtrl.clear();
    });
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  void _save() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Snippet cannot be empty')));
      return;
    }
    final snippet =
        (widget.snippet ??
                Snippet(id: 0, text: text, createdAt: DateTime.now()))
            .copyWith(
              text: text,
              note: _noteCtrl.text.trim().isNotEmpty
                  ? _noteCtrl.text.trim()
                  : null,
              sourceTitle: _sourceCtrl.text.trim().isNotEmpty
                  ? _sourceCtrl.text.trim()
                  : null,
              color: _color,
              tags: _tags,
            );
    Navigator.pop(context, snippet);
    widget.onSave(snippet);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brightness = Theme.of(context).brightness;
    final isSepia = c.bg == AppColors.sepiaBg;
    final highlight = AppColors.highlight(_color, brightness, isSepia: isSepia);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // Highlight color row
        Row(
          children: [
            Text(
              'Highlight',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const Spacer(),
            HighlightColorPicker(
              colors: HighlightColorPicker.palette,
              selected: _color,
              onChanged: (c) => setState(() => _color = c),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Text
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: highlight.withValues(alpha: 0.10),
            borderRadius: AppSpacing.brLg,
            border: Border.all(
              color: highlight.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: TextField(
            controller: _textCtrl,
            maxLines: 6,
            minLines: 3,
            style: AppType.reading(
              fontSize: 15,
              lineHeight: 1.5,
              color: c.textPrimary,
            ).copyWith(fontStyle: FontStyle.italic),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              hintText: 'The quote or idea…',
              hintStyle: AppType.readingItalic(
                fontSize: 15,
                color: c.textTertiary,
              ),
              contentPadding: EdgeInsets.zero,
              isCollapsed: true,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Note
        Text(
          'Your note',
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _noteCtrl,
          maxLines: 4,
          minLines: 2,
          decoration: const InputDecoration(
            hintText: 'Add your thoughts, connections, or context…',
          ),
        ),
        const SizedBox(height: 20),
        // Source
        Text(
          'Source',
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        StashTextField(
          controller: _sourceCtrl,
          hint: 'Book or article title',
          leadingIcon: Icons.book_outlined,
        ),
        const SizedBox(height: 20),
        // Tags
        Text(
          'Tags',
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        StashTextField(
          controller: _tagCtrl,
          hint: 'Add a tag and press enter',
          leadingIcon: Icons.tag,
          textInputAction: TextInputAction.done,
          onSubmitted: _addTag,
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _tags
                .map(
                  (t) => TagPill(
                    label: t,
                    variant: TagPillVariant.removable,
                    onRemove: () => _removeTag(t),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 28),
        // Actions
        Row(
          children: [
            if (widget.onDelete != null && widget.snippet != null) ...[
              IconButtonRound(
                icon: Icons.delete_outline,
                size: 44,
                variant: IconButtonVariant.filled,
                backgroundColor: const Color(0xFFFAE3E3),
                iconColor: const Color(0xFFC44C4C),
                onPressed: () async {
                  final confirmed = await StashDialog.show<bool>(
                    context,
                    title: 'Delete snippet?',
                    content: 'This cannot be undone.',
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: c.textSecondary),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Color(0xFFC44C4C)),
                        ),
                      ),
                    ],
                  );
                  if (confirmed == true && context.mounted) {
                    Navigator.pop(context);
                    widget.onDelete?.call(widget.snippet!.id);
                  }
                },
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: PremiumButton(
                label: widget.creating ? 'Save snippet' : 'Update',
                leading: const Icon(Icons.check),
                expand: true,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

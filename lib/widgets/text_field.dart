import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';

/// A refined text field with optional leading/trailing icons, a clear
/// button, and a pill-shaped surface. Used for search, URL import,
/// snippet source/tag, etc.
class StashTextField extends StatefulWidget {
  final String? hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;
  final TextInputType? keyboardType;
  final bool autofocus;
  final IconData? leadingIcon;
  final bool showClearButton;
  final bool enabled;
  final String? label;
  final int? maxLines;
  final int? minLines;
  final bool obscureText;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  const StashTextField({
    super.key,
    this.hint,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.done,
    this.keyboardType,
    this.autofocus = false,
    this.leadingIcon,
    this.showClearButton = false,
    this.enabled = true,
    this.label,
    this.maxLines = 1,
    this.minLines,
    this.obscureText = false,
    this.trailing,
    this.padding,
  });

  @override
  State<StashTextField> createState() => _StashTextFieldState();
}

class _StashTextFieldState extends State<StashTextField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  bool _hasText = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.controller ?? TextEditingController();
    _focus = widget.focusNode ?? FocusNode();
    _hasText = _ctrl.text.isNotEmpty;
    _focus.addListener(_onFocusChange);
    _ctrl.addListener(_onTextChange);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _ctrl.removeListener(_onTextChange);
    if (widget.controller == null) _ctrl.dispose();
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = _focus.hasFocus);
  }

  void _onTextChange() {
    final has = _ctrl.text.isNotEmpty;
    if (has != _hasText && mounted) setState(() => _hasText = has);
  }

  void _clear() {
    _ctrl.clear();
    widget.onChanged?.call('');
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: AppSpacing.brPill,
        border: Border.all(
          color: _focused
              ? c.accent.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          if (widget.leadingIcon != null) ...[
            const SizedBox(width: 10),
            Icon(widget.leadingIcon, size: 18, color: c.textTertiary),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              textInputAction: widget.textInputAction,
              keyboardType: widget.keyboardType,
              autofocus: widget.autofocus,
              enabled: widget.enabled,
              maxLines: widget.maxLines,
              minLines: widget.minLines,
              obscureText: widget.obscureText,
              cursorColor: c.accent,
              cursorWidth: 1.5,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: widget.hint,
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                isDense: true,
                hintStyle: TextStyle(
                  color: c.textTertiary,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          if (widget.showClearButton && _hasText)
            AnimatedPress(
              scaleDown: 0.85,
              duration: const Duration(milliseconds: 120),
              onTap: _clear,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.close, size: 16, color: c.textSecondary),
              ),
            ),
          if (widget.trailing != null) ...[
            const SizedBox(width: 4),
            widget.trailing!,
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

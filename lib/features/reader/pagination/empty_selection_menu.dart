import 'package:flutter/material.dart';

/// Suppresses the platform text-selection context menu (Copy / Select all /
/// Share, etc.) while leaving selection handles and the custom reader toolbar
/// intact.
Widget emptyTextSelectionContextMenu(
  BuildContext context,
  EditableTextState editableTextState,
) {
  return const SizedBox.shrink();
}

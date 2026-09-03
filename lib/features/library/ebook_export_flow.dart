import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/models/book.dart';
import '../../core/services/android_storage_access.dart';
import '../../core/services/ebook_export_service.dart';
import '../../widgets/toast.dart';

/// Picks a folder and copies [books] that have local ebook files into it.
///
/// Returns the result, or null if the user cancelled / denied access.
Future<EbookExportResult?> exportEbooksToPickedFolder(
  BuildContext context, {
  required List<Book> books,
}) async {
  final exportable = books
      .where((b) => b.filePath?.trim().isNotEmpty == true)
      .toList(growable: false);
  if (exportable.isEmpty) {
    StashToast.show(
      context,
      message: 'None of the selected books have a local ebook file',
      icon: Icons.info_outline,
    );
    return null;
  }

  if (!await _ensureExportStorageAccess(context)) return null;
  if (!context.mounted) return null;

  final picked = await FilePicker.getDirectoryPath(
    dialogTitle: exportable.length == 1
        ? 'Export ebook to folder'
        : 'Export ${exportable.length} ebooks to folder',
  );
  if (picked == null || !context.mounted) return null;

  if (AndroidStorageAccess.needsAllFilesAccess(picked) &&
      !await AndroidStorageAccess.hasAllFilesAccess()) {
    if (context.mounted) {
      StashToast.show(
        context,
        message:
            'Android blocked this folder. Grant All files access, then try again.',
        icon: Icons.error_outline,
      );
    }
    return null;
  }

  if (!context.mounted) return null;
  StashToast.show(
    context,
    message: exportable.length == 1
        ? 'Exporting ebook…'
        : 'Exporting ${exportable.length} ebooks…',
  );

  final result = await EbookExportService.exportToDirectory(
    books: exportable,
    destinationDir: picked,
  );

  if (!context.mounted) return result;

  if (result.exported == 0) {
    StashToast.show(
      context,
      message: result.failed > 0
          ? 'Export failed'
          : 'No ebook files could be exported',
      icon: Icons.error_outline,
    );
  } else if (result.failed > 0 || result.skipped > 0) {
    StashToast.show(
      context,
      message:
          'Exported ${result.exported}'
          '${result.skipped > 0 ? ', skipped ${result.skipped}' : ''}'
          '${result.failed > 0 ? ', failed ${result.failed}' : ''}',
      icon: Icons.check_circle_outline,
    );
  } else {
    StashToast.show(
      context,
      message: result.exported == 1
          ? 'Ebook exported'
          : 'Exported ${result.exported} ebooks',
      icon: Icons.check_circle_outline,
    );
  }
  return result;
}

Future<bool> _ensureExportStorageAccess(BuildContext context) async {
  if (!AndroidStorageAccess.needsAllFilesAccess('/storage/emulated/0')) {
    return true;
  }
  if (await AndroidStorageAccess.hasAllFilesAccess()) return true;
  if (!context.mounted) return false;

  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('All files access'),
      content: const Text(
        'Android needs All files access before Koma can copy ebooks into a '
        'shared folder.\n\n'
        'Open the next screen, enable access for Koma, then come back and '
        'choose the folder again.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Grant access'),
        ),
      ],
    ),
  );
  if (go != true) return false;
  await AndroidStorageAccess.requestAllFilesAccess();
  // User must return from Settings and tap Export again.
  return false;
}

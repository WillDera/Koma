import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/models/manga.dart';
import '../../core/models/manga_chapter.dart';
import '../../core/services/android_storage_access.dart';
import '../../core/services/cbz_export_service.dart';
import '../../core/services/keiyoushi_service.dart';
import '../../widgets/toast.dart';

/// Picks a folder and exports downloaded [chapters] as CBZ archives.
Future<CbzExportResult?> exportMangaChaptersAsCbz(
  BuildContext context, {
  required Manga manga,
  required List<MangaChapter> chapters,
  KeiyoushiService? keiyoushi,
  Future<String> Function(String sourceId)? resolveSourceId,
}) async {
  final exportable = chapters
      .where((c) => c.isDownloaded || c.url.trim().isNotEmpty)
      .toList(growable: false);
  if (exportable.isEmpty) {
    StashToast.show(
      context,
      message: 'No downloaded chapters to export',
      icon: Icons.info_outline,
    );
    return null;
  }

  if (!await _ensureExportStorageAccess(context)) return null;
  if (!context.mounted) return null;

  final picked = await FilePicker.getDirectoryPath(
    dialogTitle: exportable.length == 1
        ? 'Export chapter as CBZ'
        : 'Export ${exportable.length} chapters as CBZ',
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
        ? 'Exporting CBZ…'
        : 'Exporting ${exportable.length} CBZ files…',
  );

  final result = await CbzExportService.exportChapters(
    manga: manga,
    chapters: exportable,
    destinationDir: picked,
    keiyoushi: keiyoushi,
    resolveSourceId: resolveSourceId,
  );

  if (!context.mounted) return result;

  if (result.exported == 0) {
    StashToast.show(
      context,
      message: result.failed > 0
          ? 'CBZ export failed'
          : 'No page files found on disk for those chapters',
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
          ? 'Exported CBZ'
          : 'Exported ${result.exported} CBZ files',
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
        'Android needs All files access before Koma can write CBZ files into a '
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
  return false;
}

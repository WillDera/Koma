import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'database_service.dart';

class ExportService {
  final DatabaseService _db;

  ExportService(this._db);

  Future<String> exportToJson() async {
    final json = await _db.exportToJson();
    final bytes = utf8.encode(json);

    // file_picker 11.x: bytes is required on Android & iOS so the
    // platform can write the file through Storage Access Framework /
    // UIDocumentPickerViewController without us having to hold a
    // file path. On other platforms (web/desktop) it's optional.
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-')
        .split('T')
        .join('_')
        .substring(0, 19);
    final result = await FilePicker.saveFile(
      dialogTitle: 'Save backup',
      fileName: 'stashreader_backup_$ts.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );

    if (result == null) {
      return 'Export cancelled';
    }

    // On platforms where saveFile returned a path (web/desktop),
    // write the bytes to that path.
    if (Platform.isAndroid || Platform.isIOS) {
      // On mobile, file_picker has already written the bytes via
      // SAF / UIDocumentPickerViewController. The returned string is
      // the URI the user picked.
      return 'Backup saved';
    }
    final file = File(result);
    if (!await file.exists() || await file.length() == 0) {
      await file.writeAsBytes(bytes);
    }
    return 'Backup saved';
  }

  Future<String> importFromJson() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select backup file',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) {
      return 'Import cancelled';
    }
    final picked = result.files.single;
    String json;
    if (picked.bytes != null) {
      json = utf8.decode(picked.bytes!);
    } else if (picked.path != null) {
      json = await File(picked.path!).readAsString();
    } else {
      return 'Import failed: empty file';
    }
    final importResult = await _db.importFromJson(json);
    return importResult.toString();
  }
}

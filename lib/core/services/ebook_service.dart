import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_storage.dart';
import 'epub_service.dart';
import 'fb2_service.dart';
import 'txt_service.dart';
import 'mobi_service.dart';
import 'pdf_service.dart';

class EbookService {
  Future<EpubResult?> parse(String filePath, {int? bookId}) async {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'epub':
        return EpubService().parseEpub(filePath, bookId: bookId);
      case 'pdf':
        return PdfService().parse(filePath, bookId: bookId);
      case 'fb2':
        return Fb2Service().parse(filePath, bookId: bookId);
      case 'txt':
        return TxtService().parse(filePath, bookId: bookId);
      case 'mobi':
      case 'azw':
      case 'azw3':
      case 'kf8':
        return MobiService().parse(filePath, bookId: bookId);
      default:
        return null;
    }
  }

  /// Copies a picker / share path into `{documents}/downloads/` so the library
  /// keeps a durable file (Android cache paths and storage moves are unreliable).
  ///
  /// Returns [sourcePath] unchanged when it already lives under downloads.
  Future<String> persistImportCopy(String sourcePath) async {
    final docs = await AppStorage.documents();
    final downloads = Directory(p.join(docs.path, 'downloads'));
    final normalized = p.normalize(File(sourcePath).absolute.path);
    final downloadsRoot = p.normalize(downloads.absolute.path);
    if (normalized == downloadsRoot ||
        p.isWithin(downloadsRoot, normalized)) {
      return normalized;
    }

    await downloads.create(recursive: true);
    final ext = p.extension(sourcePath);
    final dest = p.join(
      downloads.path,
      '${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await File(sourcePath).copy(dest);
    return dest;
  }
}

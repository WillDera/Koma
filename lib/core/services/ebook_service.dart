import 'epub_service.dart';
import 'fb2_service.dart';
import 'txt_service.dart';
import 'mobi_service.dart';

class EbookService {
  Future<EpubResult?> parse(String filePath, {int? bookId}) async {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'epub':
        return EpubService().parseEpub(filePath, bookId: bookId);
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
}

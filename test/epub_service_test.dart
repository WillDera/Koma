import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:koma/core/services/epub_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('koma_epub_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('parses nested NCX, rewrites images, strips CSS, extracts cover', () async {
    final epubPath = '${tmp.path}/fixture.epub';
    await File(epubPath).writeAsBytes(_buildFixtureEpub());

    final result = await EpubService().parseEpub(epubPath);

    expect(result, isNotNull);
    expect(result!.book.title, 'Fixture Book');
    expect(result.book.author, 'Ada Lovelace');
    expect(result.book.coverPath, isNotNull);
    expect(File(result.book.coverPath!).existsSync(), isTrue);

    expect(result.chapters.length, greaterThanOrEqualTo(2));
    expect(result.chapters.map((c) => c.title), contains('Chapter One'));
    expect(result.chapters.map((c) => c.title), contains('Section Nested'));

    final ch1 = result.chapters.firstWhere((c) => c.title == 'Chapter One');
    expect(ch1.content.contains('<style'), isFalse);
    expect(ch1.content.contains('@page'), isFalse);
    expect(ch1.content.contains('Hello from chapter one.'), isTrue);
    expect(ch1.content.contains('img.png'), isFalse);
    expect(ch1.content.contains('ebook_media'), isTrue);
  });
}

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.docs);
  final String docs;

  @override
  Future<String?> getApplicationDocumentsPath() async => docs;
}

Uint8List _tinyPng() {
  final image = img.Image(width: 1, height: 1);
  image.setPixelRgb(0, 0, 200, 40, 40);
  return Uint8List.fromList(img.encodePng(image));
}

List<int> _buildFixtureEpub() {
  final png = _tinyPng();
  final archive = Archive();

  void add(String name, List<int> bytes, {bool compress = true}) {
    archive.addFile(
      compress
          ? ArchiveFile(name, bytes.length, bytes)
          : ArchiveFile.noCompress(name, bytes.length, bytes),
    );
  }

  add('mimetype', 'application/epub+zip'.codeUnits, compress: false);
  add(
    'META-INF/container.xml',
    '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf"
      media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
'''.codeUnits,
  );
  add(
    'OEBPS/content.opf',
    '''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"
            xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title>Fixture Book</dc:title>
    <dc:creator opf:role="aut">Ada Lovelace</dc:creator>
    <dc:language>en</dc:language>
    <dc:identifier id="BookId">urn:uuid:koma-epub-fixture</dc:identifier>
    <meta name="cover" content="cover-image"/>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="ch2.xhtml" media-type="application/xhtml+xml"/>
    <item id="cover-image" href="cover.png" media-type="image/png"/>
    <item id="inline-img" href="img.png" media-type="image/png"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
  </spine>
</package>
'''.codeUnits,
  );
  add(
    'OEBPS/toc.ncx',
    '''<?xml version="1.0"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="urn:uuid:koma-epub-fixture"/>
  </head>
  <docTitle><text>Fixture Book</text></docTitle>
  <navMap>
    <navPoint id="nav1" playOrder="1">
      <navLabel><text>Chapter One</text></navLabel>
      <content src="ch1.xhtml"/>
      <navPoint id="nav1a" playOrder="2">
        <navLabel><text>Section Nested</text></navLabel>
        <content src="ch2.xhtml"/>
      </navPoint>
    </navPoint>
  </navMap>
</ncx>
'''.codeUnits,
  );
  add(
    'OEBPS/ch1.xhtml',
    '''<?xml version="1.0"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <title>Chapter One</title>
  <style type="text/css">p { color: red; }</style>
</head>
<body>
  <p>Hello from chapter one.</p>
  <img src="img.png" alt="inline"/>
  <style>body { background: blue; }</style>
  @page { margin: 2em; }
</body>
</html>
'''.codeUnits,
  );
  add(
    'OEBPS/ch2.xhtml',
    '''<?xml version="1.0"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Section Nested</title></head>
<body><p>Nested section body.</p></body>
</html>
'''.codeUnits,
  );
  add('OEBPS/cover.png', png);
  add('OEBPS/img.png', png);

  return ZipEncoder().encode(archive);
}

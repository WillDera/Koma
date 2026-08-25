import 'dart:typed_data';

// kindle_unpack only exposes EPUB packaging via the barrel, which pulls in
// archive-3 APIs. Parse pipeline lives under src/.
// ignore_for_file: implementation_imports

import 'package:kindle_unpack/src/decompress/book_text.dart';
import 'package:kindle_unpack/src/headers/header_exception.dart';
import 'package:kindle_unpack/src/images.dart';
import 'package:kindle_unpack/src/kf8/boundary.dart';
import 'package:kindle_unpack/src/kf8/fdst.dart';
import 'package:kindle_unpack/src/kf8/flows.dart';
import 'package:kindle_unpack/src/kf8/skeleton_fragment.dart';
import 'package:kindle_unpack/src/kf8/xhtml_split.dart';
import 'package:kindle_unpack/src/pdb.dart';

/// [KindleBook.fromBytes] without importing `kindle_unpack`'s EPUB packager.
///
/// `kindle_unpack` 0.1.1 still uses archive 3's `ArchiveFile.compress` setter,
/// which archive 4 (required by epub_pro) removed. Koma never calls `toEpub()`,
/// so this adapter runs the same parse pipeline and skips that file.
class KindleBookAdapter {
  KindleBookAdapter._({
    required this.pdb,
    required this.section,
    required this.rawML,
    required this.parts,
    required this.images,
  });

  factory KindleBookAdapter.fromBytes(Uint8List bytes) {
    final pdb = PdbFile.parse(bytes);
    final kf = KindleFile.inspect(pdb);
    final section = kf.kf8 ?? kf.mobi7!;
    final rawML = decompressBookText(
      pdb: pdb,
      palmDoc: section.palmDoc,
      mobi: section.mobi,
    );

    BookFlows? flows;
    List<XhtmlPart> parts;
    if (kf.kf8 != null) {
      final fdstRecIdx = section.mobi.fdstRecord! + section.recordOffset;
      final fdst = FdstTable.parse(pdb.records[fdstRecIdx].data);
      flows = BookFlows.split(rawML, fdst);
      try {
        final skel = SkeletonTable.parse(pdb, section.mobi);
        final frag = FragmentTable.parse(pdb, section.mobi);
        parts = XhtmlSplitter.split(
          primaryFlow: flows.primaryHtml!.bytes,
          skeletons: skel,
          fragments: frag,
        );
      } on HeaderException {
        parts = [
          XhtmlPart(fileNumber: 0, bytes: flows.primaryHtml!.bytes),
        ];
      }
    } else {
      parts = [XhtmlPart(fileNumber: 0, bytes: rawML)];
    }

    final images = BookImages.extract(
      pdb: pdb,
      mobi: section.mobi,
      exth: section.exth,
    );

    return KindleBookAdapter._(
      pdb: pdb,
      section: section,
      rawML: rawML,
      parts: parts,
      images: images,
    );
  }

  final PdbFile pdb;
  final KindleSection section;
  final Uint8List rawML;
  final List<XhtmlPart> parts;
  final BookImages images;

  String get title =>
      section.exth?.title ??
      section.mobi.fullName(pdb.records[section.recordOffset].data);
}

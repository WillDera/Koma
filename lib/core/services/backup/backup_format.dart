import 'dart:convert';
import 'dart:typed_data';

enum BackupKind { komaJson, mihon, mangayomi, unknown }

class BackupSniff {
  final BackupKind kind;
  const BackupSniff(this.kind);

  bool get isKnown => kind != BackupKind.unknown;
}

/// Detect backup format from magic bytes, then filename.
BackupSniff sniffBackup(List<int> bytes, {String? filename}) {
  if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
    return const BackupSniff(BackupKind.mihon);
  }
  if (bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4b &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04) {
    return const BackupSniff(BackupKind.mangayomi);
  }
  final name = filename?.toLowerCase() ?? '';
  if (name.endsWith('.tachibk') || name.endsWith('.proto.gz')) {
    return const BackupSniff(BackupKind.mihon);
  }
  if (name.endsWith('.backup') || name.contains('mangayomi')) {
    return const BackupSniff(BackupKind.mangayomi);
  }
  if (bytes.isNotEmpty && bytes[0] == 0x7b) {
    try {
      final text = utf8.decode(bytes);
      final data = jsonDecode(text);
      if (data is Map && data.containsKey('version')) {
        final v = data['version'];
        if (v is int || (v is String && int.tryParse(v) != null)) {
          return const BackupSniff(BackupKind.komaJson);
        }
        if (v == '1' || v == '2') {
          return const BackupSniff(BackupKind.mangayomi);
        }
      }
    } catch (_) {}
    return const BackupSniff(BackupKind.komaJson);
  }
  // Raw protobuf (ungzipped Mihon).
  if (bytes.isNotEmpty && !name.endsWith('.json')) {
    if (name.endsWith('.tachibk') || name.contains('mihon')) {
      return const BackupSniff(BackupKind.mihon);
    }
  }
  return const BackupSniff(BackupKind.unknown);
}

Uint8List asUint8List(List<int> bytes) =>
    bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

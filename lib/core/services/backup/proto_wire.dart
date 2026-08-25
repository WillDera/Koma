import 'dart:convert';
import 'dart:typed_data';

/// Minimal protobuf wire reader/writer (proto2/proto3 compatible).
///
/// kotlinx.serialization protobuf uses the same tags. Unknown fields are
/// skipped so fork extras do not break decode.
class ProtoReader {
  ProtoReader(this._buf);
  final List<int> _buf;
  int _pos = 0;

  bool get isDone => _pos >= _buf.length;

  int get remaining => _buf.length - _pos;

  int readVarint() {
    var result = 0;
    var shift = 0;
    while (_pos < _buf.length) {
      final byte = _buf[_pos++];
      result |= (byte & 0x7f) << shift;
      if ((byte & 0x80) == 0) return result;
      shift += 7;
      if (shift > 63) {
        throw const FormatException('Varint too long');
      }
    }
    throw const FormatException('Truncated varint');
  }

  (int field, int wire) readTag() {
    final tag = readVarint();
    return (tag >> 3, tag & 7);
  }

  void skip(int wire) {
    switch (wire) {
      case 0:
        readVarint();
      case 1:
        _pos += 8;
      case 2:
        final len = readVarint();
        _pos += len;
      case 5:
        _pos += 4;
      default:
        throw FormatException('Unknown wire type $wire');
    }
    if (_pos > _buf.length) {
      throw const FormatException('Truncated protobuf');
    }
  }

  List<int> readBytes() {
    final len = readVarint();
    if (_pos + len > _buf.length) {
      throw const FormatException('Truncated bytes');
    }
    final slice = _buf.sublist(_pos, _pos + len);
    _pos += len;
    return slice;
  }

  String readString() => utf8.decode(readBytes());

  double readFloat() {
    if (_pos + 4 > _buf.length) {
      throw const FormatException('Truncated float');
    }
    final buf = _buf;
    final bytes = buf is Uint8List ? buf : Uint8List.fromList(buf);
    final data = ByteData.sublistView(bytes, _pos, _pos + 4);
    _pos += 4;
    return data.getFloat32(0, Endian.little);
  }

  /// Packed repeated varints (wire type 2) or a single varint.
  List<int> readPackedVarints(int wire) {
    if (wire == 0) return [readVarint()];
    if (wire != 2) {
      skip(wire);
      return const [];
    }
    final inner = readBytes();
    final r = ProtoReader(inner);
    final out = <int>[];
    while (!r.isDone) {
      out.add(r.readVarint());
    }
    return out;
  }
}

class ProtoWriter {
  final BytesBuilder _out = BytesBuilder(copy: false);

  Uint8List toBytes() => _out.takeBytes();

  void writeTag(int field, int wire) => writeVarint((field << 3) | wire);

  void writeVarint(int value) {
    var v = value;
    // Dart ints are signed; protobuf varints are unsigned 64-bit.
    if (v < 0) {
      writeVarint64(v);
      return;
    }
    while (v > 0x7f) {
      _out.addByte((v & 0x7f) | 0x80);
      v >>= 7;
    }
    _out.addByte(v);
  }

  void writeVarint64(int value) {
    var n = BigInt.from(value).toUnsigned(64);
    while (n > BigInt.from(0x7f)) {
      _out.addByte((n.toInt() & 0x7f) | 0x80);
      n >>= 7;
    }
    _out.addByte(n.toInt());
  }

  void writeBytes(int field, List<int> bytes) {
    writeTag(field, 2);
    writeVarint(bytes.length);
    _out.add(bytes);
  }

  void writeString(int field, String value) {
    if (value.isEmpty) return;
    writeBytes(field, utf8.encode(value));
  }

  void writeInt(int field, int value) {
    if (value == 0) return;
    writeTag(field, 0);
    writeVarint(value);
  }

  void writeBool(int field, bool value, {bool omitFalse = true}) {
    if (omitFalse && !value) return;
    writeTag(field, 0);
    writeVarint(value ? 1 : 0);
  }

  void writeFloat(int field, double value) {
    if (value == 0) return;
    writeTag(field, 5);
    final data = ByteData(4)..setFloat32(0, value, Endian.little);
    _out.add(data.buffer.asUint8List());
  }

  void writeMessage(int field, List<int> bytes) {
    if (bytes.isEmpty) return;
    writeBytes(field, bytes);
  }
}

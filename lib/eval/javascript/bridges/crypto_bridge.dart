import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_qjs/flutter_qjs.dart';
import '../../../utils/js_unpacker.dart';

const cryptoBridgeCode = '''
var __cryptoCallbacks = {};
var __cryptoCallbackId = 0;

globalThis.CryptoJS = globalThis.CryptoJS || {};
globalThis.CryptoJS.enc = globalThis.CryptoJS.enc || {};
globalThis.CryptoJS.enc.Utf8 = {
  parse: function(str) {
    return { words: CryptoJS.enc.Utf8.parseString(str), sigBytes: str.length * 4 };
  },
  stringify: function(wordArray) {
    return CryptoJS.enc.Utf8.stringifyWords(wordArray);
  }
};

CryptoJS.enc.Utf8.parseString = function(str) {
  var words = [];
  for (var i = 0; i < str.length; i++) {
    words[i] = str.charCodeAt(i);
  }
  return { words: words, sigBytes: str.length * 4 };
};

CryptoJS.enc.Utf8.stringifyWords = function(wordArray) {
  var words = wordArray.words;
  var sigBytes = wordArray.sigBytes;
  var utf8 = [];
  for (var i = 0; i < sigBytes; i++) {
    var byte = (words[i >>> 2] >>> (24 - (i % 4) * 8)) & 0xff;
    utf8.push(String.fromCharCode(byte));
  }
  return utf8.join('');
};

CryptoJS.lib = CryptoJS.lib || {};
CryptoJS.lib.CipherParams = function(params) {
  this.ciphertext = params.ciphertext;
  this.key = params.key;
  this.iv = params.iv;
  this.salt = params.salt;
};

CryptoJS.AES = {
  encrypt: function(message, key) {
    var id = __cryptoCallbackId++;
    return new Promise(function(resolve, reject) {
      __cryptoCallbacks[id] = { resolve: resolve, reject: reject };
      sendMessage('CryptoAESEncrypt', JSON.stringify({
        message: message,
        key: key,
        callbackId: id
      }));
    });
  },
  decrypt: function(ciphertext, key) {
    var id = __cryptoCallbackId++;
    return new Promise(function(resolve, reject) {
      __cryptoCallbacks[id] = { resolve: resolve, reject: reject };
      sendMessage('CryptoAESDecrypt', JSON.stringify({
        ciphertext: ciphertext,
        key: key,
        callbackId: id
      }));
    });
  }
};

function cryptoHandler(text, iv, secretKeyString, encrypt) {
  var id = __cryptoCallbackId++;
  return new Promise(function(resolve, reject) {
    __cryptoCallbacks[id] = { resolve: resolve, reject: reject };
    sendMessage('CryptoHandler', JSON.stringify({
      text: text,
      iv: iv,
      key: secretKeyString,
      encrypt: encrypt,
      callbackId: id
    }));
  });
}

function decryptAESGCM(encrypted, keyHex, ivHex, tagHex) {
  tagHex = tagHex || "";
  var id = __cryptoCallbackId++;
  return new Promise(function(resolve, reject) {
    __cryptoCallbacks[id] = { resolve: resolve, reject: reject };
    sendMessage('DecryptAESGCM', JSON.stringify({
      encrypted: encrypted,
      keyHex: keyHex,
      ivHex: ivHex,
      tagHex: tagHex,
      callbackId: id
    }));
  });
}

function unpackJsAndCombine(scriptBlock) {
  var id = __cryptoCallbackId++;
  return new Promise(function(resolve, reject) {
    __cryptoCallbacks[id] = { resolve: resolve, reject: reject };
    sendMessage('UnpackJsAndCombine', JSON.stringify({
      scriptBlock: scriptBlock,
      callbackId: id
    }));
  });
}
''';

Future<void> injectCryptoBridge(QuickJsRuntime2 engine) async {
  engine.setupBridge('CryptoAESEncrypt', (args) {
    final message = args['message'] as String? ?? '';
    final key = args['key'] as String? ?? '';
    final callbackId = args['callbackId'] as int? ?? 0;
    unawaited(_aesEncrypt(engine, message, key, callbackId));
  });

  engine.setupBridge('CryptoAESDecrypt', (args) {
    final ciphertext = args['ciphertext'] as String? ?? '';
    final key = args['key'] as String? ?? '';
    final callbackId = args['callbackId'] as int? ?? 0;
    unawaited(_aesDecrypt(engine, ciphertext, key, callbackId));
  });

  engine.setupBridge('CryptoHandler', (args) {
    final text = args['text'] as String? ?? '';
    final iv = args['iv'] as String? ?? '';
    final key = args['key'] as String? ?? '';
    final doEncrypt = args['encrypt'] as bool? ?? false;
    final callbackId = args['callbackId'] as int? ?? 0;
    unawaited(_cryptoHandler(engine, text, iv, key, doEncrypt, callbackId));
  });

  engine.setupBridge('DecryptAESGCM', (args) {
    final encrypted = args['encrypted'] as String? ?? '';
    final keyHex = args['keyHex'] as String? ?? '';
    final ivHex = args['ivHex'] as String? ?? '';
    final tagHex = args['tagHex'] as String? ?? '';
    final callbackId = args['callbackId'] as int? ?? 0;
    unawaited(
      _decryptAESGCM(engine, encrypted, keyHex, ivHex, tagHex, callbackId),
    );
  });

  engine.setupBridge('UnpackJsAndCombine', (args) {
    final scriptBlock = args['scriptBlock'] as String? ?? '';
    final callbackId = args['callbackId'] as int? ?? 0;
    _unpackJsAndCombine(engine, scriptBlock, callbackId);
  });

  engine.evaluate(cryptoBridgeCode);
}

Future<void> _aesEncrypt(
  QuickJsRuntime2 engine,
  String message,
  String key,
  int callbackId,
) async {
  try {
    final keyBytes = Uint8List.fromList(utf8.encode(key));
    final messageBytes = Uint8List.fromList(utf8.encode(message));
    final cipher = AesCrypt(keyBytes);
    final encrypted = cipher.encrypt(messageBytes);
    final result = jsonEncode({
      'ciphertext': base64Encode(encrypted),
      'key': key,
    });
    engine.evaluate('__cryptoCallbacks[$callbackId].resolve($result)');
  } catch (e) {
    final errMsg = e.toString().replaceAll('"', '\\"').replaceAll("'", "\\'");
    engine.evaluate('__cryptoCallbacks[$callbackId].reject("$errMsg")');
  }
}

Future<void> _aesDecrypt(
  QuickJsRuntime2 engine,
  String ciphertext,
  String key,
  int callbackId,
) async {
  try {
    final keyBytes = Uint8List.fromList(utf8.encode(key));
    final cipherBytes = Uint8List.fromList(base64Decode(ciphertext));
    final cipher = AesCrypt(keyBytes);
    final decrypted = cipher.decrypt(cipherBytes);
    final result = utf8.decode(decrypted);
    final escaped = result.replaceAll('"', '\\"').replaceAll('\n', '\\n');
    engine.evaluate('__cryptoCallbacks[$callbackId].resolve("$escaped")');
  } catch (e) {
    final errMsg = e.toString().replaceAll('"', '\\"').replaceAll("'", "\\'");
    engine.evaluate('__cryptoCallbacks[$callbackId].reject("$errMsg")');
  }
}

class AesCrypt {
  final Uint8List _key;
  AesCrypt(this._key);

  Uint8List encrypt(Uint8List plaintext) {
    final padded = _pkcs7Pad(plaintext, 16);
    final result = Uint8List(padded.length);
    for (var i = 0; i < padded.length; i += 16) {
      final block = Uint8List.sublistView(padded, i, i + 16);
      final encrypted = _aesEncryptBlock(block);
      result.setRange(i, i + 16, encrypted);
    }
    return result;
  }

  Uint8List decrypt(Uint8List ciphertext) {
    final result = Uint8List(ciphertext.length);
    for (var i = 0; i < ciphertext.length; i += 16) {
      final block = Uint8List.sublistView(ciphertext, i, i + 16);
      final decrypted = _aesDecryptBlock(block);
      result.setRange(i, i + 16, decrypted);
    }
    return _pkcs7Unpad(result);
  }

  Uint8List _aesEncryptBlock(Uint8List block) {
    final state = List<int>.from(block);
    _addRoundKey(state, _key);
    for (var round = 0; round < 10; round++) {
      _subBytes(state);
      _shiftRows(state);
      if (round < 9) {
        _mixColumns(state);
      }
      _addRoundKey(state, _key);
    }
    return Uint8List.fromList(state);
  }

  Uint8List _aesDecryptBlock(Uint8List block) {
    final state = List<int>.from(block);
    _addRoundKey(state, _key);
    for (var round = 0; round < 10; round++) {
      _invShiftRows(state);
      _invSubBytes(state);
      _addRoundKey(state, _key);
      if (round < 9) {
        _invMixColumns(state);
      }
    }
    _invShiftRows(state);
    _invSubBytes(state);
    _addRoundKey(state, _key);
    return Uint8List.fromList(state);
  }

  void _addRoundKey(List<int> state, Uint8List key) {
    for (var i = 0; i < state.length; i++) {
      state[i] ^= key[i % key.length];
    }
  }

  void _subBytes(List<int> state) {
    for (var i = 0; i < state.length; i++) {
      state[i] = _sBox[state[i]];
    }
  }

  void _invSubBytes(List<int> state) {
    for (var i = 0; i < state.length; i++) {
      state[i] = _invSBox[state[i]];
    }
  }

  void _shiftRows(List<int> state) {
    final temp = List<int>.from(state);
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 4; j++) {
        state[i + j * 4] = temp[i + ((j + i) % 4) * 4];
      }
    }
  }

  void _invShiftRows(List<int> state) {
    final temp = List<int>.from(state);
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 4; j++) {
        state[i + j * 4] = temp[i + ((j - i + 4) % 4) * 4];
      }
    }
  }

  void _mixColumns(List<int> state) {
    for (var i = 0; i < 4; i++) {
      final col = [state[i], state[i + 4], state[i + 8], state[i + 12]];
      state[i] = _gmul(col[0], 2) ^ _gmul(col[1], 3) ^ col[2] ^ col[3];
      state[i + 4] = col[0] ^ _gmul(col[1], 2) ^ _gmul(col[2], 3) ^ col[3];
      state[i + 8] = col[0] ^ col[1] ^ _gmul(col[2], 2) ^ _gmul(col[3], 3);
      state[i + 12] = _gmul(col[0], 3) ^ col[1] ^ col[2] ^ _gmul(col[3], 2);
    }
  }

  void _invMixColumns(List<int> state) {
    for (var i = 0; i < 4; i++) {
      final col = [state[i], state[i + 4], state[i + 8], state[i + 12]];
      state[i] =
          _gmul(col[0], 14) ^
          _gmul(col[1], 11) ^
          _gmul(col[2], 13) ^
          _gmul(col[3], 9);
      state[i + 4] =
          _gmul(col[0], 9) ^
          _gmul(col[1], 14) ^
          _gmul(col[2], 11) ^
          _gmul(col[3], 13);
      state[i + 8] =
          _gmul(col[0], 13) ^
          _gmul(col[1], 9) ^
          _gmul(col[2], 14) ^
          _gmul(col[3], 11);
      state[i + 12] =
          _gmul(col[0], 11) ^
          _gmul(col[1], 13) ^
          _gmul(col[2], 9) ^
          _gmul(col[3], 14);
    }
  }

  int _gmul(int a, int b) {
    var p = 0;
    for (var i = 0; i < 8; i++) {
      if (b & 1 != 0) p ^= a;
      final hi = a & 0x80;
      a = (a << 1) & 0xFF;
      if (hi != 0) a ^= 0x1B;
      b >>= 1;
    }
    return p;
  }

  Uint8List _pkcs7Pad(Uint8List data, int blockSize) {
    final padLen = blockSize - (data.length % blockSize);
    final padded = Uint8List(data.length + padLen);
    padded.setRange(0, data.length, data);
    for (var i = data.length; i < padded.length; i++) {
      padded[i] = padLen;
    }
    return padded;
  }

  Uint8List _pkcs7Unpad(Uint8List data) {
    if (data.isEmpty) return data;
    final padLen = data.last;
    if (padLen < 1 || padLen > 16) return data;
    return Uint8List.sublistView(data, 0, data.length - padLen);
  }

  static const _sBox = [
    0x63,
    0x7C,
    0x77,
    0x7B,
    0xF2,
    0x6B,
    0x6F,
    0xC5,
    0x30,
    0x01,
    0x67,
    0x2B,
    0xFE,
    0xD7,
    0xAB,
    0x76,
    0xCA,
    0x82,
    0xC9,
    0x7D,
    0xFA,
    0x59,
    0x47,
    0xF0,
    0xAD,
    0xD4,
    0xA2,
    0xAF,
    0x9C,
    0xA4,
    0x72,
    0xC0,
    0xB7,
    0xFD,
    0x93,
    0x26,
    0x36,
    0x3F,
    0xF7,
    0xCC,
    0x34,
    0xA5,
    0xE5,
    0xF1,
    0x71,
    0xD8,
    0x31,
    0x15,
    0x04,
    0xC7,
    0x23,
    0xC3,
    0x18,
    0x96,
    0x05,
    0x9A,
    0x07,
    0x12,
    0x80,
    0xE2,
    0xEB,
    0x27,
    0xB2,
    0x75,
    0x09,
    0x83,
    0x2C,
    0x1A,
    0x1B,
    0x6E,
    0x5A,
    0xA0,
    0x52,
    0x3B,
    0xD6,
    0xB3,
    0x29,
    0xE3,
    0x2F,
    0x84,
    0x53,
    0xD1,
    0x00,
    0xED,
    0x20,
    0xFC,
    0xB1,
    0x5B,
    0x6A,
    0xCB,
    0xBE,
    0x39,
    0x4A,
    0x4C,
    0x58,
    0xCF,
    0xD0,
    0xEF,
    0xAA,
    0xFB,
    0x43,
    0x4D,
    0x33,
    0x85,
    0x45,
    0xF9,
    0x02,
    0x7F,
    0x50,
    0x3C,
    0x9F,
    0xA8,
    0x51,
    0xA3,
    0x40,
    0x8F,
    0x92,
    0x9D,
    0x38,
    0xF5,
    0xBC,
    0xB6,
    0xDA,
    0x21,
    0x10,
    0xFF,
    0xF3,
    0xD2,
    0xCD,
    0x0C,
    0x13,
    0xEC,
    0x5F,
    0x97,
    0x44,
    0x17,
    0xC4,
    0xA7,
    0x7E,
    0x3D,
    0x64,
    0x5D,
    0x19,
    0x73,
    0x60,
    0x81,
    0x4F,
    0xDC,
    0x22,
    0x2A,
    0x90,
    0x88,
    0x46,
    0xEE,
    0xB8,
    0x14,
    0xDE,
    0x5E,
    0x0B,
    0xDB,
    0xE0,
    0x32,
    0x3A,
    0x0A,
    0x49,
    0x06,
    0x24,
    0x5C,
    0xC2,
    0xD3,
    0xAC,
    0x62,
    0x91,
    0x95,
    0xE4,
    0x79,
    0xE7,
    0xC8,
    0x37,
    0x6D,
    0x8D,
    0xD5,
    0x4E,
    0xA9,
    0x6C,
    0x56,
    0xF4,
    0xEA,
    0x65,
    0x7A,
    0xAE,
    0x08,
    0xBA,
    0x78,
    0x25,
    0x2E,
    0x1C,
    0xA6,
    0xB4,
    0xC6,
    0xE8,
    0xDD,
    0x74,
    0x1F,
    0x4B,
    0xBD,
    0x8B,
    0x8A,
    0x70,
    0x3E,
    0xB5,
    0x66,
    0x48,
    0x03,
    0xF6,
    0x0E,
    0x61,
    0x35,
    0x57,
    0xB9,
    0x86,
    0xC1,
    0x1D,
    0x9E,
    0xE1,
    0xF8,
    0x98,
    0x11,
    0x69,
    0xD9,
    0x8E,
    0x94,
    0x9B,
    0x1E,
    0x87,
    0xE9,
    0xCE,
    0x55,
    0x28,
    0xDF,
    0x8C,
    0xA1,
    0x89,
    0x0D,
    0xBF,
    0xE6,
    0x42,
    0x68,
    0x41,
    0x99,
    0x2D,
    0x0F,
    0xB0,
    0x54,
    0xBB,
    0x16,
  ];

  static const _invSBox = [
    0x52,
    0x09,
    0x6A,
    0xD5,
    0x30,
    0x36,
    0xA5,
    0x38,
    0xBF,
    0x40,
    0xA3,
    0x9E,
    0x81,
    0xF3,
    0xD7,
    0xFB,
    0x7C,
    0xE3,
    0x39,
    0x82,
    0x9B,
    0x2F,
    0xFF,
    0x87,
    0x34,
    0x8E,
    0x43,
    0x44,
    0xC4,
    0xDE,
    0xE9,
    0xCB,
    0x54,
    0x7B,
    0x94,
    0x32,
    0xA6,
    0xC2,
    0x23,
    0x3D,
    0xEE,
    0x4C,
    0x95,
    0x0B,
    0x42,
    0xFA,
    0xC3,
    0x4E,
    0x08,
    0x2E,
    0xA1,
    0x66,
    0x28,
    0xD9,
    0x24,
    0xB2,
    0x76,
    0x5B,
    0xA2,
    0x49,
    0x6D,
    0x8B,
    0xD1,
    0x25,
    0x72,
    0xF8,
    0xF6,
    0x64,
    0x86,
    0x68,
    0x98,
    0x16,
    0xD4,
    0xA4,
    0x5C,
    0xCC,
    0x5D,
    0x65,
    0xB6,
    0x92,
    0x6C,
    0x70,
    0x48,
    0x50,
    0xFD,
    0xED,
    0xB9,
    0xDA,
    0x5E,
    0x15,
    0x46,
    0x57,
    0xA7,
    0x8D,
    0x9D,
    0x84,
    0x90,
    0xD8,
    0xAB,
    0x00,
    0x8C,
    0xBC,
    0xD3,
    0x0A,
    0xF7,
    0xE4,
    0x58,
    0x05,
    0xB8,
    0xB3,
    0x45,
    0x06,
    0xD0,
    0x2C,
    0x1E,
    0x8F,
    0xCA,
    0x3F,
    0x0F,
    0x02,
    0xC1,
    0xAF,
    0xBD,
    0x03,
    0x01,
    0x13,
    0x8A,
    0x6B,
    0x3A,
    0x91,
    0x11,
    0x41,
    0x4F,
    0x67,
    0xDC,
    0xEA,
    0x97,
    0xF2,
    0xCF,
    0xCE,
    0xF0,
    0xB4,
    0xE6,
    0x73,
    0x96,
    0xAC,
    0x74,
    0x22,
    0xE7,
    0xAD,
    0x35,
    0x85,
    0xE2,
    0xF9,
    0x37,
    0xE8,
    0x1C,
    0x75,
    0xDF,
    0x6E,
    0x47,
    0xF1,
    0x1A,
    0x71,
    0x1D,
    0x29,
    0xC5,
    0x89,
    0x6F,
    0xB7,
    0x62,
    0x0E,
    0xAA,
    0x18,
    0xBE,
    0x1B,
    0xFC,
    0x56,
    0x3E,
    0x4B,
    0xC6,
    0xD2,
    0x79,
    0x20,
    0x9A,
    0xDB,
    0xC0,
    0xFE,
    0x78,
    0xCD,
    0x5A,
    0xF4,
    0x1F,
    0xDD,
    0xA8,
    0x33,
    0x88,
    0x07,
    0xC7,
    0x31,
    0xB1,
    0x12,
    0x10,
    0x59,
    0x27,
    0x80,
    0xEC,
    0x5F,
    0x60,
    0x51,
    0x7F,
    0xA9,
    0x19,
    0xB5,
    0x4A,
    0x0D,
    0x2D,
    0xE5,
    0x7A,
    0x9F,
    0x93,
    0xC9,
    0x9C,
    0xEF,
    0xA0,
    0xE0,
    0x3B,
    0x4D,
    0xAE,
    0x2A,
    0xF5,
    0xB0,
    0xC8,
    0xEB,
    0xBB,
    0x3C,
    0x83,
    0x53,
    0x99,
    0x61,
    0x17,
    0x2B,
    0x04,
    0x7E,
    0xBA,
    0x77,
    0xD6,
    0x26,
    0xE1,
    0x69,
    0x14,
    0x63,
    0x55,
    0x21,
    0x0C,
    0x7D,
  ];
}

Future<void> _cryptoHandler(
  QuickJsRuntime2 engine,
  String text,
  String iv,
  String key,
  bool doEncrypt,
  int callbackId,
) async {
  try {
    final encKey = enc.Key.fromUtf8(key.padRight(32).substring(0, 32));
    final encIv = enc.IV.fromUtf8(iv.padRight(16).substring(0, 16));
    final encrypter = enc.Encrypter(enc.AES(encKey, mode: enc.AESMode.cbc));
    final result = doEncrypt
        ? encrypter.encrypt(text, iv: encIv).base64
        : encrypter.decrypt64(text, iv: encIv);
    final escaped = result.replaceAll('"', '\\"').replaceAll('\n', '\\n');
    engine.evaluate('__cryptoCallbacks[$callbackId].resolve("$escaped")');
  } catch (e) {
    final errMsg = e.toString().replaceAll('"', '\\"').replaceAll("'", "\\'");
    engine.evaluate('__cryptoCallbacks[$callbackId].reject("$errMsg")');
  }
}

Future<void> _decryptAESGCM(
  QuickJsRuntime2 engine,
  String encrypted,
  String keyHex,
  String ivHex,
  String tagHex,
  int callbackId,
) async {
  try {
    final keyBytes = _hexDecode(keyHex);
    final ivBytes = _hexDecode(ivHex);
    final cipherBytes = base64Decode(encrypted);
    final tagBytes = tagHex.isNotEmpty ? _hexDecode(tagHex) : <int>[];
    final dataWithTag = Uint8List.fromList([...cipherBytes, ...tagBytes]);
    final encKey = enc.Key(Uint8List.fromList(keyBytes));
    final encIv = enc.IV(Uint8List.fromList(ivBytes));
    final encrypter = enc.Encrypter(enc.AES(encKey, mode: enc.AESMode.gcm));
    final result = encrypter.decrypt(enc.Encrypted(dataWithTag), iv: encIv);
    final escaped = result.replaceAll('"', '\\"').replaceAll('\n', '\\n');
    engine.evaluate('__cryptoCallbacks[$callbackId].resolve("$escaped")');
  } catch (e) {
    final escaped = encrypted.replaceAll('"', '\\"');
    engine.evaluate('__cryptoCallbacks[$callbackId].resolve("$escaped")');
  }
}

void _unpackJsAndCombine(
  QuickJsRuntime2 engine,
  String scriptBlock,
  int callbackId,
) {
  final result = JsUnpacker.unpackAndCombine(scriptBlock) ?? '';
  final escaped = result.replaceAll('"', '\\"').replaceAll('\n', '\\n');
  engine.evaluate('__cryptoCallbacks[$callbackId].resolve("$escaped")');
}

List<int> _hexDecode(String hex) {
  final result = <int>[];
  for (var i = 0; i < hex.length - 1; i += 2) {
    result.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return result;
}

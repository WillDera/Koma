import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:http/http.dart' as http;
import 'package:js_packer/js_packer.dart';

import '../../../core/services/http/m_client.dart';
import '../../../utils/cryptoaes/crypto_aes.dart';
import '../../../utils/cryptoaes/deobfuscator.dart';
import '../../../utils/js_unpacker.dart';

/// Mangayomi-faithful crypto / unpack / webview-eval JS bridges.
///
/// Pattern matches `mangayomi/lib/eval/javascript/utils.dart`: sync
/// `sendMessage` / `onMessage` returns for crypto+unpack; async HTTP loopback
/// for [evaluateJavascriptViaWebview] via [cfPort].
const cryptoBridgeCode = r'''
function cryptoHandler(text, iv, secretKeyString, encrypt) {
    return sendMessage(
        "cryptoHandler",
        JSON.stringify([text, iv, secretKeyString, encrypt])
    );
}
function encryptAESCryptoJS(plainText, passphrase) {
    return sendMessage(
        "encryptAESCryptoJS",
        JSON.stringify([plainText, passphrase])
    );
}
function decryptAESCryptoJS(encrypted, passphrase) {
    return sendMessage(
        "decryptAESCryptoJS",
        JSON.stringify([encrypted, passphrase])
    );
}
function decryptAESGCM(encrypted, keyHex, ivHex, tagHex = "") {
    return sendMessage(
        "decryptAESGCM",
        JSON.stringify([encrypted, keyHex, ivHex, tagHex])
    );
}
function deobfuscateJsPassword(inputString) {
    return sendMessage(
        "deobfuscateJsPassword",
        JSON.stringify([inputString])
    );
}
function unpackJsAndCombine(scriptBlock) {
    return sendMessage(
        "unpackJsAndCombine",
        JSON.stringify([scriptBlock])
    );
}
function unpackJs(packedJS) {
    return sendMessage(
        "unpackJs",
        JSON.stringify([packedJS])
    );
}
async function evaluateJavascriptViaWebview(url, headers, scripts) {
    return await sendMessage(
        "evaluateJavascriptViaWebview",
        JSON.stringify([url, headers, scripts])
    );
}
''';

Future<void> injectCryptoBridge(JavascriptRuntime runtime) async {
  List<dynamic> asList(dynamic args) {
    if (args is List) return args;
    if (args is String) {
      try {
        final decoded = jsonDecode(args);
        if (decoded is List) return decoded;
      } catch (_) {}
    }
    return <dynamic>[];
  }

  runtime.onMessage('cryptoHandler', (dynamic args) {
    final list = asList(args);
    return _cryptoHandler(
      list.isNotEmpty ? list[0].toString() : '',
      list.length > 1 ? list[1].toString() : '',
      list.length > 2 ? list[2].toString() : '',
      list.length > 3 ? list[3] == true : false,
    );
  });
  runtime.onMessage('encryptAESCryptoJS', (dynamic args) {
    final list = asList(args);
    return CryptoAES.encryptAESCryptoJS(
      list.isNotEmpty ? list[0].toString() : '',
      list.length > 1 ? list[1].toString() : '',
    );
  });
  runtime.onMessage('decryptAESCryptoJS', (dynamic args) {
    final list = asList(args);
    return CryptoAES.decryptAESCryptoJS(
      list.isNotEmpty ? list[0].toString() : '',
      list.length > 1 ? list[1].toString() : '',
    );
  });
  runtime.onMessage('decryptAESGCM', (dynamic args) {
    final list = asList(args);
    return _decryptAESGCM(
      list.isNotEmpty ? list[0].toString() : '',
      list.length > 1 ? list[1].toString() : '',
      list.length > 2 ? list[2].toString() : '',
      list.length > 3 ? (list[3]?.toString() ?? '') : '',
    );
  });
  runtime.onMessage('deobfuscateJsPassword', (dynamic args) {
    final list = asList(args);
    return Deobfuscator.deobfuscateJsPassword(
      list.isNotEmpty ? list[0].toString() : '',
    );
  });
  runtime.onMessage('unpackJsAndCombine', (dynamic args) {
    final list = asList(args);
    return JsUnpacker.unpackAndCombine(
          list.isNotEmpty ? list[0].toString() : '',
        ) ??
        '';
  });
  runtime.onMessage('unpackJs', (dynamic args) {
    final list = asList(args);
    return JSPacker(list.isNotEmpty ? list[0].toString() : '').unpack() ?? '';
  });
  runtime.onMessage('evaluateJavascriptViaWebview', (dynamic args) async {
    final list = asList(args);
    final url = list.isNotEmpty ? list[0].toString() : '';
    final headersRaw = list.length > 1 ? list[1] : null;
    final scriptsRaw = list.length > 2 ? list[2] : null;
    final headers = headersRaw is Map
        ? headersRaw.map((k, v) => MapEntry(k.toString(), v.toString()))
        : <String, String>{};
    final scripts = scriptsRaw is List
        ? scriptsRaw.map((e) => e.toString()).toList()
        : <String>[];
    final time = list.length > 3 ? (list[3] as int? ?? 30) : 30;
    try {
      final res = await http.post(
        Uri.parse('http://localhost:$cfPort/evaluateJavascriptViaWebview'),
        headers: {HttpHeaders.contentTypeHeader: 'application/json'},
        body: jsonEncode({
          'url': url,
          'headers': headers,
          'scripts': scripts,
          'time': time,
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        // Mangayomi casts to bool, but the loopback handler returns the
        // setResponse string — forward the raw result to JS.
        return data['result'];
      }
      return false;
    } catch (_) {
      return false;
    }
  });

  runtime.evaluate(cryptoBridgeCode);
}

/// AES-CBC cryptoHandler — faithful to mangayomi [MBridge.cryptoHandler].
String _cryptoHandler(
  String text,
  String iv,
  String secretKeyString,
  bool doEncrypt,
) {
  try {
    final pair = _encryptPair(secretKeyString, iv);
    if (doEncrypt) {
      return pair.$1.encrypt(text, iv: pair.$2).base64;
    }
    return pair.$1.decrypt64(text, iv: pair.$2);
  } catch (_) {
    return text;
  }
}

(encrypt.Encrypter, encrypt.IV) _encryptPair(String keyy, String ivv) {
  final key = encrypt.Key.fromUtf8(keyy);
  final iv = encrypt.IV.fromUtf8(ivv);
  final encrypter = encrypt.Encrypter(
    encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
  );
  return (encrypter, iv);
}

/// AES-GCM decrypt — faithful to mangayomi [MBridge.decryptAESGCM].
String _decryptAESGCM(
  String encrypted,
  String keyHex,
  String ivHex,
  String tagHex,
) {
  try {
    final key = encrypt.Key(Uint8List.fromList(_hexDecode(keyHex)));
    final iv = encrypt.IV(Uint8List.fromList(_hexDecode(ivHex)));
    final dataWithTag = Uint8List.fromList([
      ...base64.decode(encrypted),
      ..._hexDecode(tagHex),
    ]);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.gcm),
    );
    return encrypter.decrypt(encrypt.Encrypted(dataWithTag), iv: iv);
  } catch (_) {
    return encrypted;
  }
}

List<int> _hexDecode(String hexStr) {
  final result = <int>[];
  for (var i = 0; i < hexStr.length - 1; i += 2) {
    result.add(int.parse(hexStr.substring(i, i + 2), radix: 16));
  }
  return result;
}

import 'dart:io';
import 'package:flutter/services.dart';

class SystemFontService {
  static const _channel = MethodChannel('com.koma.koma/system');

  Future<String?> getSystemTypeface() async {
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod<String>('getSystemTypeface');
      }
    } on PlatformException {
      // ignore
    }
    return null;
  }
}

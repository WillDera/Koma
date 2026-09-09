import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Biometric / device-credential unlock + Android FLAG_SECURE bridge.
class AppLockService {
  AppLockService._();

  static final _auth = LocalAuthentication();
  static const _secureChannel = MethodChannel('com.koma.koma/secure_screen');

  static Future<bool> canAuthenticate() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate({String reason = 'Unlock Koma'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// [mode]: 0 never, 1 when incognito, 2 always.
  static Future<void> applySecureScreen({
    required int mode,
    required bool incognito,
  }) async {
    final secure = mode == 2 || (mode == 1 && incognito);
    try {
      await _secureChannel.invokeMethod('setSecureScreen', {'secure': secure});
    } catch (_) {
      try {
        await _secureChannel.invokeMethod('setSecureScreen', secure);
      } catch (_) {}
    }
  }
}

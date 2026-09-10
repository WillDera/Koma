import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

/// Result of [AppLockService.authenticate].
class AppLockAuthResult {
  const AppLockAuthResult._({
    required this.success,
    this.errorMessage,
    this.deviceAuthUnavailable = false,
  });

  factory AppLockAuthResult.ok() => const AppLockAuthResult._(success: true);

  factory AppLockAuthResult.failed(String message) =>
      AppLockAuthResult._(success: false, errorMessage: message);

  factory AppLockAuthResult.unavailable(String message) => AppLockAuthResult._(
        success: false,
        errorMessage: message,
        deviceAuthUnavailable: true,
      );

  final bool success;
  final String? errorMessage;
  final bool deviceAuthUnavailable;
}

/// Biometric / device-credential unlock + Android FLAG_SECURE bridge.
class AppLockService {
  AppLockService._();

  static final _auth = LocalAuthentication();
  static const _secureChannel = MethodChannel('com.koma.koma/secure_screen');

  /// True while a system auth UI is up (biometric / device credential).
  /// Lifecycle must not treat that as "user left the app".
  static bool authInProgress = false;

  static Future<bool> canAuthenticate() async {
    final status = await deviceAuthStatus();
    return status.available;
  }

  /// Why device auth is or isn't usable (emulators often have no PIN enrolled).
  static Future<({bool available, String detail})> deviceAuthStatus() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        return (
          available: false,
          detail:
              'This device has no screen lock. On an emulator: Settings → '
              'Security → set a PIN, or Extended controls → Fingerprint.',
        );
      }
      final canBio = await _auth.canCheckBiometrics;
      if (canBio || supported) {
        return (available: true, detail: 'Device authentication available');
      }
      return (
        available: false,
        detail: 'No biometric or screen lock available on this device.',
      );
    } catch (e) {
      return (available: false, detail: 'Auth check failed: $e');
    }
  }

  static Future<AppLockAuthResult> authenticate({
    String reason = 'Unlock Koma',
  }) async {
    final status = await deviceAuthStatus();
    if (!status.available) {
      return AppLockAuthResult.unavailable(status.detail);
    }

    authInProgress = true;
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      if (ok) return AppLockAuthResult.ok();
      return AppLockAuthResult.failed('Authentication cancelled');
    } on PlatformException catch (e) {
      final code = e.code;
      if (code == auth_error.notAvailable ||
          code == auth_error.notEnrolled ||
          code == auth_error.passcodeNotSet) {
        return AppLockAuthResult.unavailable(
          e.message?.isNotEmpty == true
              ? e.message!
              : 'Set a device PIN or enroll biometrics, then try again.',
        );
      }
      return AppLockAuthResult.failed(
        e.message?.isNotEmpty == true
            ? e.message!
            : 'Authentication failed ($code)',
      );
    } catch (e) {
      return AppLockAuthResult.failed('$e');
    } finally {
      authInProgress = false;
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

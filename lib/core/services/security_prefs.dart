import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mihon-style privacy prefs: incognito + app lock + secure screen.
class SecurityPrefs {
  static const _kIncognito = 'security_incognito';
  static const _kAppLock = 'security_app_lock';
  static const _kSecureScreen = 'security_secure_screen'; // 0 never, 1 incognito, 2 always
  static const _kHideNotification = 'security_hide_notification_content';
  static const _kUpdateProgressAfterReading =
      'tracker_update_progress_after_reading';

  static bool incognitoCached = false;
  static bool appLockCached = false;
  static int secureScreenCached = 1;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    incognitoCached = p.getBool(_kIncognito) ?? false;
    appLockCached = p.getBool(_kAppLock) ?? false;
    secureScreenCached = p.getInt(_kSecureScreen) ?? 1;
  }

  static Future<bool> isIncognito() async {
    final p = await SharedPreferences.getInstance();
    return incognitoCached = p.getBool(_kIncognito) ?? false;
  }

  static Future<void> setIncognito(bool v) async {
    incognitoCached = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kIncognito, v);
  }

  static Future<bool> isAppLockEnabled() async {
    final p = await SharedPreferences.getInstance();
    return appLockCached = p.getBool(_kAppLock) ?? false;
  }

  static Future<void> setAppLockEnabled(bool v) async {
    appLockCached = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAppLock, v);
  }

  /// 0 = never, 1 = when incognito, 2 = always (FLAG_SECURE / hide recents).
  static Future<int> secureScreenMode() async {
    final p = await SharedPreferences.getInstance();
    return secureScreenCached = p.getInt(_kSecureScreen) ?? 1;
  }

  static Future<void> setSecureScreenMode(int v) async {
    secureScreenCached = v.clamp(0, 2);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kSecureScreen, secureScreenCached);
  }

  static Future<bool> hideNotificationContent() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kHideNotification) ?? false;
  }

  static Future<void> setHideNotificationContent(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kHideNotification, v);
  }

  static Future<bool> updateProgressAfterReading() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kUpdateProgressAfterReading) ?? true;
  }

  static Future<void> setUpdateProgressAfterReading(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kUpdateProgressAfterReading, v);
  }
}

class IncognitoNotifier extends Notifier<bool> {
  @override
  bool build() => SecurityPrefs.incognitoCached;

  Future<void> set(bool value) async {
    state = value;
    await SecurityPrefs.setIncognito(value);
  }

  Future<void> toggle() => set(!state);
}

final incognitoProvider =
    NotifierProvider<IncognitoNotifier, bool>(IncognitoNotifier.new);

class AppLockEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => SecurityPrefs.appLockCached;

  Future<void> set(bool value) async {
    state = value;
    await SecurityPrefs.setAppLockEnabled(value);
  }
}

final appLockEnabledProvider =
    NotifierProvider<AppLockEnabledNotifier, bool>(AppLockEnabledNotifier.new);

/// Whether the session is unlocked. When lock is off, always true.
class AppUnlockedNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Prefer listen over watch so unlock() is not wiped on every rebuild.
    ref.listen<bool>(appLockEnabledProvider, (prev, next) {
      if (!next) {
        state = true;
      } else if (prev != true) {
        // Cold-start from prefs, or user just enabled lock → require unlock.
        // Enable flow calls [unlock] immediately after set(true).
        state = false;
      }
    });
    return !ref.read(appLockEnabledProvider);
  }

  void unlock() => state = true;

  void lock() {
    if (ref.read(appLockEnabledProvider)) state = false;
  }
}

final appUnlockedProvider =
    NotifierProvider<AppUnlockedNotifier, bool>(AppUnlockedNotifier.new);

class SecureScreenNotifier extends Notifier<int> {
  @override
  int build() => SecurityPrefs.secureScreenCached;

  Future<void> set(int value) async {
    state = value.clamp(0, 2);
    await SecurityPrefs.setSecureScreenMode(state);
  }
}

final secureScreenProvider =
    NotifierProvider<SecureScreenNotifier, int>(SecureScreenNotifier.new);

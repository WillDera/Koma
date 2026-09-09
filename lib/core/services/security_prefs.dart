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

  static Future<bool> isIncognito() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kIncognito) ?? false;
  }

  static Future<void> setIncognito(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kIncognito, v);
  }

  static Future<bool> isAppLockEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kAppLock) ?? false;
  }

  static Future<void> setAppLockEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAppLock, v);
  }

  /// 0 = never, 1 = when incognito, 2 = always (FLAG_SECURE / hide recents).
  static Future<int> secureScreenMode() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kSecureScreen) ?? 1;
  }

  static Future<void> setSecureScreenMode(int v) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kSecureScreen, v.clamp(0, 2));
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
  bool build() {
    Future.microtask(_load);
    return false;
  }

  Future<void> _load() async {
    state = await SecurityPrefs.isIncognito();
  }

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
  bool build() {
    Future.microtask(_load);
    return false;
  }

  Future<void> _load() async {
    state = await SecurityPrefs.isAppLockEnabled();
  }

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
    final lockOn = ref.watch(appLockEnabledProvider);
    return !lockOn;
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
  int build() {
    Future.microtask(_load);
    return 1;
  }

  Future<void> _load() async {
    state = await SecurityPrefs.secureScreenMode();
  }

  Future<void> set(int value) async {
    state = value.clamp(0, 2);
    await SecurityPrefs.setSecureScreenMode(state);
  }
}

final secureScreenProvider =
    NotifierProvider<SecureScreenNotifier, int>(SecureScreenNotifier.new);

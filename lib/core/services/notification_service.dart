import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'library_update_service.dart';

/// Wraps flutter_local_notifications for library, extension, and download
/// alerts.
///
/// Notifications are only posted when the corresponding user toggle is on
/// (persisted in SharedPreferences). The library poller / download worker may
/// run from a WorkManager background isolate, so this service must be fully
/// self contained — it initializes its own plugin instance and never touches
/// Riverpod state.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _keyNotifyNewChapters = 'notify_new_chapters';
  static const _keyNotifyExtUpdates = 'notify_extension_updates';

  static const _channelLibrary = 'library_updates';
  static const _channelExtensions = 'extension_updates';
  static const _channelDownloadProgress = 'downloader_progress';
  static const _channelDownloadError = 'downloader_error';

  static const _idDownloadProgress = 1100;
  static const _idDownloadError = 1101;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('app_icon'),
    );
    await _plugin.initialize(settings: settings);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
    _initialized = true;
  }

  /// System notification for a library poll that found new chapters.
  Future<void> notifyNewChapters(LibraryUpdateReport report) async {
    if (report.totalNew <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_keyNotifyNewChapters) ?? true)) return;
    await _show(
      id: 1000,
      title: '${report.totalNew} new chapter${report.totalNew == 1 ? '' : 's'}',
      body: report.updatedNames.isEmpty
          ? 'in your library'
          : report.updatedNames.take(3).join(', ') +
                (report.updatedNames.length > 3 ? '…' : ''),
      channelId: _channelLibrary,
      channelName: 'Library updates',
      channelDescription: 'New chapters in your library',
    );
  }

  /// System notification when extension updates are available at app start.
  Future<void> notifyExtensionUpdates(int count) async {
    if (count <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_keyNotifyExtUpdates) ?? true)) return;
    await _show(
      id: 1001,
      title: '$count plugin update${count == 1 ? '' : 's'} available',
      body: 'Tap to install the latest extensions.',
      channelId: _channelExtensions,
      channelName: 'Plugin updates',
      channelDescription: 'New extension versions available',
    );
  }

  /// Ongoing progress for the chapter download queue (Mihon DownloadNotifier).
  Future<void> notifyDownloadProgress({
    required String mangaTitle,
    required String chapterName,
    required int done,
    required int total,
    required int pending,
  }) async {
    await init();
    final progressText = total > 0 ? '$done/$total' : '…';
    final title = mangaTitle.isEmpty ? 'Downloading' : mangaTitle;
    final body = pending > 1
        ? '$chapterName · $progressText · $pending in queue'
        : '$chapterName · $progressText';
    final details = AndroidNotificationDetails(
      _channelDownloadProgress,
      'Download progress',
      channelDescription: 'Chapter download progress',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      ongoing: true,
      showProgress: total > 0,
      maxProgress: total > 0 ? total : 0,
      progress: total > 0 ? done : 0,
      category: AndroidNotificationCategory.progress,
    );
    await _plugin.show(
      id: _idDownloadProgress,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: details),
    );
  }

  Future<void> notifyDownloadPaused(int pending) async {
    await init();
    final details = AndroidNotificationDetails(
      _channelDownloadProgress,
      'Download progress',
      channelDescription: 'Chapter download progress',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      ongoing: false,
    );
    await _plugin.show(
      id: _idDownloadProgress,
      title: 'Downloads paused',
      body: pending <= 0
          ? 'Queue empty'
          : '$pending chapter${pending == 1 ? '' : 's'} remaining',
      notificationDetails: NotificationDetails(android: details),
    );
  }

  Future<void> notifyDownloadError(String message) async {
    await init();
    const details = AndroidNotificationDetails(
      _channelDownloadError,
      'Download errors',
      channelDescription: 'Chapter download failures',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    await _plugin.show(
      id: _idDownloadError,
      title: 'Download failed',
      body: message,
      notificationDetails: NotificationDetails(android: details),
    );
  }

  Future<void> dismissDownloadProgress() async {
    if (!_initialized) return;
    await _plugin.cancel(id: _idDownloadProgress);
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDescription,
  }) async {
    if (!_initialized) return;
    final details = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: details),
    );
  }
}

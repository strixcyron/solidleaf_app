import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Локальные уведомления о найденных обновлениях русификатора.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const windows = WindowsInitializationSettings(
        appName: 'SolidLeaf',
        appUserModelId: 'SolidLeaf.Launcher.App.1',
        guid: 'b7b3f0b2-9c4e-4e7a-9b1a-8a3d2f5c1e10',
      );
      const initSettings = InitializationSettings(
        android: android,
        windows: windows,
      );
      await _plugin.initialize(settings: initSettings);

      if (Platform.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.requestNotificationsPermission();
      }
      _ready = true;
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
    }
  }

  Future<void> showUpdateAvailable({
    required String title,
    required String body,
  }) async {
    if (!_ready) await init();
    if (!_ready) return;
    try {
      const androidDetails = AndroidNotificationDetails(
        'solidleaf_updates',
        'Обновления',
        channelDescription: 'Уведомления о новых версиях русификатора',
        importance: Importance.high,
        priority: Priority.high,
      );
      const windowsDetails = WindowsNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        windows: windowsDetails,
      );
      await _plugin.show(
        id: 1999,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('showUpdateAvailable failed: $e');
    }
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Системный трей Windows: свернуть лаунчер и восстановить по клику.
class TrayService with TrayListener {
  TrayService._();
  static final TrayService instance = TrayService._();

  bool _ready = false;
  bool get isReady => _ready;

  Future<void> init() async {
    if (!Platform.isWindows || _ready) return;
    try {
      trayManager.addListener(this);
      // Иконка из ассетов: копируем во временный файл (tray_manager ждёт путь).
      final iconPath = await _resolveTrayIconPath();
      await trayManager.setIcon(iconPath);
      await trayManager.setToolTip('SolidLeaf Launcher');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'show', label: 'Открыть лаунчер'),
            MenuItem.separator(),
            MenuItem(key: 'exit', label: 'Выход'),
          ],
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('TrayService init failed: $e');
    }
  }

  Future<String> _resolveTrayIconPath() async {
    final support = await getApplicationSupportDirectory();
    final out = File(p.join(support.path, 'tray_icon.ico'));
    if (!await out.exists()) {
      final data = await rootBundle.load('assets/images/launcher_icon.ico');
      await out.writeAsBytes(data.buffer.asUint8List());
    }
    return out.path;
  }

  Future<void> hideToTray() async {
    if (!Platform.isWindows) return;
    if (!_ready) await init();
    try {
      await windowManager.hide();
      await windowManager.setSkipTaskbar(true);
    } catch (e) {
      debugPrint('hideToTray: $e');
    }
  }

  Future<void> showFromTray() async {
    if (!Platform.isWindows) return;
    try {
      await windowManager.setSkipTaskbar(false);
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('showFromTray: $e');
    }
  }

  @override
  void onTrayIconMouseDown() {
    showFromTray();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        showFromTray();
        break;
      case 'exit':
        windowManager.destroy();
        break;
    }
  }

  Future<void> dispose() async {
    if (!_ready) return;
    trayManager.removeListener(this);
    try {
      await trayManager.destroy();
    } catch (_) {}
    _ready = false;
  }
}

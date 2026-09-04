import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'controllers/launcher_controller.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'services/tray_service.dart';
import 'theme/app_theme.dart';
import 'utils/single_instance.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Одна копия лаунчера: второй процесс сразу выходит.
  final isFirst = await SingleInstanceGuard.ensureSingleInstance();
  if (!isFirst) {
    exit(0);
  }

  await NotificationService.instance.init();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    const minSize = Size(960, 600);
    const defaultSize = Size(1024, 640);

    const windowOptions = WindowOptions(
      size: defaultSize,
      minimumSize: minSize,
      center: true,
      backgroundColor: Color(0xFF111019),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setMinimumSize(minSize);
      // Сброс битых/нулевых размеров после странного DPI или прошлой сессии.
      await _ensureSaneWindowGeometry(minSize: minSize, defaultSize: defaultSize);
      await windowManager.show();
      await windowManager.focus();
      if (Platform.isWindows) {
        await TrayService.instance.init();
      }
    });
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => LauncherController(),
      child: const LocalizationLauncher(),
    ),
  );
}

/// Если окно меньше минимума или размеры «нулевые» — ставим дефолт и центр.
Future<void> _ensureSaneWindowGeometry({
  required Size minSize,
  required Size defaultSize,
}) async {
  try {
    final bounds = await windowManager.getBounds();
    final w = bounds.width;
    final h = bounds.height;
    final broken = w.isNaN ||
        h.isNaN ||
        w < minSize.width ||
        h < minSize.height ||
        w > 10000 ||
        h > 10000;
    if (broken) {
      await windowManager.setSize(defaultSize);
      await windowManager.center();
    }
  } catch (_) {
    await windowManager.setSize(defaultSize);
    await windowManager.center();
  }
}

class LocalizationLauncher extends StatelessWidget {
  const LocalizationLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LauncherController>();

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final useDynamic =
            controller.dynamicColorEnabled && lightDynamic != null;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'SOLIDLEAF TEAM',
          themeMode: _resolveThemeMode(controller),
          themeAnimationDuration: const Duration(milliseconds: 400),
          themeAnimationCurve: Curves.easeInOut,
          theme: AppTheme.light(
            preset: controller.themePreset,
            coverAccent: controller.coverAccent,
            coverSecondary: controller.coverSecondary,
            coverMuted: controller.coverMuted,
            customAccent: controller.customAccent,
            dynamicScheme: useDynamic ? lightDynamic.harmonized() : null,
          ),
          darkTheme: AppTheme.dark(
            preset: controller.themePreset,
            coverAccent: controller.coverAccent,
            coverSecondary: controller.coverSecondary,
            coverMuted: controller.coverMuted,
            customAccent: controller.customAccent,
            dynamicScheme: useDynamic ? darkDynamic?.harmonized() : null,
          ),
          // Масштаб шрифта интерфейса из настроек.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(controller.uiScale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const AuthGate(),
        );
      },
    );
  }

  /// Пресеты с фиксированной яркостью управляют темой сами; «Из баннера»
  /// и Material You уважают переключатель светлая/тёмная.
  ThemeMode _resolveThemeMode(LauncherController controller) {
    if (controller.dynamicColorEnabled &&
        controller.themePreset != AppThemePreset.dynamicCover) {
      return controller.isDarkMode ? ThemeMode.dark : ThemeMode.light;
    }
    final brightness = AppTheme.effectiveBrightness(
      controller.themePreset,
      controller.isDarkMode,
    );
    return brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
  }
}

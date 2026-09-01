import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'controllers/launcher_controller.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1180, 760),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => LauncherController(),
      child: const LocalizationLauncher(),
    ),
  );
}

class LocalizationLauncher extends StatelessWidget {
  const LocalizationLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LauncherController>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SOLIDLEAF TEAM',
      themeMode: controller.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: const Duration(milliseconds: 400),
      themeAnimationCurve: Curves.easeInOut,
      theme: AppTheme.light(coverAccent: controller.coverAccent),
      darkTheme: AppTheme.dark(coverAccent: controller.coverAccent),
      // The launcher requires a successful Telegram login before the main
      // screen (with texture/text install controls) becomes reachable —
      // see AuthGate/LoginScreen in login_screen.dart.
      home: const AuthGate(),
    );
  }
}

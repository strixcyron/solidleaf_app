import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'controllers/launcher_controller.dart';
import 'screens/login_screen.dart';

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

      // ☀️ Светлая тема («Винтажная бумага»)
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F0E6),
        cardColor: const Color(0xFFE8E2D4),
        dividerColor: const Color(0xFFC8BFB0),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8C6D3B),
          primary: const Color(0xFF8C6D3B),
          secondary: const Color(0xFFA6854D),
          surface: const Color(0xFFE8E2D4),
          brightness: Brightness.light,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF2C2621)),
          bodySmall: TextStyle(color: Color(0xFF6B6255)),
        ),
        fontFamily: 'Inter',
      ),

      // 🌙 Тёмная тема («Ностальгический нуар»)
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF111019),
        cardColor: const Color(0xFF1D1A2B),
        dividerColor: const Color(0xFF2D2240),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B52F4),
          primary: const Color(0xFF7B52F4),
          secondary: const Color(0xFF8A6AF6),
          surface: const Color(0xFF1D1A2B),
          brightness: Brightness.dark,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFFEEEEEE)),
          bodySmall: TextStyle(color: Color(0xFFA09CB0)),
        ),
        fontFamily: 'Inter',
      ),
      // The launcher requires a successful Telegram login before the main
      // screen (with texture/text install controls) becomes reachable —
      // see AuthGate/LoginScreen in login_screen.dart.
      home: const AuthGate(),
    );
  }
}

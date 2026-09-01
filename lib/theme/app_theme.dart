import 'package:flutter/material.dart';

import '../services/cover_accent_loader.dart';

class AppTheme {
  AppTheme._();

  static const _lightPrimary = Color(0xFF8C6D3B);
  static const _lightSecondary = Color(0xFFA6854D);
  static const _darkPrimary = Color(0xFF7B52F4);
  static const _darkSecondary = Color(0xFF8A6AF6);

  static ThemeData light({Color? coverAccent}) {
    final primary = blendAccent(_lightPrimary, coverAccent, 0.14);
    final secondary = blendAccent(_lightSecondary, coverAccent, 0.10);

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF4F0E6),
      cardColor: const Color(0xFFE8E2D4),
      dividerColor: const Color(0xFFC8BFB0),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        surface: const Color(0xFFE8E2D4),
        brightness: Brightness.light,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Color(0xFF2C2621)),
        bodySmall: TextStyle(color: Color(0xFF6B6255)),
      ),
      fontFamily: 'Inter',
      tooltipTheme: _tooltipTheme(isDark: false),
    );
  }

  static ThemeData dark({Color? coverAccent}) {
    final primary = blendAccent(_darkPrimary, coverAccent, 0.12);
    final secondary = blendAccent(_darkSecondary, coverAccent, 0.10);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF111019),
      cardColor: const Color(0xFF1D1A2B),
      dividerColor: const Color(0xFF2D2240),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        surface: const Color(0xFF1D1A2B),
        brightness: Brightness.dark,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Color(0xFFEEEEEE)),
        bodySmall: TextStyle(color: Color(0xFFA09CB0)),
      ),
      fontFamily: 'Inter',
      tooltipTheme: _tooltipTheme(isDark: true),
    );
  }

  static TooltipThemeData _tooltipTheme({required bool isDark}) {
    return TooltipThemeData(
      waitDuration: const Duration(milliseconds: 350),
      showDuration: const Duration(seconds: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D1A2B) : const Color(0xFF2C2621),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFFC9A227), width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      textStyle: TextStyle(
        color: isDark ? const Color(0xFFEEEEEE) : Colors.white,
        fontSize: 12,
        height: 1.35,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

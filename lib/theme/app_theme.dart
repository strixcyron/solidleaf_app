import 'package:flutter/material.dart';

import '../services/cover_accent_loader.dart';

/// Пресеты оформления лаунчера. Выбираются в настройках.
enum AppThemePreset {
  dynamicCover('Из обложки', 'Цвета берутся из обложки игры'),
  amoled('AMOLED', 'Чистый чёрный — экономит батарею на OLED'),
  neon('Неон', 'Тёмная тема с яркими акцентами'),
  sepia('Сепия', 'Тёплая «бумажная» светлая тема'),
  ocean('Океан', 'Глубокий сине-бирюзовый'),
  sakura('Сакура', 'Нежная светло-розовая');

  const AppThemePreset(this.label, this.description);

  final String label;
  final String description;
}

/// Набор цветов конкретного пресета.
class _Palette {
  const _Palette({
    required this.brightness,
    required this.scaffold,
    required this.card,
    required this.divider,
    required this.primary,
    required this.secondary,
    required this.textPrimary,
    required this.textSecondary,
    this.forceBrightness = true,
  });

  final Brightness brightness;
  final Color scaffold;
  final Color card;
  final Color divider;
  final Color primary;
  final Color secondary;
  final Color textPrimary;
  final Color textSecondary;

  /// Если false — пресет уважает переключатель светлая/тёмная.
  final bool forceBrightness;
}

class AppTheme {
  AppTheme._();

  static const _darkPrimary = Color(0xFF7B52F4);
  static const _darkSecondary = Color(0xFF8A6AF6);
  static const _lightPrimary = Color(0xFF8C6D3B);
  static const _lightSecondary = Color(0xFFA6854D);

  /// Собирает светлую тему приложения по текущим настройкам.
  static ThemeData light({
    AppThemePreset preset = AppThemePreset.dynamicCover,
    Color? coverAccent,
    Color? customAccent,
    ColorScheme? dynamicScheme,
  }) =>
      _build(
        preset: preset,
        isDark: false,
        coverAccent: coverAccent,
        customAccent: customAccent,
        dynamicScheme: dynamicScheme,
      );

  /// Собирает тёмную тему приложения по текущим настройкам.
  static ThemeData dark({
    AppThemePreset preset = AppThemePreset.dynamicCover,
    Color? coverAccent,
    Color? customAccent,
    ColorScheme? dynamicScheme,
  }) =>
      _build(
        preset: preset,
        isDark: true,
        coverAccent: coverAccent,
        customAccent: customAccent,
        dynamicScheme: dynamicScheme,
      );

  /// Акцентный цвет пресета для превью в настройках.
  static Color previewAccent(AppThemePreset preset, {bool isDark = true}) =>
      _paletteFor(preset, isDark).primary;

  /// Фон пресета для превью в настройках.
  static Color previewBackground(AppThemePreset preset, {bool isDark = true}) =>
      _paletteFor(preset, isDark).scaffold;

  /// Реальная яркость, которую даст пресет (для выбора themeMode в main).
  static Brightness effectiveBrightness(AppThemePreset preset, bool isDark) {
    final p = _paletteFor(preset, isDark);
    return p.forceBrightness
        ? p.brightness
        : (isDark ? Brightness.dark : Brightness.light);
  }

  static ThemeData _build({
    required AppThemePreset preset,
    required bool isDark,
    Color? coverAccent,
    Color? customAccent,
    ColorScheme? dynamicScheme,
  }) {
    // Material You (адаптивные цвета) — только если нет пользовательского акцента.
    if (customAccent == null && dynamicScheme != null) {
      return _fromScheme(dynamicScheme);
    }

    final p = _paletteFor(preset, isDark);
    final usesCover = preset == AppThemePreset.dynamicCover;

    final Color primary;
    final Color secondary;
    if (customAccent != null) {
      primary = customAccent;
      secondary = customAccent;
    } else {
      primary = usesCover ? blendAccent(p.primary, coverAccent, 0.14) : p.primary;
      secondary =
          usesCover ? blendAccent(p.secondary, coverAccent, 0.10) : p.secondary;
    }

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      surface: p.card,
      brightness: p.brightness,
    );

    return _assemble(
      brightness: p.brightness,
      scaffold: p.scaffold,
      card: p.card,
      divider: p.divider,
      scheme: scheme,
      textPrimary: p.textPrimary,
      textSecondary: p.textSecondary,
    );
  }

  /// Тема из системной цветовой схемы (Material You на Android 12+).
  static ThemeData _fromScheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final scaffold =
        isDark ? const Color(0xFF121016) : const Color(0xFFF6F3FA);
    return _assemble(
      brightness: scheme.brightness,
      scaffold: scaffold,
      card: scheme.surfaceContainerHigh,
      divider: scheme.outlineVariant,
      scheme: scheme,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
    );
  }

  static ThemeData _assemble({
    required Brightness brightness,
    required Color scaffold,
    required Color card,
    required Color divider,
    required ColorScheme scheme,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: scaffold,
      cardColor: card,
      dividerColor: divider,
      colorScheme: scheme,
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: textPrimary),
        bodySmall: TextStyle(color: textSecondary),
      ),
      fontFamily: 'Inter',
      tooltipTheme: _tooltipTheme(isDark: brightness == Brightness.dark),
    );
  }

  static _Palette _paletteFor(AppThemePreset preset, bool isDark) {
    switch (preset) {
      case AppThemePreset.amoled:
        return const _Palette(
          brightness: Brightness.dark,
          scaffold: Color(0xFF000000),
          card: Color(0xFF0B0B0F),
          divider: Color(0xFF1E1E26),
          primary: Color(0xFF9B7CFF),
          secondary: Color(0xFF00E5D0),
          textPrimary: Color(0xFFF2F2F5),
          textSecondary: Color(0xFF9A98A6),
        );
      case AppThemePreset.neon:
        return const _Palette(
          brightness: Brightness.dark,
          scaffold: Color(0xFF0D0221),
          card: Color(0xFF1A0B2E),
          divider: Color(0xFF3A1F5C),
          primary: Color(0xFFB026FF),
          secondary: Color(0xFF00F5FF),
          textPrimary: Color(0xFFF4ECFF),
          textSecondary: Color(0xFFB39CD0),
        );
      case AppThemePreset.sepia:
        return const _Palette(
          brightness: Brightness.light,
          scaffold: Color(0xFFF1E7D0),
          card: Color(0xFFE7D9BC),
          divider: Color(0xFFCDBB98),
          primary: Color(0xFF8B5E34),
          secondary: Color(0xFFB07D46),
          textPrimary: Color(0xFF3B2F1E),
          textSecondary: Color(0xFF6E5C42),
        );
      case AppThemePreset.ocean:
        return const _Palette(
          brightness: Brightness.dark,
          scaffold: Color(0xFF06141B),
          card: Color(0xFF0C2731),
          divider: Color(0xFF1C3D49),
          primary: Color(0xFF00B4D8),
          secondary: Color(0xFF48CAE4),
          textPrimary: Color(0xFFE3F6FB),
          textSecondary: Color(0xFF8FB3BE),
        );
      case AppThemePreset.sakura:
        return const _Palette(
          brightness: Brightness.light,
          scaffold: Color(0xFFFFF0F3),
          card: Color(0xFFFFE0E6),
          divider: Color(0xFFF3C2CD),
          primary: Color(0xFFE75A7C),
          secondary: Color(0xFFF48FB1),
          textPrimary: Color(0xFF4A2731),
          textSecondary: Color(0xFF9A6673),
        );
      case AppThemePreset.dynamicCover:
        if (isDark) {
          return const _Palette(
            brightness: Brightness.dark,
            scaffold: Color(0xFF111019),
            card: Color(0xFF1D1A2B),
            divider: Color(0xFF2D2240),
            primary: _darkPrimary,
            secondary: _darkSecondary,
            textPrimary: Color(0xFFEEEEEE),
            textSecondary: Color(0xFFA09CB0),
            forceBrightness: false,
          );
        }
        return const _Palette(
          brightness: Brightness.light,
          scaffold: Color(0xFFF4F0E6),
          card: Color(0xFFE8E2D4),
          divider: Color(0xFFC8BFB0),
          primary: _lightPrimary,
          secondary: _lightSecondary,
          textPrimary: Color(0xFF2C2621),
          textSecondary: Color(0xFF6B6255),
          forceBrightness: false,
        );
    }
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

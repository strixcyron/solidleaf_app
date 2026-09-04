import 'dart:io';

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// Палитра, извлечённая из баннера/обложки.
class CoverPalette {
  const CoverPalette({this.primary, this.secondary, this.muted});

  final Color? primary;
  final Color? secondary;
  final Color? muted;

  bool get isEmpty => primary == null && secondary == null && muted == null;
}

/// Извлекает акцентные цвета из текущей обложки баннера.
class CoverAccentLoader {
  CoverAccentLoader._();

  static Future<CoverPalette> loadFromProvider(ImageProvider provider) async {
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        provider,
        // Баннер широкий — семплируем в похожих пропорциях.
        size: const Size(160, 90),
        maximumColorCount: 16,
      );
      final primary = palette.vibrantColor?.color ??
          palette.lightVibrantColor?.color ??
          palette.dominantColor?.color ??
          palette.mutedColor?.color;
      final secondary = palette.darkVibrantColor?.color ??
          palette.mutedColor?.color ??
          palette.lightMutedColor?.color ??
          primary;
      final muted = palette.darkMutedColor?.color ??
          palette.dominantColor?.color ??
          secondary;
      return CoverPalette(
        primary: primary,
        secondary: secondary,
        muted: muted,
      );
    } catch (_) {
      return const CoverPalette();
    }
  }

  /// Asset → file → запасной cover.jpg.
  static Future<CoverPalette> load({
    String? assetPath,
    String? filePath,
    List<String> assetFallbacks = const [],
  }) async {
    if (filePath != null && filePath.isNotEmpty) {
      final file = File(filePath);
      if (await file.exists()) {
        final fromFile = await loadFromProvider(FileImage(file));
        if (!fromFile.isEmpty) return fromFile;
      }
    }

    final candidates = <String>[
      if (assetPath != null && assetPath.isNotEmpty) assetPath,
      ...assetFallbacks,
      'assets/images/cover.jpg',
    ];

    for (final path in candidates) {
      final palette = await loadFromProvider(AssetImage(path));
      if (!palette.isEmpty) return palette;
    }
    return const CoverPalette();
  }
}

/// Делает акцент читаемым на светлой/тёмной теме (насыщенность и яркость).
Color normalizeCoverAccent(Color color, {required bool isDark}) {
  final hsl = HSLColor.fromColor(color);
  final saturation = hsl.saturation.clamp(0.42, 0.82);
  final lightness = isDark
      ? hsl.lightness.clamp(0.48, 0.72)
      : hsl.lightness.clamp(0.32, 0.52);
  return hsl.withSaturation(saturation).withLightness(lightness).toColor();
}

/// Смешивает [accent] в [base] с силой [strength] (0–1).
Color blendAccent(Color base, Color? accent, double strength) {
  if (accent == null || strength <= 0) return base;
  return Color.lerp(base, accent, strength.clamp(0.0, 1.0)) ?? base;
}

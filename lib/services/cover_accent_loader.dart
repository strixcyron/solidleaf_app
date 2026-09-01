import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// Extracts a dominant accent color from the hero cover art once at startup.
class CoverAccentLoader {
  CoverAccentLoader._();

  static Future<ui.Color?> load({
    String assetPath = 'assets/images/cover.jpg',
  }) async {
    try {
      final imageProvider = AssetImage(assetPath);
      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 12,
      );
      return palette.vibrantColor?.color ??
          palette.dominantColor?.color ??
          palette.mutedColor?.color;
    } catch (_) {
      return null;
    }
  }
}

/// Blends [accent] into [base] by [strength] (0–1).
ui.Color blendAccent(ui.Color base, ui.Color? accent, double strength) {
  if (accent == null || strength <= 0) return base;
  return ui.Color.lerp(base, accent, strength.clamp(0.0, 1.0)) ?? base;
}

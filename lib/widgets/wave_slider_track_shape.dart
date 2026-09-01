import 'dart:math' as math;

import 'package:flutter/material.dart';
class WaveSliderTrackShape extends SliderTrackShape {
  final double waveHeight; // Р’С‹СЃРѕС‚Р° РІРѕР»РЅС‹
  final double waveLength; // Р”Р»РёРЅР° РІРѕР»РЅС‹ (СЂР°СЃСЃС‚РѕСЏРЅРёРµ РјРµР¶РґСѓ РїРёРєР°РјРё)

  WaveSliderTrackShape({this.waveHeight = 3.0, this.waveLength = 12.0});

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 3.0;
    final double trackLeft = offset.dx;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(trackLeft, trackTop, parentBox.size.width, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final Canvas canvas = context.canvas;
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );

    // РћС‚СЂРёСЃРѕРІРєР° Р°РєС‚РёРІРЅРѕР№ С‡Р°СЃС‚Рё (Р’РѕР»РЅР°)
    final Path activePath = Path();
    activePath.moveTo(trackRect.left, trackRect.centerLeft.dy);

    for (double x = trackRect.left; x <= thumbCenter.dx; x += 1) {
      final double relativeX = x - trackRect.left;
      final double y = trackRect.centerLeft.dy +
          math.sin(relativeX / waveLength * 1 * math.pi) * waveHeight;
      activePath.lineTo(x, y);
    }

    final Paint activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = sliderTheme.trackHeight ?? 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(activePath, activePaint);

    // РћС‚СЂРёСЃРѕРІРєР° РЅРµР°РєС‚РёРІРЅРѕР№ С‡Р°СЃС‚Рё (РџСЂСЏРјР°СЏ Р»РёРЅРёСЏ)
    final Path inactivePath = Path();
    inactivePath.moveTo(thumbCenter.dx, trackRect.centerLeft.dy);
    inactivePath.lineTo(trackRect.right, trackRect.centerLeft.dy);

    final Paint inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.grey
      ..style = PaintingStyle.stroke
      ..strokeWidth = sliderTheme.trackHeight ?? 1.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(inactivePath, inactivePaint);
  }
}

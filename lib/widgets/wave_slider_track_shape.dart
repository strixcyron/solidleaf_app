import 'dart:math' as math;

import 'package:flutter/material.dart';

class WaveSliderTrackShape extends SliderTrackShape {
  final double waveHeight; // Высота волны
  final double waveLength; // Длина волны (расстояние между пиками)

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
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
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
    bool isDiscrete = false,
    bool isEnabled = false,
    required TextDirection textDirection,
  }) {
    final Canvas canvas = context.canvas;
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    // Отрисовка активной части (Волна)
    final Path activePath = Path();
    final double activeWidth = thumbCenter.dx - trackRect.left;
    activePath.moveTo(trackRect.left, trackRect.center.dy);
    for (double x = 0; x < activeWidth; x += 1) {
      final double y = trackRect.center.dy +
          math.sin((x / waveLength) * 2 * math.pi) * waveHeight;
      activePath.lineTo(trackRect.left + x, y);
    }

    final Paint activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? Colors.purple
      ..style = PaintingStyle.stroke
      ..strokeWidth = sliderTheme.trackHeight ?? 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(activePath, activePaint);

    // Отрисовка неактивной части (Прямая линия)
    final Path inactivePath = Path()
      ..moveTo(thumbCenter.dx, trackRect.center.dy)
      ..lineTo(trackRect.right, trackRect.center.dy);

    final Paint inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.grey
      ..style = PaintingStyle.stroke
      ..strokeWidth = sliderTheme.trackHeight ?? 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(inactivePath, inactivePaint);
  }
}

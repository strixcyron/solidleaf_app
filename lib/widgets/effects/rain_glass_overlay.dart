import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Semi-transparent rain-on-glass effect for hero cover art.
class RainGlassOverlay extends StatefulWidget {
  const RainGlassOverlay({super.key});

  @override
  State<RainGlassOverlay> createState() => _RainGlassOverlayState();
}

class _RainGlassOverlayState extends State<RainGlassOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_RainDrop> _drops;
  late final List<_RainStreak> _streaks;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);
    _drops = List.generate(
      48,
      (i) => _RainDrop(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: 1.2 + rng.nextDouble() * 2.4,
        speed: 0.08 + rng.nextDouble() * 0.14,
        phase: rng.nextDouble() * math.pi * 2,
      ),
    );
    _streaks = List.generate(
      6,
      (i) => _RainStreak(
        x: rng.nextDouble(),
        delay: i * 0.17,
        length: 28 + rng.nextDouble() * 36,
        speed: 0.35 + rng.nextDouble() * 0.25,
      ),
    );
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _RainGlassPainter(
              t: _controller.value,
              drops: _drops,
              streaks: _streaks,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _RainDrop {
  _RainDrop({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.phase,
  });

  final double x;
  final double y;
  final double radius;
  final double speed;
  final double phase;
}

class _RainStreak {
  _RainStreak({
    required this.x,
    required this.delay,
    required this.length,
    required this.speed,
  });

  final double x;
  final double delay;
  final double length;
  final double speed;
}

class _RainGlassPainter extends CustomPainter {
  _RainGlassPainter({
    required this.t,
    required this.drops,
    required this.streaks,
  });

  final double t;
  final List<_RainDrop> drops;
  final List<_RainStreak> streaks;

  @override
  void paint(Canvas canvas, Size size) {
    final glassTint = Paint()
      ..color = const Color(0xFF8BA4C4).withValues(alpha: 0.04);
    canvas.drawRect(Offset.zero & size, glassTint);

    for (final drop in drops) {
      final dy = (drop.y + t * drop.speed) % 1.0;
      final wobble = math.sin(t * math.pi * 2 + drop.phase) * 2;
      final center = Offset(
        drop.x * size.width + wobble,
        dy * size.height,
      );
      final opacity = 0.18 + math.sin(drop.phase + t * 4) * 0.08;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity.clamp(0.08, 0.32))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6);
      canvas.drawCircle(center, drop.radius, paint);
    }

    for (final streak in streaks) {
      final cycle = ((t + streak.delay) % 1.0);
      if (cycle > 0.55) continue;
      final progress = cycle / 0.55;
      final x = streak.x * size.width;
      final y = progress * (size.height + streak.length) - streak.length;
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(x - 1, y, 2, streak.length))
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(x, y), Offset(x, y + streak.length), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RainGlassPainter oldDelegate) =>
      oldDelegate.t != t;
}

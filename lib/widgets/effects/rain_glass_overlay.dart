import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Живой эффект «дождь по стеклу» с грозовой атмосферой для hero-обложки.
/// Слои: вспышки молний, вертикальный быстрый дождь (два плана глубины),
/// брызги внизу, стекающие капли со следом и прилипшие к стеклу капли-бусины.
///
/// Реализация намеренно без `MaskFilter.blur` — размытие на каждом элементе
/// каждый кадр сильно тормозит; мягкость капель имитируется слоями заливок.
class RainGlassOverlay extends StatefulWidget {
  const RainGlassOverlay({super.key});

  @override
  State<RainGlassOverlay> createState() => _RainGlassOverlayState();
}

class _RainGlassOverlayState extends State<RainGlassOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_GlassBead> _beads;
  late final List<_RunningDrop> _runners;
  late final List<_FallingRain> _rainFar;
  late final List<_FallingRain> _rainNear;
  late final List<_Splash> _splashes;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);

    _beads = List.generate(
      18,
      (i) => _GlassBead(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: 1.6 + rng.nextDouble() * 3.2,
        phase: rng.nextDouble() * math.pi * 2,
        jitter: 0.4 + rng.nextDouble() * 0.9,
      ),
    );

    _runners = List.generate(
      9,
      (i) => _RunningDrop(
        x: rng.nextDouble(),
        startY: rng.nextDouble() * 0.4,
        delay: rng.nextDouble(),
        speed: 0.6 + rng.nextDouble() * 0.9,
        headRadius: 2.4 + rng.nextDouble() * 3.0,
        drift: (rng.nextDouble() - 0.5) * 14,
        wobblePhase: rng.nextDouble() * math.pi * 2,
      ),
    );

    // Дальний план дождя — короткие, почти вертикальные, слабые штрихи.
    _rainFar = List.generate(
      22,
      (i) => _FallingRain(
        x: rng.nextDouble() * 1.1 - 0.05,
        delay: rng.nextDouble(),
        speed: 3.0 + rng.nextDouble() * 1.4,
        length: 4 + rng.nextDouble() * 5,
        slant: 0.3 + rng.nextDouble() * 0.8,
        alpha: 0.05 + rng.nextDouble() * 0.05,
        width: 0.8,
      ),
    );

    // Ближний план — короткие быстрые вертикальные штрихи, чуть ярче.
    _rainNear = List.generate(
      13,
      (i) => _FallingRain(
        x: rng.nextDouble() * 1.1 - 0.05,
        delay: rng.nextDouble(),
        speed: 4.5 + rng.nextDouble() * 2.2,
        length: 8 + rng.nextDouble() * 8,
        slant: 0.6 + rng.nextDouble() * 1.2,
        alpha: 0.10 + rng.nextDouble() * 0.10,
        width: 1.2,
      ),
    );

    // Брызги у нижнего края стекла.
    _splashes = List.generate(
      6,
      (i) => _Splash(
        x: 0.05 + rng.nextDouble() * 0.9,
        y: 0.72 + rng.nextDouble() * 0.24,
        delay: rng.nextDouble(),
        speed: 0.9 + rng.nextDouble() * 0.8,
        maxRadius: 6 + rng.nextDouble() * 10,
      ),
    );

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary изолирует перерисовку оверлея от остального экрана.
    return RepaintBoundary(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _RainGlassPainter(
                t: _controller.value,
                beads: _beads,
                runners: _runners,
                rainFar: _rainFar,
                rainNear: _rainNear,
                splashes: _splashes,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _GlassBead {
  _GlassBead({
    required this.x,
    required this.y,
    required this.radius,
    required this.phase,
    required this.jitter,
  });

  final double x;
  final double y;
  final double radius;
  final double phase;
  final double jitter;
}

class _RunningDrop {
  _RunningDrop({
    required this.x,
    required this.startY,
    required this.delay,
    required this.speed,
    required this.headRadius,
    required this.drift,
    required this.wobblePhase,
  });

  final double x;
  final double startY;
  final double delay;
  final double speed;
  final double headRadius;
  final double drift;
  final double wobblePhase;
}

class _FallingRain {
  _FallingRain({
    required this.x,
    required this.delay,
    required this.speed,
    required this.length,
    required this.slant,
    required this.alpha,
    required this.width,
  });

  final double x;
  final double delay;
  final double speed;
  final double length;
  final double slant;
  final double alpha;
  final double width;
}

class _Splash {
  _Splash({
    required this.x,
    required this.y,
    required this.delay,
    required this.speed,
    required this.maxRadius,
  });

  final double x;
  final double y;
  final double delay;
  final double speed;
  final double maxRadius;
}

class _RainGlassPainter extends CustomPainter {
  _RainGlassPainter({
    required this.t,
    required this.beads,
    required this.runners,
    required this.rainFar,
    required this.rainNear,
    required this.splashes,
  });

  final double t;
  final List<_GlassBead> beads;
  final List<_RunningDrop> runners;
  final List<_FallingRain> rainFar;
  final List<_FallingRain> rainNear;
  final List<_Splash> splashes;

  @override
  void paint(Canvas canvas, Size size) {
    final flash = _lightning(t);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF8BA4C4).withValues(alpha: 0.035),
    );
    if (flash > 0.01) {
      _paintLightning(canvas, size, flash);
    }

    _paintRain(canvas, size, rainFar, flash);
    _paintSplashes(canvas, size);
    _paintRain(canvas, size, rainNear, flash);
    _paintRunningDrops(canvas, size, flash);
    _paintBeads(canvas, size, flash);
  }

  /// Значение вспышки молнии 0..1 (несколько резких мерцаний за цикл).
  double _lightning(double t) {
    double f = 0;
    for (final c in const [0.16, 0.55, 0.83]) {
      final d = (t - c).abs();
      final spike = math.exp(-d * 42);
      final flicker = 0.55 + 0.45 * math.sin(t * 150 + c * 30);
      f = math.max(f, spike * flicker);
    }
    return f.clamp(0.0, 1.0);
  }

  void _paintLightning(Canvas canvas, Size size, double flash) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFDCE6FF).withValues(alpha: 0.26 * flash),
          const Color(0xFFAFC4F0).withValues(alpha: 0.10 * flash),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  /// Вертикальный быстрый дождь. Яркость усиливается вспышкой молнии.
  void _paintRain(
    Canvas canvas,
    Size size,
    List<_FallingRain> rain,
    double flash,
  ) {
    for (final r in rain) {
      final cycle = ((t + r.delay) * r.speed) % 1.0;
      final y = cycle * (size.height + r.length) - r.length;
      final x = r.x * size.width;
      final a = (r.alpha + flash * 0.18).clamp(0.0, 0.5);
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: a)
        ..strokeWidth = r.width
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, y), Offset(x + r.slant, y + r.length), paint);
    }
  }

  /// Брызги — расходящиеся кольца у нижнего края стекла.
  void _paintSplashes(Canvas canvas, Size size) {
    for (final s in splashes) {
      final cycle = ((t + s.delay) * s.speed) % 1.0;
      if (cycle > 0.5) continue;
      final p = cycle / 0.5;
      final radius = p * s.maxRadius;
      final alpha = (1 - p) * 0.28;
      final center = Offset(s.x * size.width, s.y * size.height);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      if (p < 0.3) {
        canvas.drawCircle(
          center,
          1.2,
          Paint()..color = Colors.white.withValues(alpha: (0.3 - p) * 0.8),
        );
      }
    }
  }

  /// Стекающие капли: сужающийся след, остаточные капельки и объёмная голова.
  void _paintRunningDrops(Canvas canvas, Size size, double flash) {
    for (final d in runners) {
      final raw = ((t + d.delay) * d.speed) % 1.0;
      final progress = math.pow(raw, 1.35).toDouble();

      final startY = d.startY * size.height;
      final headY = startY + progress * (size.height - startY);
      final wobble = math.sin(t * math.pi * 2 + d.wobblePhase) * 1.4;
      final headX = d.x * size.width + d.drift * progress + wobble;

      final trailTop = startY;
      if (headY <= trailTop + 2) continue;

      final trailRect = Rect.fromLTWH(
        headX - d.headRadius,
        trailTop,
        d.headRadius * 2,
        headY - trailTop,
      );
      final trailPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.07 + flash * 0.06),
            Colors.white.withValues(alpha: 0.16 + flash * 0.10),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(trailRect)
        ..strokeWidth = d.headRadius * 0.8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(headX, trailTop), Offset(headX, headY), trailPaint);

      const residualCount = 3;
      for (var i = 1; i <= residualCount; i++) {
        final f = i / (residualCount + 1);
        final ry = trailTop + (headY - trailTop) * f;
        final rr = d.headRadius * (0.28 + 0.22 * (1 - f));
        _drawBead(canvas, Offset(headX, ry), rr, 0.7 * f + 0.3, flash);
      }

      _drawBead(canvas, Offset(headX, headY), d.headRadius, 1.0, flash);
    }
  }

  /// Прилипшие к стеклу капли, слегка подрагивающие на месте.
  void _paintBeads(Canvas canvas, Size size, double flash) {
    for (final b in beads) {
      final jx = math.sin(t * math.pi * 2 + b.phase) * b.jitter;
      final jy = math.cos(t * math.pi * 2 + b.phase * 1.3) * b.jitter * 0.6;
      final center = Offset(b.x * size.width + jx, b.y * size.height + jy);
      final breathe = 0.85 + 0.15 * math.sin(t * math.pi * 2 + b.phase);
      _drawBead(canvas, center, b.radius, breathe, flash);
    }
  }

  /// Рисует объёмную каплю воды без размытия: мягкое тело двумя слоями,
  /// тёмный ободок преломления, светлый контур и яркий блик.
  void _drawBead(Canvas canvas, Offset c, double r, double alpha, double flash) {
    if (r < 0.6) return;

    // Тело-линза: два вложенных полупрозрачных круга дают мягкость без блюра.
    canvas.drawCircle(
      c,
      r,
      Paint()..color = Colors.white.withValues(alpha: 0.06 * alpha),
    );
    canvas.drawCircle(
      c,
      r * 0.68,
      Paint()..color = Colors.white.withValues(alpha: 0.07 * alpha),
    );

    // Тёмный ободок преломления (нижняя-правая дуга).
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.85),
      0.15,
      math.pi * 0.95,
      false,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, r * 0.3)
        ..strokeCap = StrokeCap.round,
    );

    // Светлый контур сверху-слева.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.85),
      math.pi * 1.15,
      math.pi * 0.9,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.4, r * 0.16),
    );

    // Яркий блик (вспыхивает при молнии).
    canvas.drawCircle(
      c.translate(-r * 0.32, -r * 0.36),
      math.max(0.5, r * 0.22),
      Paint()..color = Colors.white.withValues(alpha: (0.6 + flash * 0.35) * alpha),
    );
  }

  @override
  bool shouldRepaint(covariant _RainGlassPainter oldDelegate) =>
      oldDelegate.t != t;
}

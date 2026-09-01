import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One-shot golden confetti burst overlay (~1 second).
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    this.duration = const Duration(milliseconds: 1000),
    this.onComplete,
  });

  final Duration duration;
  final VoidCallback? onComplete;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _particles = List.generate(56, (i) {
      final angle = rng.nextDouble() * math.pi * 2;
      final speed = 120 + rng.nextDouble() * 220;
      return _ConfettiParticle(
        originX: 0.5 + (rng.nextDouble() - 0.5) * 0.15,
        originY: 0.42 + (rng.nextDouble() - 0.5) * 0.08,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 80,
        size: 4 + rng.nextDouble() * 5,
        rotation: rng.nextDouble() * math.pi,
        spin: (rng.nextDouble() - 0.5) * 8,
        color: _colors[rng.nextInt(_colors.length)],
      );
    });
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward().whenComplete(() {
        widget.onComplete?.call();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _colors = [
    Color(0xFFC9A227),
    Color(0xFFE8C547),
    Color(0xFF7B52F4),
    Color(0xFFFFFFFF),
    Color(0xFFD97706),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _ConfettiPainter(
              t: Curves.easeOutCubic.transform(_controller.value),
              particles: _particles,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _ConfettiParticle {
  _ConfettiParticle({
    required this.originX,
    required this.originY,
    required this.vx,
    required this.vy,
    required this.size,
    required this.rotation,
    required this.spin,
    required this.color,
  });

  final double originX;
  final double originY;
  final double vx;
  final double vy;
  final double size;
  final double rotation;
  final double spin;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.t, required this.particles});

  final double t;
  final List<_ConfettiParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    const gravity = 420.0;
    final opacity = (1 - t).clamp(0.0, 1.0);

    for (final p in particles) {
      final x = p.originX * size.width + p.vx * t;
      final y = p.originY * size.height + p.vy * t + 0.5 * gravity * t * t;
      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity * 0.9);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.spin * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.55,
          ),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t;
}

/// Shows confetti over the current route, waits, then returns.
Future<void> showConfettiBurst(
  BuildContext context, {
  Duration duration = const Duration(milliseconds: 1000),
}) async {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  final completer = Completer<void>();

  entry = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: ConfettiBurst(
        duration: duration,
        onComplete: () {
          if (entry.mounted) {
            entry.remove();
          }
          if (!completer.isCompleted) completer.complete();
        },
      ),
    ),
  );

  overlay.insert(entry);
  await completer.future;
}

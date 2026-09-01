import 'package:flutter/material.dart';

/// Animated dashed border that appears on hover — arcane / magical feel.
class ArcaneHoverBorder extends StatefulWidget {
  const ArcaneHoverBorder({
    super.key,
    required this.child,
    this.borderRadius = 12,
    this.strokeWidth = 1.4,
    this.color,
    this.enabled = true,
  });

  final Widget child;
  final double borderRadius;
  final double strokeWidth;
  final Color? color;
  final bool enabled;

  @override
  State<ArcaneHoverBorder> createState() => _ArcaneHoverBorderState();
}

class _ArcaneHoverBorderState extends State<ArcaneHoverBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setHovered(bool value) {
    if (!widget.enabled || _hovered == value) return;
    setState(() => _hovered = value);
    if (value) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            foregroundPainter: _hovered
                ? _ArcaneBorderPainter(
                    progress: _controller.value,
                    color: color,
                    borderRadius: widget.borderRadius,
                    strokeWidth: widget.strokeWidth,
                  )
                : null,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _ArcaneBorderPainter extends CustomPainter {
  _ArcaneBorderPainter({
    required this.progress,
    required this.color,
    required this.borderRadius,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double borderRadius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    const dashLength = 7.0;
    const gapLength = 5.0;
    final offset = progress * (dashLength + gapLength);

    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    double distance = -offset;
    while (distance < metric.length) {
      final start = distance.clamp(0.0, metric.length);
      final end = (distance + dashLength).clamp(0.0, metric.length);
      if (end > start) {
        canvas.drawPath(metric.extractPath(start, end), paint);
      }
      distance += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _ArcaneBorderPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.borderRadius != borderRadius;
}

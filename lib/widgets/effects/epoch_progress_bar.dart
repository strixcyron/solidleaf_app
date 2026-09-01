import 'package:flutter/material.dart';

/// Download progress bar with shimmer and a brief golden flash at 100%.
class EpochProgressBar extends StatefulWidget {
  const EpochProgressBar({
    super.key,
    required this.progress,
    this.label,
    this.height = 6,
    this.indeterminate = false,
  });

  final double progress;
  final String? label;
  final double height;
  final bool indeterminate;

  @override
  State<EpochProgressBar> createState() => _EpochProgressBarState();
}

class _EpochProgressBarState extends State<EpochProgressBar>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerController;
  late final AnimationController _flashController;
  double _lastProgress = 0;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _lastProgress = widget.progress;
  }

  @override
  void didUpdateWidget(covariant EpochProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_lastProgress < 1 && widget.progress >= 1) {
      _flashController.forward(from: 0);
    }
    _lastProgress = widget.progress;
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final trackColor = theme.dividerColor;
    final value = widget.indeterminate ? null : widget.progress.clamp(0.0, 1.0);
    final pct = widget.indeterminate
        ? null
        : (widget.progress * 100).clamp(0, 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null || pct != null) ...[
          Text(
            widget.label ??
                (pct != null ? 'Загрузка архива… $pct%' : 'Загрузка архива…'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 6),
        ],
        AnimatedBuilder(
          animation: Listenable.merge([_shimmerController, _flashController]),
          builder: (context, _) {
            final flash = _flashController.value;
            final flashColor = Color.lerp(
              primary,
              const Color(0xFFC9A227),
              flash,
            )!;

            return ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: widget.height,
                child: CustomPaint(
                  painter: _EpochProgressPainter(
                    value: value,
                    trackColor: trackColor,
                    fillColor: flashColor,
                    shimmerT: _shimmerController.value,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _EpochProgressPainter extends CustomPainter {
  _EpochProgressPainter({
    required this.value,
    required this.trackColor,
    required this.fillColor,
    required this.shimmerT,
  });

  final double? value;
  final Color trackColor;
  final Color fillColor;
  final double shimmerT;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );
    canvas.drawRRect(track, Paint()..color = trackColor);

    final fillWidth = value == null
        ? size.width * (0.25 + shimmerT * 0.5)
        : size.width * value!.clamp(0.0, 1.0);
    if (fillWidth <= 0) return;

    final fillRect = Rect.fromLTWH(0, 0, fillWidth, size.height);
    final fillPaint = Paint()..color = fillColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(fillRect, const Radius.circular(4)),
      fillPaint,
    );

    final shimmerX = fillWidth * shimmerT;
    final shimmerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(shimmerX - 40, 0, 80, size.height));
    canvas.drawRect(fillRect, shimmerPaint);
  }

  @override
  bool shouldRepaint(covariant _EpochProgressPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.shimmerT != shimmerT;
}

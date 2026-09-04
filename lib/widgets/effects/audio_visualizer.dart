import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Эквалайзер: при [expanded] тянется на всю ширину с большим числом полос.
class AudioVisualizer extends StatefulWidget {
  const AudioVisualizer({
    super.key,
    required this.isPlaying,
    this.barCount = 7,
    this.height = 22,
    this.color,
    this.expanded = false,
  });

  final bool isPlaying;
  final int barCount;
  final double height;
  final Color? color;
  final bool expanded;

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<double> _phases;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(7);
    final count = widget.expanded ? 24 : widget.barCount;
    _phases = List.generate(count, (_) => rng.nextDouble() * math.pi);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _sync();
  }

  @override
  void didUpdateWidget(covariant AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded ||
        oldWidget.barCount != widget.barCount) {
      final rng = math.Random(7);
      final count = widget.expanded ? 24 : widget.barCount;
      _phases = List.generate(count, (_) => rng.nextDouble() * math.pi);
    }
    _sync();
  }

  void _sync() {
    if (widget.isPlaying) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final count = widget.expanded ? 24 : widget.barCount;
    final barWidth = widget.expanded ? 4.0 : 3.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final row = Row(
          mainAxisAlignment: widget.expanded
              ? MainAxisAlignment.spaceEvenly
              : MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(count, (i) {
            final phase = i < _phases.length ? _phases[i] : i * 0.4;
            final t = _controller.value * math.pi * 2;
            final wave = widget.isPlaying
                ? (0.35 + 0.65 * ((math.sin(t + phase + i * 0.55).abs())))
                : 0.18;
            final barHeight = widget.height * wave;

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.expanded ? 1.5 : 3,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: barWidth,
                height: barHeight,
                decoration: BoxDecoration(
                  color: color.withValues(
                    alpha: widget.isPlaying ? 0.85 : 0.35,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        );

        return SizedBox(
          height: widget.height,
          width: widget.expanded ? double.infinity : null,
          child: row,
        );
      },
    );
  }
}

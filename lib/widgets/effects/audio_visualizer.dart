import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Simple audio bar visualizer (5–7 bars) synced to playback state.
class AudioVisualizer extends StatefulWidget {
  const AudioVisualizer({
    super.key,
    required this.isPlaying,
    this.barCount = 7,
    this.height = 22,
    this.color,
  });

  final bool isPlaying;
  final int barCount;
  final double height;
  final Color? color;

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<double> _phases;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(7);
    _phases = List.generate(widget.barCount, (_) => rng.nextDouble() * math.pi);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _sync();
  }

  @override
  void didUpdateWidget(covariant AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
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

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.barCount, (i) {
              final t = _controller.value * math.pi * 2;
              final wave = widget.isPlaying
                  ? (0.35 +
                      0.65 *
                          ((math.sin(t + _phases[i] + i * 0.7).abs())))
                  : 0.18;
              final barHeight = widget.height * wave;

              return Padding(
                padding: EdgeInsets.only(
                  left: i == 0 ? 0 : 3,
                  right: i == widget.barCount - 1 ? 0 : 3,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 3,
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
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

enum StatusBadgeKind { updateAvailable, installed, neutral }

/// Animated version/status badge with pulse glow or check scale.
class AnimatedStatusBadge extends StatefulWidget {
  const AnimatedStatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    required this.kind,
    this.compact = false,
  });

  final String label;
  final Color color;
  final IconData icon;
  final StatusBadgeKind kind;
  final bool compact;

  @override
  State<AnimatedStatusBadge> createState() => _AnimatedStatusBadgeState();
}

class _AnimatedStatusBadgeState extends State<AnimatedStatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant AnimatedStatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.kind == StatusBadgeKind.updateAvailable) {
      _controller.repeat(reverse: true);
    } else if (widget.kind == StatusBadgeKind.installed) {
      _controller.forward(from: 0);
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
    final padH = widget.compact ? 10.0 : 12.0;
    final padV = widget.compact ? 6.0 : 7.0;
    final fontSize = widget.compact ? 11.0 : 12.0;
    final iconSize = widget.compact ? 14.0 : 15.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glow = widget.kind == StatusBadgeKind.updateAvailable
            ? 0.25 + _controller.value * 0.35
            : 0.18;
        final scale = widget.kind == StatusBadgeKind.installed
            ? 0.6 + Curves.elasticOut.transform(_controller.value) * 0.4
            : 1.0;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: glow),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: widget.color, width: 1),
            boxShadow: widget.kind == StatusBadgeKind.updateAvailable
                ? [
                    BoxShadow(
                      color: widget.color.withValues(
                        alpha: 0.25 + _controller.value * 0.35,
                      ),
                      blurRadius: 10 + _controller.value * 8,
                      spreadRadius: _controller.value * 1.5,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: scale,
                child: Icon(widget.icon, color: widget.color, size: iconSize),
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.color,
                  fontWeight: FontWeight.w700,
                  fontSize: fontSize,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

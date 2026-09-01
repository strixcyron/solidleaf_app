import 'dart:io';

import 'package:flutter/material.dart';

/// Subtle magnetic pull toward the cursor (desktop only).
class MagneticHover extends StatefulWidget {
  const MagneticHover({
    super.key,
    required this.child,
    this.strength = 3,
    this.enabled,
  });

  final Widget child;
  final double strength;
  final bool? enabled;

  @override
  State<MagneticHover> createState() => _MagneticHoverState();
}

class _MagneticHoverState extends State<MagneticHover> {
  Offset _offset = Offset.zero;
  final GlobalKey _key = GlobalKey();

  bool get _active {
    if (widget.enabled != null) return widget.enabled!;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  void _onHover(PointerEvent event) {
    if (!_active) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final local = box.globalToLocal(event.position);
    final center = box.size.center(Offset.zero);
    final delta = local - center;
    final maxPull = widget.strength;
    setState(() {
      _offset = Offset(
        (delta.dx / box.size.width * maxPull).clamp(-maxPull, maxPull),
        (delta.dy / box.size.height * maxPull).clamp(-maxPull, maxPull),
      );
    });
  }

  void _onExit() {
    if (_offset == Offset.zero) return;
    setState(() => _offset = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: _onHover,
      onExit: (_) => _onExit(),
      child: AnimatedContainer(
        key: _key,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(_offset.dx, _offset.dy, 0),
        child: widget.child,
      ),
    );
  }
}

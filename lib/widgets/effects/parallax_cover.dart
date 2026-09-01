import 'dart:io';

import 'package:flutter/material.dart';

/// Subtle parallax shift for album/cover art on desktop.
class ParallaxCover extends StatefulWidget {
  const ParallaxCover({
    super.key,
    required this.child,
    this.maxOffset = 3.5,
    this.enabled,
  });

  final Widget child;
  final double maxOffset;
  final bool? enabled;

  @override
  State<ParallaxCover> createState() => _ParallaxCoverState();
}

class _ParallaxCoverState extends State<ParallaxCover> {
  Offset _offset = Offset.zero;

  bool get _active {
    if (widget.enabled != null) return widget.enabled!;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return widget.child;

    return MouseRegion(
      onHover: (event) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(event.position);
        final nx = (local.dx / box.size.width - 0.5) * 2;
        final ny = (local.dy / box.size.height - 0.5) * 2;
        final next = Offset(
          nx * widget.maxOffset,
          ny * widget.maxOffset,
        );
        if (next != _offset) setState(() => _offset = next);
      },
      onExit: (_) {
        if (_offset != Offset.zero) setState(() => _offset = Offset.zero);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(_offset.dx, _offset.dy, 0),
        child: widget.child,
      ),
    );
  }
}

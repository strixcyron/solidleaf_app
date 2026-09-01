import 'package:flutter/material.dart';

/// Fade + slide-in with staggered delay per child index.
class StaggeredFadeIn extends StatefulWidget {
  const StaggeredFadeIn({
    super.key,
    required this.index,
    required this.child,
    this.delayPerItem = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 420),
    this.slideOffset = const Offset(0, 12),
  });

  final int index;
  final Widget child;
  final Duration delayPerItem;
  final Duration duration;
  final Offset slideOffset;

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: widget.slideOffset,
      end: Offset.zero,
    ).animate(_fade);

    Future<void>.delayed(
      widget.delayPerItem * widget.index,
      () {
        if (mounted) _controller.forward();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

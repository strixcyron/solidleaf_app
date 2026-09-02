import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/animated_covers.dart';

/// Обложка баннера с поддержкой видео.
///
/// На Android пытается проиграть mp4 через `video_player` (зациклено, без
/// звука). Если видео нет/не поддерживается, а также на всех остальных
/// платформах — показывается [imageFallback] (webp → gif → статичная).
class AnimatedCoverView extends StatefulWidget {
  const AnimatedCoverView({
    super.key,
    required this.cover,
    required this.imageFallback,
  });

  final AnimatedCover cover;

  /// Отрисовка обложки без видео (анимированные webp/gif или статичная).
  final Widget imageFallback;

  @override
  State<AnimatedCoverView> createState() => _AnimatedCoverViewState();
}

class _AnimatedCoverViewState extends State<AnimatedCoverView> {
  VideoPlayerController? _controller;
  bool _videoReady = false;
  bool _videoFailed = false;

  // Видео подключаем только для Android — по требованию.
  bool get _useVideo => Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    if (_useVideo) _initVideo();
  }

  @override
  void didUpdateWidget(covariant AnimatedCoverView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Сменили вариант обложки — пересоздаём плеер.
    if (_useVideo && oldWidget.cover.mp4 != widget.cover.mp4) {
      _disposeVideo();
      _videoReady = false;
      _videoFailed = false;
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.asset(widget.cover.mp4);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _videoReady = true);
    } catch (_) {
      // Файла нет или формат не поддерживается — откат на изображение.
      controller.dispose();
      if (_controller == controller) _controller = null;
      if (mounted) setState(() => _videoFailed = true);
    }
  }

  void _disposeVideo() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_useVideo && _videoReady && !_videoFailed && controller != null) {
      // Растягиваем видео по размеру баннера с обрезкой (cover).
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      );
    }
    return widget.imageFallback;
  }
}

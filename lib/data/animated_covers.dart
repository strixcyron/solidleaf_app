/// Вариант анимированной обложки. Файлы кладутся в assets/video/
/// в формате .webp (приоритет) или .gif. Если файла нет — используется
/// статичная обложка.
class AnimatedCover {
  const AnimatedCover({
    required this.id,
    required this.label,
    required this.asset,
  });

  /// Порядковый идентификатор (совпадает с индексом в списке).
  final int id;

  /// Название для отображения в настройках.
  final String label;

  /// Базовый путь без расширения, например assets/video/cover1.
  final String asset;

  /// Полный путь к .mp4-версии (используется через video_player на Android).
  String get mp4 => '$asset.mp4';

  /// Полный путь к .webp-версии.
  String get webp => '$asset.webp';

  /// Полный путь к .gif-версии (запасной вариант).
  String get gif => '$asset.gif';
}

/// Семь доступных анимированных обложек.
const List<AnimatedCover> animatedCovers = [
  AnimatedCover(id: 0, label: 'Обложка 1', asset: 'assets/video/cover1'),
  AnimatedCover(id: 1, label: 'Обложка 2', asset: 'assets/video/cover2'),
  AnimatedCover(id: 2, label: 'Обложка 3', asset: 'assets/video/cover3'),
  AnimatedCover(id: 3, label: 'Обложка 4', asset: 'assets/video/cover4'),
  AnimatedCover(id: 4, label: 'Обложка 5', asset: 'assets/video/cover5'),
  AnimatedCover(id: 5, label: 'Обложка 6', asset: 'assets/video/cover6'),
  AnimatedCover(id: 6, label: 'Обложка 7', asset: 'assets/video/cover7'),
];

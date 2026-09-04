/// Статичные обложки (до 10 слотов) + путь для пользовательской картинки.
class StaticCover {
  const StaticCover({
    required this.id,
    required this.label,
    required this.asset,
  });

  final int id;
  final String label;
  /// Asset-путь; для слота «своя» — пустая строка.
  final String asset;
}

/// Доступные статичные обложки из ассетов (webp/jpg).
const List<StaticCover> staticCovers = [
  StaticCover(id: 0, label: 'Классика', asset: 'assets/images/cover.jpg'),
  StaticCover(id: 1, label: 'Обложка 1', asset: 'assets/video/cover1.webp'),
  StaticCover(id: 2, label: 'Обложка 2', asset: 'assets/video/cover2.webp'),
  StaticCover(id: 3, label: 'Обложка 3', asset: 'assets/video/cover3.webp'),
  StaticCover(id: 4, label: 'Обложка 4', asset: 'assets/video/cover4.webp'),
  StaticCover(id: 5, label: 'Обложка 5', asset: 'assets/video/cover5.webp'),
  StaticCover(id: 6, label: 'Обложка 6', asset: 'assets/video/cover6.webp'),
  StaticCover(id: 7, label: 'Обложка 7', asset: 'assets/video/cover1.webp'),
  StaticCover(id: 8, label: 'Обложка 8', asset: 'assets/video/cover3.webp'),
  StaticCover(id: 9, label: 'Обложка 9', asset: 'assets/video/cover5.webp'),
];

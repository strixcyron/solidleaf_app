/// Текущая версия лаунчера (для логики/сравнений).
const String launcherVersion = '0.2-alpha';

/// Подпись в UI: «alpha v0.2» (ещё не стабильный v1.0).
const String launcherVersionLabel = 'alpha v0.2';

/// Одна запись истории версий лаунчера.
class LauncherRelease {
  const LauncherRelease({
    required this.version,
    required this.date,
    required this.changes,
  });

  final String version;
  final String date;
  final List<String> changes;
}

/// История версий лаунчера — новые релизы добавляйте в НАЧАЛО списка.
const List<LauncherRelease> launcherChangelog = [
  LauncherRelease(
    version: '0.2-alpha',
    date: 'Сентябрь 2026',
    changes: [
      'Кнопка «Запустить игру»: при установленной текстовой локализации '
          'и отсутствующих текстурах — предложение доустановить графику '
          'или продолжить запуск.',
      'Автопоиск игры на ПК: вложенный путь '
          'Games\\reverse1999_global\\Reverse1999en, разные диски и Steam; '
          'выбор более «живой» копии при нескольких установках.',
      'Удаление компонентов по отдельности: иконка корзины на карточках '
          'текста и графики, без общего меню с выбором типа удаления.',
      'На Android: запуск пакета игры; в манифесте объявлена видимость '
          'пакета Reverse: 1999 (Android 11+).',
      'Устойчивее Shizuku на HyperOS / Redmi / Infinix: мягкий bind '
          'UserService (без destroy на каждой попытке), запасная запись '
          'через tmp+rename, проверка записи до установки.',
      'Диалог «Что нового?» по русификатору — в стиле инструкции Shizuku '
          '(нижний лист), кнопка заметнее на фоне.',
      'Приветствие при первом запуске, вход через Telegram, Premium-графика.',
      'Установка и обновление текста на Windows и Android; музыкальный '
          'плеер; страница «О проекте»; темы и визуальные эффекты.',
    ],
  ),
  LauncherRelease(
    version: '0.1-alpha',
    date: 'Август 2026',
    changes: [
      'Первая внутренняя альфа-сборка лаунчера SolidLeaf.',
      'Базовая установка текстовой локализации и работа с Shizuku.',
    ],
  ),
];

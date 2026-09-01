import 'dart:io';

import 'package:path/path.dart' as p;

/// Поиск папки установки Reverse: 1999 на ПК (Windows).
class GamePathFinder {
  GamePathFinder._();

  /// Ключ в SharedPreferences для пути, выбранного пользователем.
  static const prefsKey = 'install_path';

  /// Папка данных Unity — надёжный признак корня установки игры.
  static const _dataFolderName = 'reverse1999_Data';

  /// Типичные пути от корня диска: глобальная и Steam-версия.
  static const _relativeCandidates = <String>[
    r'Games\reverse1999_global',
    r'Steam\steamapps\common\Reverse 1999',
  ];

  /// Проверяет, что в [dirPath] лежит установленная игра.
  static bool isValidGamePath(String dirPath) {
    if (dirPath.isEmpty || dirPath.startsWith('Укажите')) {
      return false;
    }
    return Directory(p.join(dirPath, _dataFolderName)).existsSync();
  }

  /// Перебирает диски C:–Z: и ищет игру по [_relativeCandidates].
  static Future<String?> findWindowsGamePath() async {
    if (!Platform.isWindows) {
      return null;
    }

    for (final drive in _availableDriveLetters()) {
      for (final relative in _relativeCandidates) {
        final candidate = p.normalize(p.join('$drive:\\', relative));
        if (isValidGamePath(candidate)) {
          return candidate;
        }
      }
    }
    return null;
  }

  /// Буквы подключённых локальных дисков.
  static Iterable<String> _availableDriveLetters() sync* {
    for (var code = 'A'.codeUnitAt(0); code <= 'Z'.codeUnitAt(0); code++) {
      final letter = String.fromCharCode(code);
      final root = '$letter:\\';
      try {
        if (Directory(root).existsSync()) {
          yield letter;
        }
      } catch (_) {
        // Нет доступа к диску — пропускаем.
      }
    }
  }
}

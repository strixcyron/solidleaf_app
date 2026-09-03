import 'dart:io';

import 'package:path/path.dart' as p;

/// Поиск папки установки Reverse: 1999 на ПК (Windows).
class GamePathFinder {
  GamePathFinder._();

  /// Ключ в SharedPreferences для пути, выбранного пользователем (только Windows).
  static const prefsKey = 'install_path';

  /// Фиксированный путь к данным игры на Android — выбор папки не нужен.
  static const androidInstallPath =
      '/storage/emulated/0/Android/data/com.bluepoch.m.en.reverse1999/';

  /// Папка данных Unity — обязательный признак корня установки на Windows.
  static const dataFolderName = 'reverse1999_Data';

  /// Возможные имена exe в корне игры.
  static const _exeCandidates = <String>[
    'Reverse1999.exe',
    'reverse1999.exe',
    'Reverse 1999.exe',
  ];

  /// Типичные пути от корня диска: глобальная и Steam-версия.
  static const _relativeCandidates = <String>[
    r'Games\reverse1999_global',
    r'Games\Reverse 1999',
    r'Program Files\Steam\steamapps\common\Reverse 1999',
    r'Program Files (x86)\Steam\steamapps\common\Reverse 1999',
    r'Steam\steamapps\common\Reverse 1999',
    r'SteamLibrary\steamapps\common\Reverse 1999',
  ];

  /// Проверяет, что путь установки подходит для текущей платформы.
  static bool isValidInstallPath(String dirPath) {
    if (Platform.isAndroid) {
      return p.normalize(dirPath) == p.normalize(androidInstallPath);
    }
    return isValidGamePath(dirPath);
  }

  /// Проверяет, что в [dirPath] лежит установленная игра (Windows).
  /// Требуется папка reverse1999_Data; желателен .exe (но не обязателен,
  /// если data-папка на месте — у некоторых сборок имя exe отличается).
  static bool isValidGamePath(String dirPath) {
    if (dirPath.isEmpty || dirPath.startsWith('Укажите')) {
      return false;
    }
    final dataDir = Directory(p.join(dirPath, dataFolderName));
    if (!dataDir.existsSync()) {
      return false;
    }
    // Доп. проверка: есть ли хотя бы один .exe в корне или известное имя.
    try {
      for (final name in _exeCandidates) {
        if (File(p.join(dirPath, name)).existsSync()) {
          return true;
        }
      }
      final hasAnyExe = Directory(dirPath)
          .listSync(followLinks: false)
          .whereType<File>()
          .any((f) => p.extension(f.path).toLowerCase() == '.exe');
      // Data-папка обязательна; exe желателен, но отсутствие не блокирует,
      // если пользователь явно выбрал корень с reverse1999_Data.
      return hasAnyExe || dataDir.existsSync();
    } catch (_) {
      return dataDir.existsSync();
    }
  }

  /// Сообщение, почему путь отклонён (для UI).
  static String? validationError(String dirPath) {
    if (dirPath.isEmpty) {
      return 'Путь пустой.';
    }
    if (!Directory(p.join(dirPath, dataFolderName)).existsSync()) {
      return 'В выбранной папке нет «$dataFolderName». '
          'Укажите корень установки Reverse: 1999.';
    }
    return null;
  }

  /// Перебирает реестр Steam, libraryfolders и типичные пути на дисках C:–Z:.
  static Future<String?> findWindowsGamePath() async {
    if (!Platform.isWindows) {
      return null;
    }

    // 1) Пути из Steam (реестр + libraryfolders.vdf).
    for (final steamRoot in await _steamLibraryRoots()) {
      final candidate = p.normalize(
        p.join(steamRoot, 'steamapps', 'common', 'Reverse 1999'),
      );
      if (isValidGamePath(candidate)) {
        return candidate;
      }
    }

    // 2) Типичные пути на всех дисках.
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

  /// Корни Steam-библиотек: InstallPath из реестра + libraryfolders.vdf.
  static Future<List<String>> _steamLibraryRoots() async {
    final roots = <String>{};

    for (final key in const [
      r'HKLM\SOFTWARE\WOW6432Node\Valve\Steam',
      r'HKLM\SOFTWARE\Valve\Steam',
      r'HKCU\SOFTWARE\Valve\Steam',
    ]) {
      final installPath = await _regQueryValue(key, 'InstallPath');
      if (installPath != null && installPath.isNotEmpty) {
        roots.add(p.normalize(installPath));
      }
    }

    // Дополнительные библиотеки из libraryfolders.vdf у каждой найденной Steam.
    final baseRoots = List<String>.from(roots);
    for (final steamRoot in baseRoots) {
      final vdf = File(p.join(steamRoot, 'steamapps', 'libraryfolders.vdf'));
      if (!await vdf.exists()) continue;
      try {
        final text = await vdf.readAsString();
        // Строки вида: "path"		"D:\\SteamLibrary"
        final re = RegExp(r'"path"\s+"([^"]+)"', caseSensitive: false);
        for (final m in re.allMatches(text)) {
          final raw = m.group(1)!.replaceAll(r'\\', r'\');
          roots.add(p.normalize(raw));
        }
      } catch (_) {
        // Битый vdf — пропускаем.
      }
    }

    return roots.toList();
  }

  /// Читает значение REG_SZ через `reg query` (без нативных плагинов).
  static Future<String?> _regQueryValue(String key, String valueName) async {
    try {
      final result = await Process.run(
        'reg',
        ['query', key, '/v', valueName],
        runInShell: true,
      );
      if (result.exitCode != 0) return null;
      final out = (result.stdout as String?) ?? '';
      // Пример: InstallPath    REG_SZ    C:\Program Files (x86)\Steam
      final re = RegExp(
        '${RegExp.escape(valueName)}\\s+REG_\\w+\\s+(.+)\$',
        multiLine: true,
        caseSensitive: false,
      );
      final m = re.firstMatch(out);
      return m?.group(1)?.trim();
    } catch (_) {
      return null;
    }
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

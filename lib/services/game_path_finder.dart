import 'dart:io';

import 'package:path/path.dart' as p;

/// Поиск папки установки Reverse: 1999 на ПК (Windows).
class GamePathFinder {
  GamePathFinder._();

  /// Ключ в SharedPreferences для пути, выбранного пользователем (только Windows).
  static const prefsKey = 'install_path';

  /// Фиксированный путь к данным игры на Android — выбор папки не нужен.
  /// Пакет уточняется через [androidDataPathFor] / resolveGamePackage.
  static const androidGamePackages = <String>[
    'com.bluepoch.m.en.reverse1999',
    'com.bluepoch.m.cn.reverse1999',
  ];

  static const androidInstallPath =
      '/storage/emulated/0/Android/data/com.bluepoch.m.en.reverse1999/';

  /// Каталог Android/data для установленного пакета игры.
  static String androidDataPathFor(String packageName) =>
      '/storage/emulated/0/Android/data/$packageName/';

  /// Папка данных Unity — обязательный признак корня установки на Windows.
  static const dataFolderName = 'reverse1999_Data';

  /// Возможные имена exe в корне игры.
  static const _exeCandidates = <String>[
    'Reverse1999.exe',
    'reverse1999.exe',
    'Reverse 1999.exe',
    'Reverse1999en.exe',
  ];

  /// Типичные «обёртки» / корни установки относительно диска.
  /// Глобальный клиент часто кладёт exe во вложенную `Reverse1999en`.
  static const _relativeCandidates = <String>[
    r'Games\reverse1999_global\Reverse1999en',
    r'Games\reverse1999_global',
    r'Games\Reverse 1999',
    r'Games\Reverse1999',
    r'Program Files\Steam\steamapps\common\Reverse 1999',
    r'Program Files (x86)\Steam\steamapps\common\Reverse 1999',
    r'Steam\steamapps\common\Reverse 1999',
    r'SteamLibrary\steamapps\common\Reverse 1999',
  ];

  /// Имена вложенных папок, где лежит реальный корень глобальной сборки.
  static const _nestedRootNames = <String>[
    'Reverse1999en',
    'Reverse1999_EN',
    'Reverse1999',
    'Reverse 1999',
    'reverse1999en',
    'reverse1999',
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

  /// Если [dirPath] — родительская обёртка (например Games\reverse1999_global),
  /// возвращает вложенный корень с reverse1999_Data; иначе сам [dirPath] или null.
  static String? resolveGameRoot(String dirPath) {
    if (dirPath.isEmpty) return null;
    final normalized = p.normalize(dirPath);
    if (isValidGamePath(normalized)) {
      return normalized;
    }

    // Известные вложенные имена.
    for (final name in _nestedRootNames) {
      final nested = p.normalize(p.join(normalized, name));
      if (isValidGamePath(nested)) {
        return nested;
      }
    }

    // Один уровень вглубь: любая подпапка с reverse1999_Data.
    try {
      final dir = Directory(normalized);
      if (!dir.existsSync()) return null;
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is! Directory) continue;
        final candidate = p.normalize(entity.path);
        if (isValidGamePath(candidate)) {
          return candidate;
        }
      }
    } catch (_) {
      // Нет доступа — пропускаем.
    }
    return null;
  }

  /// Путь к exe игры в [dirPath], или null если не найден.
  static String? findGameExecutable(String dirPath) {
    final root = resolveGameRoot(dirPath) ?? dirPath;
    if (root.isEmpty) return null;
    for (final name in _exeCandidates) {
      final candidate = p.join(root, name);
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    try {
      final exe = Directory(root)
          .listSync(followLinks: false)
          .whereType<File>()
          .where((f) => p.extension(f.path).toLowerCase() == '.exe')
          .map((f) => f.path)
          .toList();
      if (exe.isEmpty) return null;
      // Предпочитаем имя с Reverse/1999, иначе первый .exe в корне.
      for (final path in exe) {
        final lower = p.basename(path).toLowerCase();
        if (lower.contains('reverse') || lower.contains('1999')) {
          return path;
        }
      }
      return exe.first;
    } catch (_) {
      return null;
    }
  }

  /// Сообщение, почему путь отклонён (для UI).
  static String? validationError(String dirPath) {
    if (dirPath.isEmpty) {
      return 'Путь пустой.';
    }
    if (resolveGameRoot(dirPath) != null) {
      return null;
    }
    if (!Directory(p.join(dirPath, dataFolderName)).existsSync()) {
      return 'В выбранной папке нет «$dataFolderName». '
          'Укажите корень установки Reverse: 1999 '
          '(обычно папка Reverse1999en или Steam\\…\\Reverse 1999).';
    }
    return null;
  }

  /// Перебирает реестр Steam, libraryfolders и типичные пути на дисках C:–Z:.
  /// Если найдено несколько установок — берёт ту, где exe новее (активная копия).
  static Future<String?> findWindowsGamePath() async {
    if (!Platform.isWindows) {
      return null;
    }

    final found = <String>{};

    // 1) Пути из Steam (реестр + libraryfolders.vdf).
    for (final steamRoot in await _steamLibraryRoots()) {
      final steamCommon = p.join(steamRoot, 'steamapps', 'common');
      for (final name in const ['Reverse 1999', 'Reverse1999']) {
        final resolved = resolveGameRoot(p.join(steamCommon, name));
        if (resolved != null) found.add(resolved);
      }
      final scanned = _scanCommonForGame(steamCommon);
      if (scanned != null) found.add(scanned);
    }

    // 2) Типичные пути на всех дисках (включая вложенный Reverse1999en).
    for (final drive in _availableDriveLetters()) {
      for (final relative in _relativeCandidates) {
        final candidate = p.normalize(p.join('$drive:\\', relative));
        final resolved = resolveGameRoot(candidate);
        if (resolved != null) found.add(resolved);
      }
    }

    if (found.isEmpty) return null;
    return _preferActiveInstall(found);
  }

  /// Среди нескольких копий выбирает наиболее «живую» (свежий exe / global).
  static String _preferActiveInstall(Set<String> roots) {
    String? best;
    var bestScore = -1;

    for (final root in roots) {
      var score = 0;
      final lower = root.toLowerCase();
      if (lower.contains('reverse1999_global')) score += 200;
      if (lower.contains('reverse1999en')) score += 80;
      if (lower.contains('${p.separator}steam${p.separator}') ||
          lower.contains('steamapps')) {
        score += 60;
      }

      final exe = findGameExecutable(root);
      if (exe != null) {
        score += 50;
        try {
          final modified = File(exe).lastModifiedSync().millisecondsSinceEpoch;
          // Более свежий exe важнее старых копий на других дисках.
          score += (modified ~/ 1000000).clamp(0, 2000000);
        } catch (_) {
          // Нет доступа к mtime.
        }
      }

      if (score > bestScore) {
        bestScore = score;
        best = root;
      }
    }

    return best!;
  }

  /// Ищет папку игры среди подпапок steamapps/common (на случай другого имени).
  static String? _scanCommonForGame(String steamCommon) {
    try {
      final dir = Directory(steamCommon);
      if (!dir.existsSync()) return null;
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is! Directory) continue;
        final name = p.basename(entity.path).toLowerCase();
        if (!name.contains('reverse') && !name.contains('1999')) continue;
        final resolved = resolveGameRoot(entity.path);
        if (resolved != null) return resolved;
      }
    } catch (_) {
      // Нет доступа к библиотеке Steam.
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

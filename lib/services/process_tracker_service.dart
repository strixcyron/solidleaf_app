import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Отслеживает запущенный процесс игры на Windows и извлекает путь установки.
///
/// Раз в [pollInterval] опрашивает процессы через PowerShell `Get-Process`.
/// Как только найден `Reverse1999.exe` — возвращает корень игры и останавливается.
class ProcessTrackerService {
  ProcessTrackerService();

  static const processNames = <String>[
    'Reverse1999',
    'reverse1999',
  ];

  Timer? _timer;
  bool _probeInFlight = false;
  bool _stopped = true;

  /// Идёт ли сейчас периодический опрос.
  bool get isRunning => !_stopped && _timer != null;

  /// Запускает опрос. Повторный вызов перезапускает таймер.
  void start({
    required void Function(String gameDir) onFound,
    Duration pollInterval = const Duration(seconds: 2),
  }) {
    if (!Platform.isWindows) {
      return;
    }

    stop();
    _stopped = false;

    Future<void> tick() async {
      if (_stopped || _probeInFlight) return;
      _probeInFlight = true;
      try {
        final exePath = await findRunningGameExecutablePath();
        if (_stopped || exePath == null) return;

        final gameDir = p.normalize(p.dirname(exePath));
        stop();
        onFound(gameDir);
      } finally {
        _probeInFlight = false;
      }
    }

    // Сразу одна попытка, затем периодически.
    unawaited(tick());
    _timer = Timer.periodic(pollInterval, (_) => unawaited(tick()));
  }

  /// Останавливает таймер (успех, закрытие окна, пауза).
  void stop() {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
  }

  /// Есть ли сейчас процесс игры (без пути к exe).
  static Future<bool> isGameProcessRunning() async {
    if (!Platform.isWindows) return false;

    for (final name in processNames) {
      try {
        final result = await Process.run(
          'powershell',
          [
            '-NoProfile',
            '-NonInteractive',
            '-ExecutionPolicy',
            'Bypass',
            '-Command',
            "(Get-Process -Name '$name' -ErrorAction SilentlyContinue | "
                'Measure-Object).Count',
          ],
          runInShell: false,
        );
        if (result.exitCode != 0) continue;
        final count =
            int.tryParse((result.stdout as String?)?.trim() ?? '') ?? 0;
        if (count > 0) return true;
      } catch (_) {}
    }

    // Фолбэк: tasklist (быстрее и надёжнее на части сборок).
    try {
      final result = await Process.run(
        'tasklist',
        ['/FI', 'IMAGENAME eq reverse1999.exe', '/NH'],
        runInShell: true,
      );
      final out = ((result.stdout as String?) ?? '').toLowerCase();
      if (out.contains('reverse1999.exe')) return true;
    } catch (_) {}

    return false;
  }

  /// Ищет ExecutablePath процесса Reverse1999 через PowerShell.
  static Future<String?> findRunningGameExecutablePath() async {
    if (!Platform.isWindows) return null;

    for (final name in processNames) {
      try {
        final result = await Process.run(
          'powershell',
          [
            '-NoProfile',
            '-NonInteractive',
            '-ExecutionPolicy',
            'Bypass',
            '-Command',
            "(Get-Process -Name '$name' -ErrorAction SilentlyContinue | "
                'Select-Object -First 1 -ExpandProperty Path)',
          ],
          runInShell: false,
        );

        if (result.exitCode != 0) continue;
        final out = (result.stdout as String?)?.trim() ?? '';
        if (out.isEmpty) continue;

        // Path должен указывать на .exe
        final normalized = p.normalize(out.replaceAll('"', ''));
        if (!normalized.toLowerCase().endsWith('.exe')) continue;
        if (!await File(normalized).exists()) continue;
        return normalized;
      } catch (_) {
        // PowerShell недоступен / процесс не найден — пробуем следующее имя.
      }
    }

    // Фолбэк: WMIC (на новых Windows может отсутствовать).
    try {
      final result = await Process.run(
        'wmic',
        [
          'process',
          'where',
          "name='Reverse1999.exe'",
          'get',
          'ExecutablePath',
          '/value',
        ],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        final out = (result.stdout as String?) ?? '';
        final match = RegExp(
          r'ExecutablePath=(.+)',
          caseSensitive: false,
        ).firstMatch(out);
        final path = match?.group(1)?.trim();
        if (path != null &&
            path.isNotEmpty &&
            await File(path).exists()) {
          return p.normalize(path);
        }
      }
    } catch (_) {}

    return null;
  }
}

import 'dart:io';

/// Гарантирует один запущенный экземпляр лаунчера на Windows/Linux/macOS.
///
/// Использует эксклюзивную блокировку файла в temp — без нативных плагинов.
/// Если копия уже запущена, возвращает false (второй процесс должен выйти).
class SingleInstanceGuard {
  SingleInstanceGuard._();

  static RandomAccessFile? _lock;

  /// Пытается захватить lock-файл. false = уже есть живой процесс.
  static Future<bool> ensureSingleInstance({
    String lockName = 'solidleaf_launcher.lock',
  }) async {
    if (Platform.isAndroid || Platform.isIOS) {
      return true;
    }

    try {
      final lockFile = File('${Directory.systemTemp.path}${Platform.pathSeparator}$lockName');
      _lock = await lockFile.open(mode: FileMode.write);
      await _lock!.lock(FileLock.exclusive);
      await _lock!.writeString('$pid\n${DateTime.now().toIso8601String()}\n');
      await _lock!.flush();
      return true;
    } on PathAccessException {
      await _safeClose();
      return false;
    } on FileSystemException {
      await _safeClose();
      return false;
    } catch (_) {
      await _safeClose();
      return false;
    }
  }

  static Future<void> _safeClose() async {
    try {
      await _lock?.close();
    } catch (_) {}
    _lock = null;
  }
}

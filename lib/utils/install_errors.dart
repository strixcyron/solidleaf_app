import 'dart:io';

/// Ошибка установки патча с понятным текстом для пользователя.
/// Не должна приводить к падению всего процесса лаунчера.
class PatchInstallException implements Exception {
  PatchInstallException(this.message, {this.needsAdmin = false});

  final String message;
  final bool needsAdmin;

  @override
  String toString() => message;
}

/// Превращает низкоуровневые FS/OS ошибки в сообщение для AlertDialog.
String describeInstallError(Object error, {String? pathHint}) {
  if (error is PatchInstallException) {
    return error.message;
  }

  if (error is FileSystemException) {
    final code = error.osError?.errorCode;
    final raw = '${error.osError?.message ?? ''} ${error.message}'.toLowerCase();
    final path = pathHint ?? error.path ?? '';

    // Windows ERROR_ACCESS_DENIED = 5, ERROR_SHARING_VIOLATION = 32
    final accessDenied = code == 5 ||
        raw.contains('access is denied') ||
        raw.contains('отказано в доступе') ||
        raw.contains('permission denied');
    final sharing = code == 32 ||
        raw.contains('being used by another process') ||
        raw.contains('занят другим процессом') ||
        raw.contains('sharing violation');

    if (accessDenied || sharing) {
      final detail = path.isEmpty ? '' : '\n\nФайл: $path';
      return 'Ошибка доступа к файлам игры.$detail\n\n'
          'Закройте Reverse: 1999 (и антивирус, если блокирует файлы) '
          'и запустите лаунчер от имени Администратора.';
    }

    if (code == 3 || raw.contains('cannot find') || raw.contains('не удается найти')) {
      return 'Неверный путь к игре или файл не найден'
          '${path.isEmpty ? '' : ': $path'}.\n\n'
          'Укажите папку, где лежит reverse1999_Data.';
    }

    return 'Ошибка файловой системы'
        '${path.isEmpty ? '' : ' ($path)'}: '
        '${error.osError?.message ?? error.message}';
  }

  final text = error.toString();
  if (text.toLowerCase().contains('access') ||
      text.toLowerCase().contains('denied') ||
      text.contains('отказано')) {
    return 'Ошибка доступа к файлам игры. '
        'Запустите лаунчер от имени Администратора.';
  }

  return text.replaceFirst(RegExp(r'^Exception:\s*'), '');
}

/// True, если ошибка похожа на Access Denied / файл занят.
bool isAccessDeniedError(Object error) {
  if (error is PatchInstallException) return error.needsAdmin;
  if (error is FileSystemException) {
    final code = error.osError?.errorCode;
    if (code == 5 || code == 32) return true;
    final raw = '${error.osError?.message ?? ''} ${error.message}'.toLowerCase();
    return raw.contains('access') ||
        raw.contains('denied') ||
        raw.contains('sharing') ||
        raw.contains('отказано');
  }
  return false;
}

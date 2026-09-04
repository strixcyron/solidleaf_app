import 'dart:io';

import 'package:dio/dio.dart';

/// Ошибка установки патча с понятным текстом для пользователя.
/// Не должна приводить к падению всего процесса лаунчера.
class PatchInstallException implements Exception {
  PatchInstallException(this.message, {this.needsAdmin = false});

  final String message;
  final bool needsAdmin;

  @override
  String toString() => message;
}

/// Структурированная ошибка для диалога: заголовок + кратко + шаги.
class UserFacingError {
  const UserFacingError({
    required this.title,
    required this.summary,
    this.steps = const [],
  });

  final String title;
  final String summary;
  final List<String> steps;

  /// Плоский текст (для statusText / логов пользователя).
  String get flatMessage {
    if (steps.isEmpty) return summary;
    final bullets = steps.map((s) => '• $s').join('\n');
    return '$summary\n\nЧто сделать:\n$bullets';
  }
}

/// Убирает технические префиксы Exception / PlatformException из строки.
String sanitizeUserErrorText(String raw) {
  var text = raw.trim();
  text = text.replaceFirst(RegExp(r'^(Exception|Error):\s*', caseSensitive: false), '');
  text = text.replaceFirst(
    RegExp(r'^Exception:\s*Exception:\s*', caseSensitive: false),
    '',
  );
  // Dio / Platform обёртки
  text = text.replaceFirst(
    RegExp(r'^DioException\s*\[[^\]]*\]:\s*', caseSensitive: false),
    '',
  );
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text;
}

/// Превращает любую ошибку в понятное сообщение для AlertDialog.
String describeInstallError(Object error, {String? pathHint}) {
  return describeInstallErrorDetailed(error, pathHint: pathHint).flatMessage;
}

/// То же, но со структурой title / summary / steps.
UserFacingError describeInstallErrorDetailed(
  Object error, {
  String? pathHint,
  bool interruptedByBackground = false,
}) {
  if (interruptedByBackground) {
    return const UserFacingError(
      title: 'Загрузка прервана',
      summary:
          'Пока лаунчер был свёрнут, загрузка или установка остановилась. '
          'Это нормально — данные не повреждены.',
      steps: [
        'Откройте лаунчер и не сворачивайте его на время установки',
        'Нажмите «Установить» или «Обновить» ещё раз',
        'На Android держите Shizuku запущенным',
      ],
    );
  }

  if (error is UserFacingError) return error;

  if (error is PatchInstallException) {
    return UserFacingError(
      title: error.needsAdmin ? 'Нужны права доступа' : 'Не удалось установить',
      summary: sanitizeUserErrorText(error.message),
      steps: error.needsAdmin
          ? const [
              'Закройте игру Reverse: 1999',
              'Запустите лаунчер от имени администратора',
              'Повторите установку',
            ]
          : const [
              'Проверьте интернет и повторите попытку',
              'Убедитесь, что путь к игре указан верно',
            ],
    );
  }

  if (error is DioException) {
    return _describeDio(error);
  }

  if (error is FileSystemException) {
    final code = error.osError?.errorCode;
    final raw = '${error.osError?.message ?? ''} ${error.message}'.toLowerCase();
    final path = pathHint ?? error.path ?? '';

    final accessDenied = code == 5 ||
        raw.contains('access is denied') ||
        raw.contains('отказано в доступе') ||
        raw.contains('permission denied');
    final sharing = code == 32 ||
        raw.contains('being used by another process') ||
        raw.contains('занят другим процессом') ||
        raw.contains('sharing violation');

    if (accessDenied || sharing) {
      return const UserFacingError(
        title: 'Нет доступа к файлам игры',
        summary: 'Лаунчер не смог записать файлы локализации.',
        steps: [
          'Полностью закройте Reverse: 1999',
          'Временно отключите блокировку папки антивирусом',
          'Запустите лаунчер от имени администратора и повторите',
        ],
      );
    }

    if (code == 3 ||
        raw.contains('cannot find') ||
        raw.contains('не удается найти')) {
      return const UserFacingError(
        title: 'Папка игры не найдена',
        summary: 'Указанный путь к игре неверный или файлы отсутствуют.',
        steps: [
          'Укажите папку, где лежит reverse1999_Data',
          'Или запустите игру один раз — лаунчер может найти путь сам',
        ],
      );
    }

    return UserFacingError(
      title: 'Ошибка записи файлов',
      summary: 'Не удалось сохранить файлы локализации на диск.',
      steps: const [
        'Проверьте свободное место на диске',
        'Повторите установку',
      ],
    );
  }

  final text = sanitizeUserErrorText(error.toString()).toLowerCase();

  if (text.contains('shizuku')) {
    return const UserFacingError(
      title: 'Нужен Shizuku',
      summary: 'Без активного Shizuku установка на Android невозможна.',
      steps: [
        'Откройте приложение Shizuku и нажмите Start',
        'Разрешите доступ лаунчеру SolidLeaf',
        'Вернитесь сюда и повторите установку',
      ],
    );
  }

  if (text.contains('access') ||
      text.contains('denied') ||
      text.contains('отказано')) {
    return const UserFacingError(
      title: 'Нужны права доступа',
      summary: 'Система запретила запись в папку игры.',
      steps: [
        'Закройте игру',
        'Запустите лаунчер от имени администратора',
        'Повторите установку',
      ],
    );
  }

  if (text.contains('socket') ||
      text.contains('connection') ||
      text.contains('network') ||
      text.contains('failed host') ||
      text.contains('timed out') ||
      text.contains('timeout')) {
    return const UserFacingError(
      title: 'Проблема с сетью',
      summary: 'Не удалось скачать файлы локализации.',
      steps: [
        'Проверьте интернет или VPN',
        'Не сворачивайте лаунчер во время загрузки',
        'Повторите попытку',
      ],
    );
  }

  // Не показываем сырой стек — общее сообщение.
  return const UserFacingError(
    title: 'Не удалось установить',
    summary: 'Произошла ошибка при загрузке или установке локализации.',
    steps: [
      'Повторите попытку',
      'Если ошибка повторяется — проверьте интернет и Shizuku (на Android)',
    ],
  );
}

UserFacingError _describeDio(DioException exception) {
  switch (exception.type) {
    case DioExceptionType.cancel:
      return const UserFacingError(
        title: 'Загрузка отменена',
        summary: 'Скачивание было прервано.',
        steps: ['Нажмите «Установить» ещё раз'],
      );
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const UserFacingError(
        title: 'Сервер не отвечает',
        summary: 'Превышено время ожидания при загрузке файлов.',
        steps: [
          'Проверьте интернет',
          'Попробуйте позже или смените сеть / VPN',
        ],
      );
    case DioExceptionType.connectionError:
      return const UserFacingError(
        title: 'Нет соединения',
        summary: 'Нет интернета или сервер временно недоступен.',
        steps: [
          'Проверьте сеть',
          'При блокировках попробуйте включить или выключить VPN',
        ],
      );
    case DioExceptionType.badResponse:
      final code = exception.response?.statusCode;
      if (code == 401 || code == 403) {
        return const UserFacingError(
          title: 'Нет доступа к файлам',
          summary: 'Сервер отклонил запрос на скачивание.',
          steps: [
            'Выйдите и войдите снова через Telegram',
            'Для графики нужен Premium-доступ',
          ],
        );
      }
      if (code == 404) {
        return const UserFacingError(
          title: 'Файлы не найдены',
          summary: 'Архив локализации отсутствует на сервере.',
          steps: [
            'Проверьте обновления позже',
            'Напишите в сообщество SolidLeaf, если ошибка повторяется',
          ],
        );
      }
      return UserFacingError(
        title: 'Ошибка сервера',
        summary: 'Сервер вернул ошибку${code == null ? '' : ' ($code)'}.',
        steps: const ['Повторите попытку чуть позже'],
      );
    default:
      return const UserFacingError(
        title: 'Ошибка загрузки',
        summary: 'Не удалось скачать файлы локализации.',
        steps: [
          'Проверьте интернет',
          'Повторите установку',
        ],
      );
  }
}

/// True, если ошибка похожа на Access Denied / файл занят.
bool isAccessDeniedError(Object error) {
  if (error is PatchInstallException) return error.needsAdmin;
  if (error is UserFacingError) {
    return error.title.contains('доступ') || error.title.contains('права');
  }
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

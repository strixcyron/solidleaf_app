/// Централизованная конфигурация Telegram auth-backend
/// (FastAPI + бот), через который лаунчер получает JWT и премиум-загрузки.
///
/// Секреты (GITHUB_TOKEN, JWT_SECRET, DATABASE_URL) живут только на сервере.
/// Клиент знает лишь публичный адрес API.
class TelegramAuthConfig {
  TelegramAuthConfig._();

  /// Имя Telegram-бота без ведущего `@`.
  /// Используется для deep link `tg://resolve?domain=...&start=...`.
  static const String botUsername = 'SolidLeaf_Auth_Bot';

  /// Адрес production-бэкенда на VPS (по умолчанию).
  static const String defaultBackendUrl = 'http://138.124.241.69:8000';

  /// Base URL FastAPI-бэкенда.
  ///
  /// Приоритет:
  /// 1. `--dart-define=APP_BACKEND_URL=...` (или dart_defines.local.json)
  /// 2. [defaultBackendUrl] — VPS production
  ///
  /// Пример локальной переопределения при разработке:
  /// `--dart-define=APP_BACKEND_URL=http://127.0.0.1:8000`
  static String get baseUrl {
    const override = String.fromEnvironment('APP_BACKEND_URL', defaultValue: '');
    if (override.isNotEmpty) {
      return override;
    }
    return defaultBackendUrl;
  }

  /// Интервал опроса `/auth/status` (секунды), пока пользователь
  /// подтверждает вход в Telegram.
  static const int pollIntervalSeconds = 3;

  /// Таймаут ожидания успешного входа (секунды).
  static const int pollTimeoutSeconds = 120;
}

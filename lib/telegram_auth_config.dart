import 'dart:io';

/// Centralized configuration for the Telegram authentication backend
/// (FastAPI service + Telegram bot) used to unlock premium texture
/// downloads.
///
/// Edit the values below to point the launcher at your deployment.
class TelegramAuthConfig {
  TelegramAuthConfig._();

  /// Telegram bot username WITHOUT the leading `@`.
  /// Used to build the deep link `tg://resolve?domain=...&start=...`.
  static const String botUsername = 'SolidLeaf_Auth_Bot';

  /// Base URL of the FastAPI backend that issues session ids, JWT tokens and
  /// serves the protected texture download endpoint.
  ///
  /// Resolved automatically based on platform.
  ///
  /// `10.0.2.2` only works in the Android emulator. On a real phone the app
  /// must connect to the PC's LAN IP (for example 192.168.31.58), otherwise
  /// the `/auth/generate` request times out before the Telegram login flow can
  /// even start. You can override it at build time with
  /// `--dart-define=APP_BACKEND_URL=http://192.168.31.58:8000`.
  static String get baseUrl {
    const override = String.fromEnvironment('APP_BACKEND_URL', defaultValue: '');
    if (override.isNotEmpty) {
      return override;
    }

    if (Platform.isAndroid) {
      // Real device fallback: use the host PC LAN IP on the same Wi‑Fi network.
      return 'http://192.168.31.58:8000';
    }
    return 'http://localhost:8000';
  }

  /// How often (in seconds) the client polls `/auth/status` while waiting
  /// for the user to confirm the login inside Telegram.
  static const int pollIntervalSeconds = 3;

  /// Maximum time (in seconds) to wait for a successful login before giving
  /// up and reporting a timeout error.
  static const int pollTimeoutSeconds = 120;
}

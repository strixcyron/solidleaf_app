import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'telegram_auth_config.dart';

/// Thrown when a Telegram login attempt fails or times out, or when a
/// protected request is rejected because of a missing/expired token.
class TelegramAuthException implements Exception {
  TelegramAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Internal helper carrying the parsed result of a single `/auth/status`
/// poll. `null` fields/return values from [TelegramAuthService._checkStatus]
/// mean "still pending" (keep polling).
class _AuthStatus {
  _AuthStatus({required this.isSuccess, this.token, this.accessLevel});
  final bool isSuccess;
  final String? token;

  /// Access tier granted by the backend: "premium" (full access, including
  /// textures) or "basic" (text localization only). Only meaningful when
  /// [isSuccess] is true.
  final String? accessLevel;
}

/// Handles the full Telegram deep-link login flow, secure JWT storage, and
/// downloading of premium (login-gated) content such as texture packs.
///
/// Flow overview:
/// 1. [loginWithTelegram] asks the backend for a `session_id`, opens
///    Telegram via a deep link (`tg://resolve?domain=...&start=...`) and
///    polls `/auth/status` every [TelegramAuthConfig.pollIntervalSeconds]
///    until the user approves the login inside the bot, or until
///    [TelegramAuthConfig.pollTimeoutSeconds] elapses.
/// 2. On success the JWT is stored securely via [FlutterSecureStorage].
/// 3. [downloadPremiumTextures] attaches the stored token as a Bearer header
///    to fetch the protected archive and saves it to a temporary file.
class TelegramAuthService {
  TelegramAuthService({Dio? dio, FlutterSecureStorage? secureStorage})
    : _dio = dio ?? Dio(),
      _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  static const _tokenKey = 'telegram_auth_jwt';
  // Stored alongside the token so the app can distinguish "premium" (text +
  // textures) from "basic" (text-only) accounts without another network
  // round-trip. See TELEGRAM_PUBLIC_GROUP_ID / TELEGRAM_CHANNEL_ID on the
  // backend for how this tier is decided.
  static const _accessLevelKey = 'telegram_access_level';

  Timer? _pollTimer;
  Completer<bool>? _loginCompleter;

  /// Starts the Telegram login flow.
  ///
  /// Returns `true` once the backend confirms the login and the JWT has been
  /// stored. Throws [TelegramAuthException] if the backend reports failure,
  /// if the Telegram app/link can't be opened, or if polling times out.
  Future<bool> loginWithTelegram() async {
    // Guard against overlapping login attempts (e.g. double-tap).
    _stopPolling();

    final sessionId = await _requestSessionId();
    await _openTelegramDeepLink(sessionId);

    final completer = Completer<bool>();
    _loginCompleter = completer;

    var elapsedSeconds = 0;
    _pollTimer = Timer.periodic(
      const Duration(seconds: TelegramAuthConfig.pollIntervalSeconds),
      (timer) async {
        elapsedSeconds += TelegramAuthConfig.pollIntervalSeconds;

        // Stop polling once we've exceeded the configured timeout so the UI
        // isn't stuck forever waiting for a login that will never complete.
        if (elapsedSeconds >= TelegramAuthConfig.pollTimeoutSeconds) {
          _stopPolling();
          if (!completer.isCompleted) {
            completer.completeError(
              TelegramAuthException(
                'Время ожидания подтверждения входа истекло (2 минуты).',
              ),
            );
          }
          return;
        }

        try {
          final status = await _checkStatus(sessionId);
          if (status == null) {
            // Backend reports "pending" (or an unrecognized status) — keep
            // polling until success/failure/timeout.
            return;
          }

          _stopPolling();

          if (status.isSuccess) {
            await _secureStorage.write(key: _tokenKey, value: status.token);
            await _secureStorage.write(
              key: _accessLevelKey,
              value: status.accessLevel ?? 'basic',
            );
            if (!completer.isCompleted) completer.complete(true);
          } else if (!completer.isCompleted) {
            completer.completeError(
              TelegramAuthException(
                'Не удалось подтвердить вход через Telegram.',
              ),
            );
          }
        } on DioException {
          // Transient network errors shouldn't abort the whole poll loop —
          // just skip this tick and try again on the next one, until the
          // overall timeout above is reached.
        }
      },
    );

    return completer.future;
  }

  /// Cancels an in-flight login attempt (e.g. user closed the login dialog).
  void cancelLogin() {
    _stopPolling();
    if (_loginCompleter != null && !_loginCompleter!.isCompleted) {
      _loginCompleter!.completeError(
        TelegramAuthException('Вход отменён пользователем.'),
      );
    }
    _loginCompleter = null;
  }

  Future<String> _requestSessionId() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${TelegramAuthConfig.baseUrl}/auth/generate',
      );
      final sessionId = response.data?['session_id']?.toString();
      if (sessionId == null || sessionId.isEmpty) {
        throw TelegramAuthException('Сервер не вернул session_id.');
      }
      return sessionId;
    } on DioException catch (e) {
      throw TelegramAuthException(
        'Не удалось создать сессию входа: ${e.message ?? e.toString()}',
      );
    }
  }

  Future<void> _openTelegramDeepLink(String sessionId) async {
    final encodedSession = Uri.encodeComponent(sessionId);
    final webLink = Uri.parse(
      'https://t.me/${TelegramAuthConfig.botUsername}?start=$encodedSession',
    );

    // On Android/iOS the universal https://t.me/<bot>?start=... link is the
    // most reliable way to hand off to Telegram. The custom tg:// scheme can
    // silently fail depending on OS/app state or when Telegram is not the
    // default handler, leaving the user stuck in the app. We prefer the web
    // link first and only try the deep link as a fallback.
    final webOpened = await launchUrl(
      webLink,
      mode: LaunchMode.externalApplication,
    );
    if (webOpened) {
      return;
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      throw TelegramAuthException(
        'Не удалось открыть Telegram. Установите приложение или перейдите по ссылке вручную: $webLink',
      );
    }

    final deepLink = Uri.parse(
      'tg://resolve?domain=${TelegramAuthConfig.botUsername}&start=$encodedSession',
    );
    final deepOpened = await launchUrl(
      deepLink,
      mode: LaunchMode.externalApplication,
    );

    if (!deepOpened) {
      throw TelegramAuthException(
        'Не удалось открыть Telegram. Установите приложение или перейдите по ссылке вручную: $webLink',
      );
    }
  }

  Future<_AuthStatus?> _checkStatus(String sessionId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${TelegramAuthConfig.baseUrl}/auth/status',
      queryParameters: {'session_id': sessionId},
    );

    final data = response.data;
    if (data == null) return null;

    final status = data['status']?.toString();
    if (status == 'success') {
      return _AuthStatus(
        isSuccess: true,
        token: data['token']?.toString() ?? '',
        accessLevel: data['access_level']?.toString(),
      );
    }
    if (status == 'failed') {
      return _AuthStatus(isSuccess: false);
    }
    // Any other status (e.g. "pending") means we should keep polling.
    return null;
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Returns the securely stored JWT, or `null` if the user isn't logged in.
  Future<String?> getStoredToken() => _secureStorage.read(key: _tokenKey);

  /// Returns the stored access tier ("premium"/"basic"), or `null` if the
  /// user isn't logged in.
  Future<String?> getAccessLevel() => _secureStorage.read(key: _accessLevelKey);

  /// Whether a JWT is currently stored locally. This does not validate the
  /// token's expiry with the backend — it only checks local presence.
  Future<bool> isLoggedIn() async {
    final token = await getStoredToken();
    return token != null && token.isNotEmpty;
  }

  /// Whether the stored account has "premium" tier access (full access,
  /// including textures). Regular ("basic") accounts — public group members
  /// who aren't in the premium channel — are logged in but return `false`
  /// here, since they're limited to the text localization.
  Future<bool> hasPremiumAccess() async {
    final level = await getAccessLevel();
    return level == 'premium';
  }

  /// Clears the stored JWT and access tier, effectively logging the user out
  /// locally.
  Future<void> logout() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _accessLevelKey);
  }

  /// Метаданные последнего релиза с auth-backend (JWT определяет free/premium).
  Future<Map<String, dynamic>> fetchLatestRelease() async {
    final token = await getStoredToken();
    if (token == null || token.isEmpty) {
      throw TelegramAuthException(
        'Вы не авторизованы. Войдите через Telegram.',
      );
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${TelegramAuthConfig.baseUrl}/api/release/latest',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      final data = response.data;
      if (data == null) {
        throw TelegramAuthException('Пустой ответ сервера при проверке релиза.');
      }
      return Map<String, dynamic>.from(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await logout();
        throw TelegramAuthException(
          'Сессия истекла. Пожалуйста, войдите снова через Telegram.',
        );
      }
      final detail = _extractBackendError(e);
      if (e.response?.statusCode == 502) {
        throw TelegramAuthException(
          detail ??
              'Auth-backend не смог получить релиз с GitHub. '
              'Проверьте GITHUB_TOKEN и GITHUB_*_REPO на сервере.',
        );
      }
      throw TelegramAuthException(
        detail ?? 'Не удалось получить релиз: ${e.message ?? e.toString()}',
      );
    }
  }

  /// Скачивает премиум-архив через auth-backend (`art` или `full`).
  Future<File> downloadPremiumAsset({
    required String assetKind,
    ProgressCallback? onProgress,
  }) async {
    final token = await getStoredToken();
    if (token == null || token.isEmpty) {
      throw TelegramAuthException(
        'Вы не авторизованы. Войдите через Telegram.',
      );
    }

    final platform = Platform.isAndroid ? 'android' : 'pc';
    final kind = assetKind.toLowerCase();

    try {
      final response = await _dio.get<List<int>>(
        '${TelegramAuthConfig.baseUrl}/api/download/premium',
        queryParameters: {'platform': platform, 'asset_kind': kind},
        onReceiveProgress: onProgress,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 10),
        ),
      );

      final bytes = response.data;
      if (bytes == null) {
        throw TelegramAuthException(
          'Пустой ответ сервера при скачивании ($kind).',
        );
      }

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/premium_${kind}_${DateTime.now().millisecondsSinceEpoch}.zip';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await logout();
        throw TelegramAuthException(
          'Сессия истекла. Пожалуйста, войдите снова через Telegram.',
        );
      }
      if (e.response?.statusCode == 403) {
        throw TelegramAuthException(
          _extractBackendError(e) ?? 'Доступно только премиум-подписчикам.',
        );
      }
      if (e.response?.statusCode == 502) {
        throw TelegramAuthException(
          _extractBackendError(e) ??
              'Auth-backend не смог скачать архив с GitHub. '
              'Проверьте настройки сервера.',
        );
      }
      throw TelegramAuthException(
        _extractBackendError(e) ??
            'Не удалось скачать архив: ${e.message ?? e.toString()}',
      );
    }
  }

  /// Текст ошибки из JSON-ответа FastAPI (`error` / `detail`).
  String? _extractBackendError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final error = data['error'] ?? data['detail'];
      if (error != null) {
        return error.toString();
      }
    }
    if (data is String && data.isNotEmpty) {
      return data;
    }
    return null;
  }

  /// Downloads the protected texture archive using the stored JWT as a
  /// Bearer token. Saves the response bytes to a temporary file and returns
  /// it.
  /// - On 401 (missing/invalid/expired token) the local session is cleared
  ///   entirely (the user must log in again).
  /// - On 403 (valid token, but "basic" tier — not a premium/channel member)
  ///   the session is left intact; only a clear explanatory error is thrown,
  ///   since the user is still validly logged in for text localization.
  Future<File> downloadPremiumTextures({
    ProgressCallback? onProgress,
  }) async {
    return downloadPremiumAsset(assetKind: 'art', onProgress: onProgress);
  }

  /// Releases resources. Call this from a widget's `dispose()` if you hold a
  /// long-lived instance of this service.
  void dispose() {
    _stopPolling();
  }
}

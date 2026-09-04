import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_constants.dart';
import '../config/github_config.dart';
import '../services/cover_accent_loader.dart';
import '../services/game_path_finder.dart';
import '../services/notification_service.dart';
import '../services/process_tracker_service.dart';
import '../telegram_auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/install_errors.dart';

/// Что делать с лаунчером после запуска игры.
enum LaunchPostAction {
  none,
  minimizeToTray,
  closeAfterCountdown,
}

/// Режим воспроизведения в мини-плеере.
enum PlaybackMode {
  all,
  favorites,
  shuffle,
}

class LauncherController extends ChangeNotifier {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'solidleaf-launcher-app',
      },
    ),
  );

  bool isDarkMode = true;

  // --- Настройки оформления лаунчера (сохраняются в SharedPreferences) ---
  /// Включены ли анимации (дождь по стеклу и т.п.).
  bool animationsEnabled = true;

  /// Адаптивные цвета системы (Material You, Android 12+).
  bool dynamicColorEnabled = false;

  /// Анимированная обложка (ассет из assets/video/ с откатом на статичную).
  bool animatedCoverEnabled = false;

  /// Индекс выбранной анимированной обложки (0..6).
  int animatedCoverIndex = 0;

  /// Индекс статичной обложки (0..9).
  int staticCoverIndex = 0;

  /// Путь к пользовательской обложке (файл на диске), null — из ассетов.
  String? customCoverPath;

  /// Действие после запуска игры.
  LaunchPostAction launchPostAction = LaunchPostAction.none;

  /// Фоновая проверка обновлений.
  bool backgroundUpdateCheck = true;

  /// Избранные треки (по fileName).
  Set<String> favoriteTrackIds = {};

  /// Режим плейлиста: all / favorites / shuffle.
  PlaybackMode playbackMode = PlaybackMode.all;

  /// Выбранный пресет темы.
  AppThemePreset themePreset = AppThemePreset.dynamicCover;

  /// Пользовательский акцентный цвет (null — цвет из пресета/обложки).
  Color? customAccent;

  /// Масштаб шрифта интерфейса (1.0 — обычный).
  double uiScale = 1.0;

  bool isDownloading = false;

  /// Какой компонент сейчас качается: `text`, `art` или `null`.
  String? downloadingKind;
  bool hasUpdate = false;
  bool hasArtUpdate = false;
  bool isShizukuActive = false;
  double downloadProgress = 0;
  String installPath = '';
  bool isInstallPathValid = false;

  /// Windows: ждём запуска Reverse1999.exe для автоопределения пути.
  bool isWaitingForGameProcess = false;

  /// Игра сейчас запущена (после старта из лаунчера / пока процесс жив).
  bool isGameRunning = false;

  /// Кратковременный флаг «путь только что пойман» — для анимации в UI.
  bool gamePathJustDetected = false;

  final ProcessTrackerService _processTracker = ProcessTrackerService();
  Timer? _gameRunningWatch;
  bool _gameRunningProbeInFlight = false;
  bool _sawGameProcessAfterLaunch = false;
  String currentVersion = 'v0.0.0';
  String currentArtVersion = 'v0.0.0';
  String remoteVersion = '—';
  String remoteArtVersion = '—';
  String changelog = 'Проверка обновлений не запускалась';
  String statusText = 'Готово';
  List<String> logs = [];
  Color? coverAccent;

  Map<String, dynamic>? _cachedRelease;
  DateTime? _cachedReleaseAt;
  static const _releaseCacheTtl = Duration(seconds: 45);

  bool? _cachedReleaseIsPremium;

  bool get isDownloadingText => isDownloading && downloadingKind == 'text';
  bool get isDownloadingArt => isDownloading && downloadingKind == 'art';

  /// Версия текста для отображения (старые установки могли сохранить тег `update`).
  String get displayCurrentVersion {
    if (_looksLikeSemanticVersion(currentVersion)) {
      return currentVersion;
    }
    if (currentVersion != 'v0.0.0' &&
        _looksLikeSemanticVersion(remoteVersion)) {
      return remoteVersion;
    }
    return currentVersion;
  }

  // --- Telegram account tiers (login-gated launcher access) ----------------
  // The auth backend now issues a JWT to ANY member of the public community
  // group (t.me/reverse1999_solidleaf) — that's enough to use the launcher
  // and its text localization. Only members of the private premium channel
  // get access_level == "premium", which unlocks the "Графика и текстуры"
  // card. [isPremium] reflects that server-decided tier, not merely "has a
  // token" (see TelegramAuthService.hasPremiumAccess).
  final TelegramAuthService telegramAuth = TelegramAuthService();
  bool isPremium = false;

  /// Текст уже установлен (не «чистая» v0.0.0).
  bool get isTextInstalled => currentVersion != 'v0.0.0';

  /// Текстуры уже установлены.
  bool get isTexturesInstalled => currentArtVersion != 'v0.0.0';

  /// Обновление текста: компонент стоит и remote новее local.
  bool get hasTextUpdate => isTextInstalled && hasUpdate;

  /// Обновление текстур: компонент стоит и remote новее local.
  bool get hasTexturesUpdate => isTexturesInstalled && hasArtUpdate;

  bool get hasAnyComponentUpdate => hasTextUpdate || hasTexturesUpdate;

  bool get isNothingInstalled => !isTextInstalled && !isTexturesInstalled;

  /// Для free-аккаунта «всё» = только текст; текстуры требуют Premium.
  bool get isAllInstalled =>
      isPremium ? (isTextInstalled && isTexturesInstalled) : isTextInstalled;

  /// Re-reads the locally stored Telegram access tier and updates
  /// [isPremium]. Call this after [initialize], and again after any
  /// login/logout attempt (including the 401-triggered auto-logout inside
  /// [TelegramAuthService.downloadPremiumTextures]) so the UI badge/lock
  /// stays in sync with the actual account tier.
  Future<void> refreshPremiumStatus() async {
    final wasPremium = isPremium;
    isPremium = await telegramAuth.hasPremiumAccess();
    if (wasPremium != isPremium) {
      _invalidateReleaseCache();
    }
    notifyListeners();

    // Подписка истекла (Premium -> Free): автоматически откатываем премиум-
    // модификации к базовой бесплатной версии без перезапуска/перелогина.
    if (wasPremium && !isPremium) {
      await _handlePremiumDowngrade();
    }
  }

  /// Автоматический откат Premium -> Free при истечении подписки.
  ///
  /// Возвращает к оригиналу игры все файлы, которые перезаписал премиум
  /// (меню, интерфейс, конфиги, графика/текстуры), но оставляет базовые
  /// free-файлы (перевод сюжета) нетронутыми. На Android используется Shizuku,
  /// так как файлы лежат в `Android/data`.
  Future<void> _handlePremiumDowngrade() async {
    final backupDirPath = _backupFolderName();

    // Если ничего премиумного не устанавливалось — откатывать нечего.
    final hasBackup = Platform.isAndroid
        ? isShizukuActive && await _safeFsExists(backupDirPath)
        : await Directory(backupDirPath).exists();
    if (!hasBackup && currentArtVersion == 'v0.0.0') {
      return;
    }

    addLog('Подписка Premium истекла — выполняется откат к Free-версии...');
    statusText = 'Подписка истекла. Возврат к базовой Free-версии...';
    notifyListeners();

    // На Android без Shizuku физически не можем трогать Android/data —
    // не сбрасываем состояние, чтобы оно не врало пользователю.
    if (Platform.isAndroid) {
      if (!isShizukuActive) {
        try {
          await checkShizukuStatus();
        } catch (_) {}
      }
      if (!isShizukuActive) {
        addLog(
          'Shizuku не активен — откат премиум-файлов отложен. '
          'Откройте Shizuku и повторите вход, чтобы завершить откат.',
        );
        statusText =
            'Подписка истекла. Нужен Shizuku для отката премиум-файлов.';
        notifyListeners();
        return;
      }
      try {
        await _ensureFileService();
      } catch (e) {
        addLog('Не удалось подключить файловый сервис Shizuku: $e');
        statusText = 'Подписка истекла. Ошибка Shizuku при откате.';
        notifyListeners();
        return;
      }
    }

    final freeFiles = _freeFileSet;
    final toRevert = await _premiumFilesToRevert(freeFiles, backupDirPath);

    var reverted = 0;
    for (final rel in toRevert) {
      final src = _joinPath(backupDirPath, rel);
      final dst = _joinPath(installPath, rel);
      try {
        if (Platform.isWindows) {
          final srcFile = File(src);
          if (!await srcFile.exists()) {
            addLog('Бэкап отсутствует, пропуск: $rel');
            continue;
          }
          await File(dst).parent.create(recursive: true);
          await srcFile.copy(dst);
          reverted++;
          addLog('Откат к оригиналу: $rel');
        } else if (Platform.isAndroid) {
          final srcExists = await _fsExists(src);
          if (!srcExists) {
            addLog('Бэкап отсутствует (Android), пропуск: $rel');
            continue;
          }
          await _fsCopyFile(src, dst);
          reverted++;
          addLog('Shizuku: откат к оригиналу: $rel');
        }
      } catch (e) {
        // Ошибка на одном файле не должна прерывать весь откат.
        addLog('Не удалось откатить $rel: $e');
      }
    }

    // Обновляем состояние: премиум-графика/расширенный текст сняты,
    // остаётся только базовая free-локализация.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('installed_art_version', 'v0.0.0');
      currentArtVersion = 'v0.0.0';
      remoteArtVersion = '—';
      hasArtUpdate = false;
      lastBackupFiles = [];
      lastBackupKind = null;
      statusText =
          'Подписка истекла. Оставлена базовая Free-версия локализации';
      addLog('Откат к Free завершён. Возвращено файлов: $reverted.');
      notifyListeners();
    } catch (e) {
      addLog('Откат файлов выполнен, но не удалось сохранить состояние: $e');
      notifyListeners();
    }
  }

  /// Безопасная проверка существования пути на Android (не бросает исключение,
  /// если Shizuku-сервис недоступен).
  Future<bool> _safeFsExists(String targetPath) async {
    try {
      await _ensureFileService();
      return await _fsExists(targetPath);
    } catch (_) {
      return false;
    }
  }

  /// Собирает список относительных путей премиум-файлов, которые нужно
  /// откатить к оригиналу: объединяет статический список перезаписываемых
  /// файлов, файлы, забэкапленные в текущей сессии, и (на Windows) реальное
  /// содержимое папки бэкапа. Базовые free-файлы исключаются.
  Future<List<String>> _premiumFilesToRevert(
    Set<String> freeFiles,
    String backupDirPath,
  ) async {
    final candidates = <String>{};

    for (final rel
        in (Platform.isWindows ? _backupFilesWindows : _backupFilesAndroid)) {
      candidates.add(rel.replaceAll('\\', '/'));
    }

    // Файлы, забэкапленные при установке в этой сессии (в т.ч. art-текстуры).
    for (final rel in lastBackupFiles) {
      candidates.add(rel.replaceAll('\\', '/'));
    }

    // На Windows можем дочитать всё, что реально лежит в папке бэкапа,
    // чтобы покрыть графику и любые дополнительные премиум-файлы.
    if (Platform.isWindows) {
      final backupDir = Directory(backupDirPath);
      if (await backupDir.exists()) {
        for (final entity
            in backupDir.listSync(recursive: true).whereType<File>()) {
          final rel = path
              .relative(entity.path, from: backupDir.path)
              .replaceAll('\\', '/');
          candidates.add(rel);
        }
      }
    }

    return candidates.where((rel) => !freeFiles.contains(rel)).toList();
  }

  void _invalidateReleaseCache() {
    _cachedRelease = null;
    _cachedReleaseAt = null;
    _cachedReleaseIsPremium = null;
  }

  /// Премиум без встроенного GITHUB_TOKEN — через auth-backend и JWT
  /// (Android/iOS и сборки без dart-define).
  bool get _usesAuthBackendForPremium =>
      isPremium && !GitHubConfig.hasPremiumToken;

  String get _activeReleaseApiUrl =>
      isPremium ? githubPremiumLatestReleaseUrl : githubFreeLatestReleaseUrl;

  /// Ordered list of endpoints to try for the active tier. Both repos may
  /// expose their release under the named `update` tag rather than as a
  /// GitHub "latest" release, so `/releases/latest` can 404 even with a valid
  /// token; we then fall back to `/releases/tags/update` (same approach the
  /// auth backend uses server-side).
  List<String> get _activeReleaseApiUrls => isPremium
      ? const [githubPremiumLatestReleaseUrl, githubPremiumTagReleaseUrl]
      : const [githubFreeLatestReleaseUrl, githubFreeTagReleaseUrl];

  String get _activeReleaseRepoLabel =>
      isPremium ? 'FrauxHD/PREMIUM' : 'strixcyron/SOLIDLEAF-TEAM';

  Map<String, String> _releaseRequestHeaders() {
    final headers = <String, String>{
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'solidleaf-launcher-app',
    };

    if (isPremium) {
      if (!GitHubConfig.hasPremiumToken) {
        throw Exception(
          'GITHUB_TOKEN не настроен. [${GitHubConfig.debugState}] '
          '${GitHubConfig.setupHint}',
        );
      }
      headers['Authorization'] = 'Bearer ${GitHubConfig.premiumToken}';
    }

    return headers;
  }

  /// Заголовки для скачивания файла релиза. Ассеты приватного репозитория
  /// нужно качать через API-URL (`asset['url']`) с
  /// `Accept: application/octet-stream` — `browser_download_url` отдаёт 404
  /// без браузерной сессии, даже если метаданные релиза уже получены.
  Map<String, String> _assetDownloadHeaders() {
    if (isPremium) {
      return {
        'Accept': 'application/octet-stream',
        'User-Agent': 'solidleaf-launcher-app',
        'Authorization': 'Bearer ${GitHubConfig.premiumToken}',
      };
    }
    return {'Accept': '*/*', 'User-Agent': 'solidleaf-launcher-app'};
  }

  /// Возвращает URL для скачивания ассета релиза. Для премиум (приватного)
  /// репозитория — API-эндпоинт; для публичного — browser_download_url.
  String? _resolveAssetDownloadUrl(Map<String, dynamic> asset) {
    if (isPremium) {
      final apiUrl = (asset['url'] ?? '').toString();
      if (apiUrl.isNotEmpty) {
        return apiUrl;
      }
    }
    final browserUrl = (asset['browser_download_url'] ?? '').toString();
    return browserUrl.isEmpty ? null : browserUrl;
  }

  @override
  void dispose() {
    _updatePollTimer?.cancel();
    stopGameRunningWatch();
    stopGameProcessWatch();
    telegramAuth.dispose();
    super.dispose();
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    isDarkMode = prefs.getBool('is_dark_mode') ?? true;
    animationsEnabled = prefs.getBool('animations_enabled') ?? true;
    dynamicColorEnabled = prefs.getBool('dynamic_color') ?? false;
    animatedCoverEnabled = prefs.getBool('animated_cover') ?? false;
    animatedCoverIndex = (prefs.getInt('animated_cover_index') ?? 0).clamp(
      0,
      6,
    );
    staticCoverIndex = (prefs.getInt('static_cover_index') ?? 0).clamp(0, 9);
    customCoverPath = prefs.getString('custom_cover_path');
    if (customCoverPath != null &&
        customCoverPath!.isNotEmpty &&
        !File(customCoverPath!).existsSync()) {
      customCoverPath = null;
    }
    final launchActionName = prefs.getString('launch_post_action');
    launchPostAction = LaunchPostAction.values.firstWhere(
      (e) => e.name == launchActionName,
      orElse: () => LaunchPostAction.none,
    );
    backgroundUpdateCheck = prefs.getBool('background_update_check') ?? true;
    favoriteTrackIds = (prefs.getStringList('favorite_tracks') ?? const [])
        .toSet();
    final playbackName = prefs.getString('playback_mode');
    playbackMode = PlaybackMode.values.firstWhere(
      (e) => e.name == playbackName,
      orElse: () => PlaybackMode.all,
    );
    final presetName = prefs.getString('theme_preset');
    themePreset = AppThemePreset.values.firstWhere(
      (e) => e.name == presetName,
      orElse: () => AppThemePreset.dynamicCover,
    );
    final accentValue = prefs.getInt('custom_accent');
    customAccent = accentValue == null ? null : Color(accentValue);
    uiScale = prefs.getDouble('ui_scale') ?? 1.0;
    currentVersion = prefs.getString('installed_version') ?? 'v0.0.0';
    currentArtVersion = prefs.getString('installed_art_version') ?? 'v0.0.0';
    installPath = await _resolveInstallPath(prefs);
    isInstallPathValid = GamePathFinder.isValidInstallPath(installPath);
    if (Platform.isAndroid) {
      addLog('Путь установки (Android): $installPath');
    } else if (isInstallPathValid) {
      addLog('Папка игры: $installPath');
    } else if (Platform.isWindows) {
      addLog(
        'Игра не найдена автоматически — запустите игру через ярлык '
        'или укажите папку с $_gameDataFolderHint',
      );
      startGameProcessWatch();
    }
    await GitHubConfig.warmUp();
    debugPrint('[GitHubConfig] ${GitHubConfig.debugState}');
    await refreshPremiumStatus();
    if (_usesAuthBackendForPremium) {
      addLog(
        'Премиум-релизы: auth-backend (JWT), без GITHUB_TOKEN в приложении',
      );
    } else {
      addLog('GitHub token — ${GitHubConfig.debugState}');
    }
    if (Platform.isAndroid) {
      await checkShizukuStatus();
    }
    await checkForUpdates();
    if (isPremium) {
      await checkForArtUpdates();
    } else {
      hasArtUpdate = false;
    }
    coverAccent = await CoverAccentLoader.load();
    notifyListeners();
    _startBackgroundUpdatePolling();
  }

  Timer? _updatePollTimer;
  bool _updateNotifySent = false;

  void _startBackgroundUpdatePolling() {
    _updatePollTimer?.cancel();
    if (!backgroundUpdateCheck) return;
    _updatePollTimer = Timer.periodic(const Duration(hours: 1), (_) {
      unawaited(_pollUpdatesInBackground());
    });
    Future<void>.delayed(const Duration(minutes: 2), () {
      if (backgroundUpdateCheck) {
        unawaited(_pollUpdatesInBackground());
      }
    });
  }

  Future<void> _pollUpdatesInBackground() async {
    try {
      final hadText = hasUpdate;
      final hadArt = hasArtUpdate;
      await checkForUpdates();
      if (isPremium) {
        await checkForArtUpdates();
      }
      final newlyFound = (!hadText && hasUpdate) || (!hadArt && hasArtUpdate);
      if (newlyFound || ((hasUpdate || hasArtUpdate) && !_updateNotifySent)) {
        _updateNotifySent = true;
        final parts = <String>[];
        if (hasUpdate) parts.add('текст $remoteVersion');
        if (hasArtUpdate) parts.add('графика $remoteArtVersion');
        await NotificationService.instance.showUpdateAvailable(
          title: 'Доступно обновление SolidLeaf',
          body: parts.isEmpty
              ? 'Найдена новая версия русификатора'
              : 'Обновление: ${parts.join(', ')}',
        );
      }
      if (!hasUpdate && !hasArtUpdate) {
        _updateNotifySent = false;
      }
    } catch (e) {
      addLog('Фоновая проверка обновлений: $e');
    }
  }

  /// Ключ первого запуска: true, пока пользователь не закрыл Welcome-диалог.
  static const firstLaunchPrefKey = 'is_first_launch';

  /// true, если приветствие ещё не показывали (по умолчанию — первый запуск).
  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(firstLaunchPrefKey) ?? true;
  }

  /// Помечает Welcome-диалог как просмотренный.
  Future<void> markFirstLaunchSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(firstLaunchPrefKey, false);
  }

  Future<void> toggleTheme() async {
    isDarkMode = !isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDarkMode);
    notifyListeners();
  }

  /// Включить/выключить анимации (дождь и т.п.).
  Future<void> setAnimationsEnabled(bool value) async {
    animationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('animations_enabled', value);
    notifyListeners();
  }

  /// Задать пользовательский акцентный цвет (null — сбросить на цвет пресета).
  Future<void> setCustomAccent(Color? color) async {
    customAccent = color;
    final prefs = await SharedPreferences.getInstance();
    if (color == null) {
      await prefs.remove('custom_accent');
    } else {
      await prefs.setInt('custom_accent', color.toARGB32());
    }
    notifyListeners();
  }

  /// Задать масштаб шрифта интерфейса (в диапазоне 0.8–1.4).
  Future<void> setUiScale(double value) async {
    uiScale = value.clamp(0.8, 1.4);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('ui_scale', uiScale);
    notifyListeners();
  }

  /// Включить/выключить адаптивные цвета системы (Material You).
  Future<void> setDynamicColor(bool value) async {
    dynamicColorEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dynamic_color', value);
    notifyListeners();
  }

  /// Включить/выключить анимированную обложку.
  Future<void> setAnimatedCover(bool value) async {
    animatedCoverEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('animated_cover', value);
    notifyListeners();
  }

  /// Выбрать вариант анимированной обложки (0..6).
  Future<void> setAnimatedCoverIndex(int index) async {
    animatedCoverIndex = index.clamp(0, 6);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('animated_cover_index', animatedCoverIndex);
    notifyListeners();
  }

  Future<void> setStaticCoverIndex(int index) async {
    staticCoverIndex = index.clamp(0, 9);
    customCoverPath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('static_cover_index', staticCoverIndex);
    await prefs.remove('custom_cover_path');
    notifyListeners();
  }

  Future<void> setCustomCoverPath(String? path) async {
    customCoverPath = path;
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.isEmpty) {
      await prefs.remove('custom_cover_path');
    } else {
      await prefs.setString('custom_cover_path', path);
    }
    notifyListeners();
  }

  Future<void> setLaunchPostAction(LaunchPostAction action) async {
    launchPostAction = action;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('launch_post_action', action.name);
    notifyListeners();
  }

  Future<void> setBackgroundUpdateCheck(bool value) async {
    backgroundUpdateCheck = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_update_check', value);
    notifyListeners();
    _startBackgroundUpdatePolling();
  }

  Future<void> toggleFavoriteTrack(String fileName) async {
    if (favoriteTrackIds.contains(fileName)) {
      favoriteTrackIds.remove(fileName);
    } else {
      favoriteTrackIds.add(fileName);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_tracks', favoriteTrackIds.toList());
    notifyListeners();
  }

  bool isFavoriteTrack(String fileName) => favoriteTrackIds.contains(fileName);

  Future<void> setPlaybackMode(PlaybackMode mode) async {
    playbackMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('playback_mode', mode.name);
    notifyListeners();
  }

  /// Выбрать пресет темы.
  Future<void> setThemePreset(AppThemePreset preset) async {
    themePreset = preset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_preset', preset.name);
    notifyListeners();
  }

  static const _gameDataFolderHint = 'reverse1999_Data';

  /// На Android — только захардкоженный путь; на Windows — сохранённый или автопоиск.
  Future<String> _resolveInstallPath(SharedPreferences prefs) async {
    if (Platform.isAndroid) {
      return GamePathFinder.androidInstallPath;
    }

    final saved = prefs.getString(GamePathFinder.prefsKey);
    if (saved != null) {
      final resolved = GamePathFinder.resolveGameRoot(saved);
      if (resolved != null) {
        if (resolved != saved) {
          await prefs.setString(GamePathFinder.prefsKey, resolved);
        }
        return resolved;
      }
    }

    if (Platform.isWindows) {
      final found = await GamePathFinder.findWindowsGamePath();
      if (found != null) {
        await prefs.setString(GamePathFinder.prefsKey, found);
        return found;
      }
      return _windowsInstallPathPlaceholder();
    }

    return '/tmp/reverse1999_localization';
  }

  String _windowsInstallPathPlaceholder() {
    return 'Укажите путь к игре, например: '
        'E:\\Games\\reverse1999_global\\Reverse1999en';
  }

  void _refreshInstallPathState() {
    isInstallPathValid = GamePathFinder.isValidInstallPath(installPath);
  }

  void addLog(String message) {
    logs.add(message);
    if (logs.length > 20) {
      logs.removeAt(0);
    }
    notifyListeners();
  }

  static const List<String> _backupFilesWindows = [
    'reverse1999_Data/StreamingAssets/PersistentRoot/luabytes/9c2019bedb92e2327bfe12024e2922a4.dat',
    'reverse1999_Data/StreamingAssets/PersistentRoot/luabytes/6ac5a62c64b72b07e9383583eef5c3ac.dat',
    'reverse1999_Data/StreamingAssets/PersistentRoot/bundles/cb7baaa1e176dd91dbb5aff21abcb7b0.dat',
    'reverse1999_Data/StreamingAssets/PersistentRoot/configs/datacfg_4.dat',
    'reverse1999_Data/StreamingAssets/PersistentRoot/configs/datacfg_2.dat',
    'reverse1999_Data/StreamingAssets/PersistentRoot/configs/language/json_language_en.json.dat',
    'reverse1999_Data/StreamingAssets/PersistentRoot/configs/language/json_language_server_en.json.dat',
  ];

  static const List<String> _backupFilesAndroid = [
    'files/ResLib/Android/luabytes/6ac5a62c64b72b07e9383583eef5c3ac.dat',
    'files/ResLib/Android/luabytes/9c2019bedb92e2327bfe12024e2922a4.dat',
    'files/ResLib/Android/configs/datacfg_4.dat',
    'files/ResLib/Android/configs/datacfg_2.dat',
    'files/ResLib/Android/configs/language/json_language_server_en.json.dat',
    'files/ResLib/Android/configs/language/json_language_en.json.dat',
    'files/ResLib/Android/bundles/cb7baaa1e176dd91dbb5aff21abcb7b0.dat',
  ];

  // Базовые файлы бесплатной версии (перевод сюжета) — они ДОЛЖНЫ остаться
  // при даунгрейде с Premium на Free. Всё остальное, что перезаписал премиум
  // (меню, интерфейс, конфиги, текстуры), откатывается к оригиналу игры.
  static const List<String> _freeFilesWindows = [
    'reverse1999_Data/StreamingAssets/PersistentRoot/luabytes/9c2019bedb92e2327bfe12024e2922a4.dat',
    'reverse1999_Data/StreamingAssets/PersistentRoot/luabytes/6ac5a62c64b72b07e9383583eef5c3ac.dat',
    'reverse1999_Data/StreamingAssets/PersistentRoot/bundles/cb7baaa1e176dd91dbb5aff21abcb7b0.dat',
  ];

  static const List<String> _freeFilesAndroid = [
    'files/ResLib/Android/luabytes/9c2019bedb92e2327bfe12024e2922a4.dat',
    'files/ResLib/Android/luabytes/6ac5a62c64b72b07e9383583eef5c3ac.dat',
    'files/ResLib/Android/bundles/cb7baaa1e176dd91dbb5aff21abcb7b0.dat',
  ];

  /// Нормализованный набор путей базовых free-файлов для текущей платформы.
  Set<String> get _freeFileSet =>
      (Platform.isAndroid ? _freeFilesAndroid : _freeFilesWindows)
          .map((rel) => rel.replaceAll('\\', '/'))
          .toSet();

  String _backupFolderName() {
    return path.join(installPath, 'backup_solidleaf');
  }

  String _joinPath(String base, String relative) {
    return path.join(base, relative);
  }

  static const int _fsChunkSize = 512 * 1024;

  Future<void> _ensureFileService({int attempts = 4}) async {
    const methodChannel = MethodChannel(shizukuChannel);
    String? lastErrorMessage;

    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        final ok =
            await methodChannel.invokeMethod<bool>('ensureFileService') ??
            false;
        if (ok) {
          if (statusText.startsWith('Shizuku не подключён') ||
              statusText.startsWith('Подключение к Shizuku')) {
            statusText = 'Shizuku: сервис доступен';
            notifyListeners();
          }
          return;
        }
        lastErrorMessage = 'Не удалось подключить Shizuku file service';
      } on PlatformException catch (e) {
        final message =
            'Shizuku file service недоступен: ${e.message ?? e.code}';
        lastErrorMessage = message;
      } catch (e) {
        lastErrorMessage = e.toString();
      }

      if (attempt < attempts) {
        statusText = 'Подключение к Shizuku... попытка $attempt/$attempts';
        notifyListeners();
        await Future.delayed(Duration(milliseconds: 700 * attempt));
      }
    }

    final detail = lastErrorMessage ?? 'неизвестная ошибка';
    final message =
        'Shizuku отвечает, но сервис записи файлов не подключился ($detail). '
        'На HyperOS / Honor / MIUI: перезапустите Shizuku, отключите '
        'оптимизацию батареи для Shizuku и SolidLeaf, снова разрешите доступ '
        'и повторите установку.';
    statusText = message;
    addLog(message);
    notifyListeners();
    throw PatchInstallException(message);
  }

  /// Запрашивает permission у Shizuku, если binder жив, а доступа ещё нет.
  Future<void> _ensureShizukuPermission() async {
    const methodChannel = MethodChannel(shizukuChannel);
    try {
      final state = await methodChannel.invokeMethod<dynamic>('getShizukuState');
      if (state is! Map) return;
      final binderAlive = state['binderAlive'] == true;
      final hasPermission = state['hasPermission'] == true;
      if (binderAlive && !hasPermission) {
        addLog('Запрос разрешения Shizuku...');
        await methodChannel.invokeMethod<bool>('requestPermission');
        await Future<void>.delayed(const Duration(milliseconds: 900));
        await checkShizukuStatus();
      }
    } catch (e) {
      addLog('Не удалось запросить разрешение Shizuku: $e');
    }
  }

  /// Уточняет пакет игры (EN/CN) и путь Android/data перед установкой.
  Future<void> _resolveAndroidGameInstallPath() async {
    if (!Platform.isAndroid) return;
    const methodChannel = MethodChannel(shizukuChannel);
    try {
      final pkg =
          await methodChannel.invokeMethod<String>('resolveGamePackage');
      if (pkg == null || pkg.isEmpty) {
        addLog(
          'Пакет игры не найден — используем путь по умолчанию: $installPath',
        );
        return;
      }
      final resolved = GamePathFinder.androidDataPathFor(pkg);
      if (resolved != installPath) {
        installPath = resolved;
        _refreshInstallPathState();
        addLog('Путь Android/data игры: $installPath (пакет $pkg)');
        notifyListeners();
      }
    } catch (e) {
      addLog('resolveGamePackage: $e — оставляем $installPath');
    }
  }

  Future<bool> _fsMkdirs(String targetPath) async {
    const methodChannel = MethodChannel(shizukuChannel);
    try {
      return await methodChannel.invokeMethod<bool>('fsMkdirs', targetPath) ??
          false;
    } on PlatformException catch (e) {
      throw Exception('mkdirs: ${e.message ?? e.code} ($targetPath)');
    }
  }

  Future<bool> _fsWriteChunk(
    String targetPath,
    Uint8List data,
    bool append,
  ) async {
    const methodChannel = MethodChannel(shizukuChannel);
    try {
      return await methodChannel.invokeMethod<bool>('fsWriteChunk', {
            'path': targetPath,
            'data': data,
            'append': append,
          }) ??
          false;
    } on PlatformException catch (e) {
      throw Exception('writeChunk: ${e.message ?? e.code} ($targetPath)');
    }
  }

  Future<Uint8List?> _fsReadChunk(
    String targetPath,
    int offset,
    int length,
  ) async {
    const methodChannel = MethodChannel(shizukuChannel);
    try {
      final result = await methodChannel.invokeMethod('fsReadChunk', {
        'path': targetPath,
        'offset': offset,
        'length': length,
      });
      if (result == null) return null;
      return Uint8List.fromList(List<int>.from(result as List));
    } on PlatformException catch (e) {
      throw Exception('readChunk: ${e.message ?? e.code} ($targetPath)');
    }
  }

  Future<int> _fsFileSize(String targetPath) async {
    const methodChannel = MethodChannel(shizukuChannel);
    try {
      final result = await methodChannel.invokeMethod<int>(
        'fsFileSize',
        targetPath,
      );
      return result ?? -1;
    } on PlatformException catch (e) {
      throw Exception('fileSize: ${e.message ?? e.code} ($targetPath)');
    }
  }

  Future<bool> _fsDeleteRecursive(String targetPath) async {
    const methodChannel = MethodChannel(shizukuChannel);
    try {
      return await methodChannel.invokeMethod<bool>(
            'fsDeleteRecursive',
            targetPath,
          ) ??
          false;
    } on PlatformException catch (e) {
      throw Exception('delete: ${e.message ?? e.code} ($targetPath)');
    }
  }

  Future<bool> _fsExists(String targetPath) async {
    const methodChannel = MethodChannel(shizukuChannel);
    try {
      return await methodChannel.invokeMethod<bool>('fsExists', targetPath) ??
          false;
    } on PlatformException catch (e) {
      throw Exception('exists: ${e.message ?? e.code} ($targetPath)');
    }
  }

  Future<void> _fsCopyFile(String src, String dst) async {
    await _fsMkdirs(path.dirname(dst));
    // Перед перезаписью бэкапа убираем старый файл (OEM truncate).
    if (await _fsExists(dst)) {
      await _fsDeleteRecursive(dst);
    }
    final size = await _fsFileSize(src);
    if (size < 0) {
      throw Exception('Источник не найден или недоступен: $src');
    }
    if (size == 0) {
      final ok = await _fsWriteChunk(dst, Uint8List(0), false);
      if (!ok) throw Exception('Не удалось создать пустой файл: $dst');
      return;
    }
    var offset = 0;
    var first = true;
    while (offset < size) {
      final len = (offset + _fsChunkSize < size)
          ? _fsChunkSize
          : (size - offset);
      final chunk = await _fsReadChunk(src, offset, len);
      if (chunk == null) {
        throw Exception('Не удалось прочитать $src на смещении $offset');
      }
      final ok = await _fsWriteChunk(dst, chunk, !first);
      if (!ok) {
        throw Exception('Не удалось записать в $dst');
      }
      first = false;
      offset += len;
    }
  }

  Future<void> _fsWriteLocalFile(File localFile, String dstPath) async {
    Object? lastError;
    // 1–2 повтора: на Honor/HyperOS binder иногда отваливается mid-copy.
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        await _fsWriteLocalFileOnce(localFile, dstPath);
        return;
      } catch (e) {
        lastError = e;
        addLog(
          'Запись ${path.basename(dstPath)} не удалась '
          '(попытка $attempt/2): $e',
        );
        if (attempt < 2) {
          try {
            await _ensureFileService(attempts: 2);
          } catch (_) {
            // Следующая попытка всё равно пойдёт — покажем итоговую ошибку.
          }
          await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
        }
      }
    }
    throw lastError ?? Exception('Не удалось записать $dstPath');
  }

  Future<void> _fsWriteLocalFileOnce(File localFile, String dstPath) async {
    await _fsMkdirs(path.dirname(dstPath));
    // Удаляем целевой файл до записи — обход O_TRUNC на HyperOS/Honor.
    if (await _fsExists(dstPath)) {
      final deleted = await _fsDeleteRecursive(dstPath);
      if (!deleted && await _fsExists(dstPath)) {
        addLog('Предупреждение: не удалось удалить перед записью: $dstPath');
      }
    }
    final data = await localFile.readAsBytes();
    if (data.isEmpty) {
      final ok = await _fsWriteChunk(dstPath, Uint8List(0), false);
      if (!ok) throw Exception('Не удалось создать пустой файл: $dstPath');
      return;
    }
    var offset = 0;
    var first = true;
    while (offset < data.length) {
      final end = (offset + _fsChunkSize < data.length)
          ? offset + _fsChunkSize
          : data.length;
      final chunk = Uint8List.sublistView(data, offset, end);
      final ok = await _fsWriteChunk(dstPath, chunk, !first);
      if (!ok) {
        throw Exception('Не удалось записать чанк в $dstPath (offset=$offset)');
      }
      first = false;
      offset = end;
    }
  }

  Future<void> _backupOnlyOverwrittenFiles(
    String sourceDir,
    String finalTarget,
    List<File> archiveFiles, {
    String? kind,
  }) async {
    final backupDirPath = _backupFolderName();
    addLog('Создание резервной копии файлов...');

    lastBackupFiles = [];
    lastBackupKind = kind;

    try {
      if (Platform.isAndroid) {
        if (!isShizukuActive) {
          addLog('Shizuku не активен — создание бэкапа на Android невозможно');
          throw Exception('Shizuku required for Android backup');
        }
        await _ensureFileService();
        final exists = await _fsExists(backupDirPath);
        if (exists) {
          final ok = await _fsDeleteRecursive(backupDirPath);
          if (!ok) {
            addLog('Не удалось очистить предыдущий бэкап через Shizuku');
          }
        }
        await _fsMkdirs(backupDirPath);
      } else {
        final backupDir = Directory(backupDirPath);
        if (await backupDir.exists()) {
          await backupDir.delete(recursive: true);
        }
        await backupDir.create(recursive: true);
      }

      var copied = 0;
      for (final archiveFile in archiveFiles) {
        final rel = path.relative(archiveFile.path, from: sourceDir);
        final targetPath = path.join(finalTarget, rel);

        if (Platform.isAndroid) {
          final exists = await _fsExists(targetPath);
          if (!exists) {
            continue;
          }
          final backupPath = path.join(backupDirPath, rel);
          await _fsCopyFile(targetPath, backupPath);
          copied++;
          lastBackupFiles.add(rel);
          addLog('Бэкап (Shizuku): $rel');
        } else {
          final targetFile = File(targetPath);
          if (!await targetFile.exists()) {
            continue;
          }
          final backupFile = File(path.join(backupDirPath, rel));
          await backupFile.parent.create(recursive: true);
          await targetFile.copy(backupFile.path);
          copied++;
          lastBackupFiles.add(rel);
          addLog('Бэкап: $rel');
        }
      }

      addLog(
        copied == 0
            ? 'Нечего копировать в бэкап — целевые файлы не найдены.'
            : 'Создание резервной копии завершено',
      );
    } catch (e) {
      addLog('Ошибка создания бэкапа: $e');
      rethrow;
    }
  }

  Future<void> createBackup() async {
    final backupDirPath = _backupFolderName();
    final files = Platform.isWindows
        ? _backupFilesWindows
        : _backupFilesAndroid;
    if (Platform.isAndroid) {
      if (!isShizukuActive) {
        addLog('Shizuku не активен — создание бэкапа на Android невозможно');
        throw Exception('Shizuku required for Android backup');
      }
      await _ensureFileService();
    }

    final backupDir = Directory(backupDirPath);
    if (await backupDir.exists()) {
      await backupDir.delete(recursive: true);
    }
    await backupDir.create(recursive: true);

    for (final rel in files) {
      final src = _joinPath(installPath, rel);
      final dst = _joinPath(backupDirPath, rel);

      if (Platform.isWindows) {
        final srcFile = File(src);
        if (!await srcFile.exists()) {
          addLog('Исходный файл не найден, пропуск: $src');
          continue;
        }
        final dstFile = File(dst);
        await dstFile.parent.create(recursive: true);
        await srcFile.copy(dst);
        addLog('Скопировано в бэкап: $rel');
      } else if (Platform.isAndroid) {
        final srcExists = await _fsExists(src);
        if (!srcExists) {
          addLog('Исходный файл не найден, пропуск (Android): $src');
          continue;
        }
        await _fsCopyFile(src, dst);
        addLog('Shizuku: скопирован в бэкапе: $rel');
      }
    }

    addLog('Создание резервной копии завершено');
  }

  Future<void> restoreBackup() async {
    addLog('Восстановление из бэкапа...');
    final backupDirPath = _backupFolderName();
    try {
      if (Platform.isAndroid) {
        if (!isShizukuActive) {
          addLog('Shizuku не активен — восстановление на Android невозможно');
          throw Exception('Shizuku required for Android restore');
        }
        await _ensureFileService();
      }

      final files = Platform.isWindows
          ? _backupFilesWindows
          : _backupFilesAndroid;

      for (final rel in files) {
        final src = _joinPath(backupDirPath, rel);
        final dst = _joinPath(installPath, rel);

        if (Platform.isWindows) {
          final srcFile = File(src);
          if (!await srcFile.exists()) {
            addLog('В бэкапе не найден файл, пропуск: $src');
            continue;
          }
          await File(dst).parent.create(recursive: true);
          await srcFile.copy(dst);
          addLog('Восстановлен файл: $rel');
        } else if (Platform.isAndroid) {
          final srcExists = await _fsExists(src);
          if (!srcExists) {
            addLog('В бэкапе не найден файл, пропуск (Android): $src');
            continue;
          }

          await _fsCopyFile(src, dst);
          addLog('Shizuku: восстановлен файл: $rel');
        }
      }

      if (Platform.isAndroid) {
        try {
          final exists = await _fsExists(backupDirPath);
          if (exists) {
            final ok = await _fsDeleteRecursive(backupDirPath);
            if (ok) {
              addLog('Папка бэкапа удалена (Shizuku)');
            } else {
              addLog('Не удалось удалить папку бэкапа через Shizuku');
            }
          }
        } catch (e) {
          addLog(
            'Не удалось удалить папку бэкапа через Shizuku: ${e.toString()}',
          );
        }
      } else {
        final backupDir = Directory(backupDirPath);
        if (await backupDir.exists()) {
          await backupDir.delete(recursive: true);
          addLog('Папка бэкапа удалена');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('installed_version', 'v0.0.0');
      currentVersion = 'v0.0.0';
      hasUpdate = false;
      statusText = 'Русификатор удалён. Состояние: Не установлено.';
      addLog('Восстановление завершено. Версия сброшена.');
      notifyListeners();
    } catch (e) {
      addLog('Ошибка восстановления: $e');
      rethrow;
    }
  }

  Future<void> restoreBackupKind(String kind) async {
    addLog('Восстановление из бэкапа (подвид: $kind)...');
    final backupDirPath = _backupFolderName();
    try {
      if (Platform.isAndroid) {
        if (!isShizukuActive) {
          addLog('Shizuku не активен — восстановление на Android невозможно');
          throw Exception('Shizuku required for Android restore');
        }
        await _ensureFileService();
      }

      List<String> toRestore = [];
      final backupDir = Directory(backupDirPath);

      if (lastBackupFiles.isNotEmpty &&
          (kind == 'all' || lastBackupKind == kind)) {
        toRestore = List.from(lastBackupFiles);
      } else if (kind == 'art') {
        if (await backupDir.exists()) {
          toRestore = backupDir
              .listSync(recursive: true)
              .whereType<File>()
              .map((f) => path.relative(f.path, from: backupDirPath))
              .toList();
        } else {
          toRestore = [];
        }
      } else {
        toRestore = Platform.isWindows
            ? _backupFilesWindows
            : _backupFilesAndroid;
      }

      if (toRestore.isEmpty) {
        addLog('В бэкапе не найдены файлы для восстановления (kind=$kind).');
        throw Exception('No backup files found for restore');
      }

      for (final rel in toRestore) {
        final src = _joinPath(backupDirPath, rel);
        final dst = _joinPath(installPath, rel);

        if (Platform.isWindows) {
          final srcFile = File(src);
          if (!await srcFile.exists()) {
            addLog('В бэкапе не найден файл, пропуск: $src');
            continue;
          }
          await File(dst).parent.create(recursive: true);
          await srcFile.copy(dst);
          addLog('Восстановлен файл: $rel');
        } else if (Platform.isAndroid) {
          final srcExists = await _fsExists(src);
          if (!srcExists) {
            addLog('В бэкапе не найден файл, пропуск (Android): $src');
            continue;
          }
          await _fsCopyFile(src, dst);
          addLog('Shizuku: восстановлен файл: $rel');
        }
      }

      if (Platform.isAndroid) {
        try {
          final exists = await _fsExists(backupDirPath);
          if (exists) {
            final ok = await _fsDeleteRecursive(backupDirPath);
            if (ok) {
              addLog('Папка бэкапа удалена (Shizuku)');
            } else {
              addLog('Не удалось удалить папку бэкапа через Shizuku');
            }
          }
        } catch (e) {
          addLog(
            'Не удалось удалить папку бэкапа через Shizuku: ${e.toString()}',
          );
        }
      } else {
        final backupDirLocal = Directory(backupDirPath);
        if (await backupDirLocal.exists()) {
          await backupDirLocal.delete(recursive: true);
          addLog('Папка бэкапа удалена');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      if (kind == 'art') {
        await prefs.setString('installed_art_version', 'v0.0.0');
        currentArtVersion = 'v0.0.0';
        hasArtUpdate = false;
        statusText = 'Русификатор графики удалён. Состояние: Не установлено.';
      } else if (kind == 'text') {
        await prefs.setString('installed_version', 'v0.0.0');
        currentVersion = 'v0.0.0';
        hasUpdate = false;
        statusText = 'Русификатор текста удалён. Состояние: Не установлено.';
      } else {
        await prefs.setString('installed_version', 'v0.0.0');
        await prefs.setString('installed_art_version', 'v0.0.0');
        currentVersion = 'v0.0.0';
        currentArtVersion = 'v0.0.0';
        hasUpdate = false;
        hasArtUpdate = false;
        statusText = 'Русификатор удалён полностью. Состояние: Не установлено.';
      }

      addLog('Восстановление завершено. Версии сброшены.');
      notifyListeners();
    } catch (e) {
      addLog('Ошибка восстановления: $e');
      rethrow;
    }
  }

  /// Diagnostic: which GitHub account does the currently-sent token map to,
  /// and does it see the premium repo? Uses the SAME headers as the failing
  /// request so we can tell whether the in-app token differs from expectations.
  Future<String> _diagnoseTokenIdentity(Map<String, String> headers) async {
    String user = 'user=?';
    String repo = 'repo=?';
    try {
      final u = await _dio.get<dynamic>(
        'https://api.github.com/user',
        options: Options(headers: headers, validateStatus: (_) => true),
      );
      if (u.statusCode == 200 && u.data is Map) {
        user = 'user=${(u.data as Map)['login']}';
      } else {
        user = 'user_status=${u.statusCode}';
      }
    } catch (e) {
      user = 'user_err';
    }
    try {
      final r = await _dio.get<dynamic>(
        'https://api.github.com/repos/FrauxHD/PREMIUM',
        options: Options(headers: headers, validateStatus: (_) => true),
      );
      repo = 'repo_status=${r.statusCode}';
    } catch (e) {
      repo = 'repo_err';
    }
    final diag = '$user, $repo';
    addLog('Диагностика токена: $diag');
    return diag;
  }

  Future<Map<String, dynamic>> _fetchLatestRelease({bool force = false}) async {
    if (_usesAuthBackendForPremium) {
      return _fetchLatestReleaseViaBackend(force: force);
    }

    await GitHubConfig.warmUp(force: !GitHubConfig.hasPremiumToken);

    if (!force &&
        _cachedRelease != null &&
        _cachedReleaseAt != null &&
        _cachedReleaseIsPremium == isPremium &&
        DateTime.now().difference(_cachedReleaseAt!) < _releaseCacheTtl) {
      return _cachedRelease!;
    }

    final headers = _releaseRequestHeaders();
    addLog('GitHub → $_activeReleaseRepoLabel [${GitHubConfig.debugState}]');

    final urls = _activeReleaseApiUrls;
    int lastStatus = 0;
    bool lastSentAuth = false;
    String? lastGhMessage;

    for (var i = 0; i < urls.length; i++) {
      final url = urls[i];
      final response = await _dio.get<dynamic>(
        url,
        options: Options(
          headers: headers,
          validateStatus: (_) => true,
          responseType: ResponseType.json,
        ),
      );

      final status = response.statusCode ?? 0;
      final sentAuth = response.requestOptions.headers.containsKey(
        'Authorization',
      );
      final ghMessage = response.data is Map
          ? (response.data as Map)['message']?.toString()
          : null;
      addLog(
        'GitHub ответил $status (auth=$sentAuth, msg=${ghMessage ?? "—"}) '
        '${url.endsWith("/latest") ? "[latest]" : "[tags/update]"}',
      );

      lastStatus = status;
      lastSentAuth = sentAuth;
      lastGhMessage = ghMessage;

      // Auth/rate-limit failures are terminal — trying the next URL won't help.
      if (status == 401) {
        throw Exception(
          'GitHub отклонил авторизацию (401). Проверьте GITHUB_TOKEN для $_activeReleaseRepoLabel.',
        );
      }
      if (status == 403 || status == 429) {
        throw Exception('Превышен лимит запросов к GitHub. Попробуйте позже.');
      }

      if (status == 200 && response.data != null) {
        final data = Map<String, dynamic>.from(response.data as Map);
        _cachedRelease = data;
        _cachedReleaseAt = DateTime.now();
        _cachedReleaseIsPremium = isPremium;
        return data;
      }

      // 404 → the release may live under the named tag instead; try next URL.
      if (status == 404 && i < urls.length - 1) {
        continue;
      }
      if (status != 404) {
        throw Exception('Ошибка сервера GitHub: $status');
      }
    }

    // All candidate URLs returned 404.
    if (isPremium) {
      final who = await _diagnoseTokenIdentity(headers);
      throw Exception(
        'Премиум-релиз в $_activeReleaseRepoLabel недоступен (404). '
        'GitHub: "${lastGhMessage ?? "Not Found"}", auth=$lastSentAuth, $who. '
        '[${GitHubConfig.debugState}]',
      );
    }
    throw Exception(
      'Релиз не найден в репозитории $_activeReleaseRepoLabel (HTTP $lastStatus).',
    );
  }

  /// Метаданные релиза через FastAPI (токен GitHub остаётся на сервере).
  Future<Map<String, dynamic>> _fetchLatestReleaseViaBackend({
    bool force = false,
  }) async {
    if (!force &&
        _cachedRelease != null &&
        _cachedReleaseAt != null &&
        _cachedReleaseIsPremium == isPremium &&
        DateTime.now().difference(_cachedReleaseAt!) < _releaseCacheTtl) {
      return _cachedRelease!;
    }

    addLog('Auth-backend → /api/release/latest');
    try {
      final data = await telegramAuth.fetchLatestRelease();
      _cachedRelease = data;
      _cachedReleaseAt = DateTime.now();
      _cachedReleaseIsPremium = isPremium;
      return data;
    } on TelegramAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  List<Map<String, dynamic>> _releaseAssets(Map<String, dynamic> release) {
    final raw = release['assets'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((asset) => Map<String, dynamic>.from(asset))
        .toList();
  }

  String get _platformAssetKey => Platform.isWindows ? 'pc' : 'android';

  Map<String, dynamic>? _findReleaseAsset(
    List<Map<String, dynamic>> assets,
    bool Function(String name, String url) test,
  ) {
    for (final asset in assets) {
      final name = (asset['name'] ?? '').toString().toLowerCase();
      final url = (asset['browser_download_url'] ?? '')
          .toString()
          .toLowerCase();
      if (test(name, url)) return asset;
    }
    return null;
  }

  /// Public GitHub currently ships free text packs as
  /// `1.5.0.19_pc_free.zip` / `1.5.0.19_android_free.zip`. Prefer `*_full.zip`
  /// when present, then `*_free.zip`, then any non-art zip for this platform.
  Map<String, dynamic>? _pickTextAsset(List<Map<String, dynamic>> assets) {
    final platformKey = _platformAssetKey;
    if (isPremium) {
      return _findReleaseAsset(
        assets,
        (name, url) =>
            name.contains('_${platformKey}_full.zip') ||
            name.endsWith('_${platformKey}_full.zip'),
      );
    }

    return _findReleaseAsset(
      assets,
      (name, url) =>
          name.contains('_${platformKey}_free.zip') ||
          name.endsWith('_${platformKey}_free.zip'),
    );
  }

  /// Premium art packs: `*_pc_art.zip` / `*_android_art.zip`.
  Map<String, dynamic>? _pickArtAsset(List<Map<String, dynamic>> assets) {
    final platformKey = _platformAssetKey;
    return _findReleaseAsset(
      assets,
      (name, url) =>
          name.contains('_${platformKey}_art.zip') ||
          name.endsWith('_${platformKey}_art.zip'),
    );
  }

  String _versionFromAsset(
    Map<String, dynamic> asset,
    Map<String, dynamic> release,
  ) {
    final name = (asset['name'] ?? '').toString();
    final verMatch = RegExp(r'(\d+(?:\.\d+)+)').firstMatch(name);
    if (verMatch != null) {
      return 'v${verMatch.group(1)}';
    }
    return _releaseVersionLabel(release);
  }

  /// Версия из полей релиза, если тег — служебный (например `update`).
  String _releaseVersionLabel(Map<String, dynamic> release) {
    for (final field in [release['name'], release['tag_name']]) {
      final value = (field ?? '').toString();
      if (_looksLikeSemanticVersion(value)) {
        return value.startsWith('v') ? value : 'v$value';
      }
    }
    return (release['tag_name'] ?? release['name'] ?? 'v0.0.0').toString();
  }

  bool _looksLikeSemanticVersion(String value) {
    return RegExp(r'^v?\d+(?:\.\d+)+').hasMatch(value);
  }

  Future<void> checkForUpdates() async {
    try {
      statusText = 'Проверка обновлений...';
      addLog('Запрос GitHub Releases ($_activeReleaseRepoLabel)...');
      final data = await _fetchLatestRelease(force: true);
      final version = _releaseVersionLabel(data);
      final body = (data['body'] ?? 'Без списка изменений').toString();
      final assets = _releaseAssets(data);
      final zipAsset = _pickTextAsset(assets);

      remoteVersion = zipAsset != null
          ? _versionFromAsset(zipAsset, data)
          : version;
      changelog = body;

      if (zipAsset == null) {
        hasUpdate = false;
        final names = assets
            .map((a) => (a['name'] ?? '').toString())
            .join(', ');
        statusText = 'Архив текста для вашей платформы не найден в релизе';
        addLog(statusText);
        addLog('Файлы в релизе: ${names.isEmpty ? '(пусто)' : names}');
        notifyListeners();
        return;
      }

      final zipUrl = (zipAsset['browser_download_url'] ?? '').toString();
      final zipName = (zipAsset['name'] ?? '').toString();
      final isNewer = _isVersionNewer(remoteVersion, currentVersion);
      hasUpdate = isNewer;
      statusText = isNewer
          ? 'Доступно обновление'
          : 'Установлена актуальная версия';
      addLog('Версия на сервере: $remoteVersion');
      addLog('Локальная версия: $currentVersion');
      addLog('Архив текста: $zipName');
      addLog('Ссылка на архив: $zipUrl');
      notifyListeners();
    } on TimeoutException catch (_) {
      statusText = 'Превышено время ожидания сервера';
      addLog(statusText);
      notifyListeners();
    } on SocketException catch (_) {
      statusText = 'Нет подключения к интернету';
      addLog(statusText);
      notifyListeners();
    } on DioException catch (error) {
      _handleDioError(error);
    } catch (e) {
      statusText = e.toString();
      addLog(statusText);
      notifyListeners();
    }
  }

  Future<void> checkForArtUpdates() async {
    if (!isPremium) {
      hasArtUpdate = false;
      notifyListeners();
      return;
    }

    try {
      addLog('Проверка версии премиум-текстур ($_activeReleaseRepoLabel)...');
      final data = await _fetchLatestRelease();
      final assets = _releaseAssets(data);
      final artAsset = _pickArtAsset(assets);

      if (artAsset != null) {
        remoteArtVersion = _versionFromAsset(artAsset, data);
      } else {
        remoteArtVersion = _releaseVersionLabel(data);
        addLog(
          'Art-архив не найден в релизе, версия взята из тега: $remoteArtVersion',
        );
      }

      hasArtUpdate = _isVersionNewer(remoteArtVersion, currentArtVersion);
      addLog(
        'Версия текстур на сервере: $remoteArtVersion, локально: $currentArtVersion',
      );
      notifyListeners();
    } catch (e) {
      addLog('Не удалось проверить версию текстур: $e');
    }
  }

  Future<void> selectInstallPath() async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle:
          'Выберите папку с игрой (где лежит ${GamePathFinder.dataFolderName})',
    );
    if (selected == null || selected.isEmpty) {
      return;
    }

    // Не сохраняем некорректный путь — иначе установка уйдёт «в никуда».
    // Родительская обёртка (Games\reverse1999_global) резолвится во вложенный корень.
    final resolved = GamePathFinder.resolveGameRoot(selected);
    final error = resolved == null
        ? GamePathFinder.validationError(selected)
        : null;
    if (error != null || resolved == null) {
      final facing = UserFacingError(
        title: 'Неверная папка игры',
        summary: error ??
            'В выбранной папке нет reverse1999_Data. '
                'Укажите Reverse1999en или корень Steam-версии.',
        steps: const [
          'Выберите каталог, где лежит reverse1999_Data '
              '(часто …\\reverse1999_global\\Reverse1999en)',
          'Или запустите игру — лаунчер может найти путь сам',
        ],
      );
      lastUserFacingError = facing;
      lastUserError = facing.flatMessage;
      statusText = facing.summary;
      addLog('Выбор папки отклонён: ${facing.summary}');
      notifyListeners();
      return;
    }

    installPath = resolved;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(GamePathFinder.prefsKey, resolved);
    _refreshInstallPathState();
    stopGameProcessWatch();
    lastUserError = null;
    lastUserFacingError = null;
    addLog('Папка игры: $installPath');
    notifyListeners();
  }

  /// Повторный автопоиск (если игра установилась после запуска лаунчера).
  Future<void> detectInstallPath() async {
    if (!Platform.isWindows) {
      return;
    }

    final found = await GamePathFinder.findWindowsGamePath();
    if (found == null) {
      addLog('Автопоиск: игра не найдена на дисках — ждём запуск процесса');
      startGameProcessWatch();
      notifyListeners();
      return;
    }

    await _applyDetectedGamePath(found, source: 'автопоиск по дискам/реестру');
  }

  /// Старт мониторинга Reverse1999.exe (только Windows, только если путь ещё невалиден).
  void startGameProcessWatch() {
    if (!Platform.isWindows || isInstallPathValid) {
      return;
    }
    if (_processTracker.isRunning) {
      isWaitingForGameProcess = true;
      notifyListeners();
      return;
    }

    isWaitingForGameProcess = true;
    addLog('Мониторинг процесса: ожидание Reverse1999.exe...');
    notifyListeners();

    _processTracker.start(
      onFound: (gameDir) {
        unawaited(_onGameProcessFound(gameDir));
      },
    );
  }

  /// Пауза при сворачивании / уходе приложения в фон.
  void pauseGameProcessWatch() {
    if (!_processTracker.isRunning && !isWaitingForGameProcess) return;
    _processTracker.stop();
    // Флаг ожидания оставляем — UI покажет, что мониторинг на паузе при необходимости.
    notifyListeners();
  }

  /// Возобновление после разворота окна, если путь всё ещё неизвестен.
  void resumeGameProcessWatch() {
    if (!Platform.isWindows || isInstallPathValid) return;
    startGameProcessWatch();
  }

  /// Полная остановка (успех, dispose, ручной выбор пути).
  void stopGameProcessWatch() {
    _processTracker.stop();
    if (isWaitingForGameProcess) {
      isWaitingForGameProcess = false;
      notifyListeners();
    }
  }

  Future<void> _onGameProcessFound(String gameDir) async {
    final resolved = GamePathFinder.resolveGameRoot(gameDir);
    if (resolved == null) {
      // Процесс есть, но рядом нет reverse1999_Data — продолжаем ждать.
      addLog(
        'Процесс найден ($gameDir), но нет ${GamePathFinder.dataFolderName} — продолжаем ожидание',
      );
      startGameProcessWatch();
      return;
    }
    await _applyDetectedGamePath(
      resolved,
      source: 'процесс reverse1999.exe',
    );
  }

  Future<void> _applyDetectedGamePath(
    String found, {
    required String source,
  }) async {
    installPath = found;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(GamePathFinder.prefsKey, found);
    _refreshInstallPathState();
    stopGameProcessWatch();
    gamePathJustDetected = true;
    lastUserError = null;
    statusText = 'Папка игры определена';
    addLog('Путь к игре ($source): $installPath');
    notifyListeners();

    // Гасим «успех» через пару секунд.
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (gamePathJustDetected) {
        gamePathJustDetected = false;
        notifyListeners();
      }
    });
  }

  /// Запуск Reverse: 1999 (Windows — exe, Android — пакет игры).
  Future<void> launchGame() async {
    if (Platform.isAndroid) {
      try {
        const methodChannel = MethodChannel(shizukuChannel);
        final launchedPkg =
            await methodChannel.invokeMethod<String>('launchGame');
        statusText = 'Игра запущена';
        addLog(
          'Запуск игры (Android): ${launchedPkg ?? 'com.bluepoch.m.en.reverse1999'}',
        );
        notifyListeners();
      } on PlatformException catch (e) {
        throw Exception(
          e.message?.isNotEmpty == true
              ? e.message!
              : 'Не удалось открыть игру. Убедитесь, что Reverse: 1999 установлена.',
        );
      }
      return;
    }

    if (!isInstallPathValid) {
      throw Exception(
        'Укажите папку с установленной игрой '
        '(нужна папка ${GamePathFinder.dataFolderName}).',
      );
    }

    final exe = GamePathFinder.findGameExecutable(installPath);
    if (exe == null) {
      throw Exception(
        'В папке игры не найден reverse1999.exe. '
        'Проверьте путь установки.',
      );
    }

    final root = GamePathFinder.resolveGameRoot(installPath) ?? installPath;
    if (root != installPath) {
      installPath = root;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(GamePathFinder.prefsKey, root);
      _refreshInstallPathState();
    }

    await Process.start(
      exe,
      const <String>[],
      workingDirectory: root,
      mode: ProcessStartMode.detached,
    );
    statusText = 'Игра запущена';
    addLog('Запуск игры: $exe');
    notifyListeners();
    startGameRunningWatch();
  }

  /// Следит за процессом игры после запуска из лаунчера.
  /// Когда процесс исчез — обновляет статус «Последняя активность».
  void startGameRunningWatch() {
    if (!Platform.isWindows) return;
    stopGameRunningWatch();
    isGameRunning = true;
    _sawGameProcessAfterLaunch = false;
    final startedAt = DateTime.now();
    _gameRunningWatch = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_tickGameRunningWatch(startedAt));
    });
    Future<void>.delayed(const Duration(seconds: 2), () {
      unawaited(_tickGameRunningWatch(startedAt));
    });
  }

  Future<void> _tickGameRunningWatch(DateTime startedAt) async {
    if (_gameRunningWatch == null || _gameRunningProbeInFlight) return;
    _gameRunningProbeInFlight = true;
    try {
      final running = await ProcessTrackerService.isGameProcessRunning();
      if (running) {
        _sawGameProcessAfterLaunch = true;
        if (!isGameRunning || statusText != 'Игра запущена') {
          isGameRunning = true;
          statusText = 'Игра запущена';
          notifyListeners();
        }
        return;
      }

      final waited = DateTime.now().difference(startedAt);
      // Ждём появления процесса после старта (до ~20 с), потом считаем выход.
      if (!_sawGameProcessAfterLaunch && waited < const Duration(seconds: 20)) {
        return;
      }

      isGameRunning = false;
      stopGameRunningWatch();
      statusText = 'Игра закрыта';
      addLog(
        _sawGameProcessAfterLaunch
            ? 'Процесс игры завершён'
            : 'Процесс игры не обнаружен / уже закрыт',
      );
      notifyListeners();
    } finally {
      _gameRunningProbeInFlight = false;
    }
  }

  void stopGameRunningWatch() {
    _gameRunningWatch?.cancel();
    _gameRunningWatch = null;
  }

  Future<void> installOrUpdate() async {
    try {
      if (!Platform.isAndroid && !isInstallPathValid) {
        await detectInstallPath();
        if (!isInstallPathValid) {
          _failInstall(
            PatchInstallException(
              'Укажите папку с установленной игрой '
              '(нужна папка ${GamePathFinder.dataFolderName}).',
            ),
          );
          return;
        }
      }

      if (remoteVersion == '—') {
        await checkForUpdates();
      }

      if (!hasUpdate && currentVersion != 'v0.0.0') {
        addLog('Обновлений не требуется. Установка уже актуальна.');
        statusText = 'Установлена актуальная версия';
        lastUserError = null;
        lastUserFacingError = null;
        notifyListeners();
        return;
      }

      final asset = await _getAssets();
      await _downloadAndInstallReleaseAsset(asset, kind: 'text');
    } catch (e) {
      _failInstall(e);
    }
  }

  Future<void> installArtPack() async {
    try {
      if (!isPremium) {
        _failInstall(
          PatchInstallException(
            'Текстуры доступны только с платной подпиской.',
          ),
        );
        return;
      }

      if (!Platform.isAndroid && !isInstallPathValid) {
        await detectInstallPath();
        if (!isInstallPathValid) {
          _failInstall(
            PatchInstallException(
              'Укажите папку с установленной игрой '
              '(нужна папка ${GamePathFinder.dataFolderName}).',
            ),
          );
          return;
        }
      }

      final asset = await _getArtAsset();
      await _downloadAndInstallReleaseAsset(asset, kind: 'art');
    } catch (e) {
      _failInstall(e);
    }
  }

  /// Скачивание премиум-архива через auth-backend (Android без GITHUB_TOKEN).
  Future<void> _downloadAndInstallViaBackend({required String kind}) async {
    final assetKind = kind == 'art' ? 'art' : 'full';

    try {
      _resetInstallUiState();
      isDownloading = true;
      downloadingKind = kind;
      downloadProgress = 0;
      notifyListeners();

      addLog('Загрузка через auth-backend ($assetKind)...');
      final zipFile = await telegramAuth.downloadPremiumAsset(
        assetKind: assetKind,
        onProgress: (received, total) {
          if (total <= 0) {
            return;
          }
          final progress = received / total;
          downloadProgress = progress;
          statusText = kind == 'art'
              ? 'Загрузка текстур: ${(progress * 100).toStringAsFixed(0)}%'
              : 'Загрузка: ${(progress * 100).toStringAsFixed(0)}%';
          notifyListeners();
        },
      );

      addLog('Архив загружен: ${zipFile.path}');
      await _extractArchive(zipFile.path, installPath, archiveKind: kind);

      final installedVersion = kind == 'art' ? remoteArtVersion : remoteVersion;
      final prefs = await SharedPreferences.getInstance();
      if (kind == 'art') {
        await prefs.setString('installed_art_version', installedVersion);
        currentArtVersion = installedVersion;
        remoteArtVersion = installedVersion;
        hasArtUpdate = false;
      } else {
        await prefs.setString('installed_version', installedVersion);
        currentVersion = installedVersion;
        remoteVersion = installedVersion;
        hasUpdate = false;
      }

      downloadProgress = 1;
      statusText = kind == 'art'
          ? 'Установка текстур завершена'
          : 'Установка завершена';
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 280));
      isDownloading = false;
      downloadingKind = null;
      downloadProgress = 0;
      addLog(
        kind == 'art'
            ? 'Установка графики и текстур завершена.'
            : 'Развёртывание файлов закончено.',
      );
      notifyListeners();
    } on TelegramAuthException catch (e) {
      _failInstall(e);
    } on FileSystemException catch (e) {
      _failInstall(e);
    } on PatchInstallException catch (e) {
      _failInstall(e);
    } catch (error) {
      _failInstall(error);
    }
  }

  Future<void> _downloadAndInstallReleaseAsset(
    Map<String, dynamic> asset, {
    required String kind,
  }) async {
    if (_usesAuthBackendForPremium) {
      await _downloadAndInstallViaBackend(kind: kind);
      return;
    }

    final zipUrl = _resolveAssetDownloadUrl(asset);
    if (zipUrl == null || zipUrl.isEmpty) {
      _failInstall(
        PatchInstallException('Не удалось найти zip-архив в GitHub Releases'),
      );
      return;
    }

    try {
      _resetInstallUiState();
      isDownloading = true;
      downloadingKind = kind;
      downloadProgress = 0;
      notifyListeners();

      Directory? extDir;
      try {
        extDir = await getExternalStorageDirectory();
      } on UnimplementedError {
        extDir = null;
      }
      final tempDir = extDir ?? await getTemporaryDirectory();
      final zipPath =
          '${tempDir.path}/reverse1999_${kind}_${DateTime.now().millisecondsSinceEpoch}.zip';
      final assetName = (asset['name'] ?? '').toString();
      addLog(
        'Загрузка ${assetName.isEmpty ? kind : assetName} '
        '(${isPremium ? "API asset URL" : "public URL"})...',
      );
      await _dio.download(
        zipUrl,
        zipPath,
        options: Options(
          headers: _assetDownloadHeaders(),
          receiveTimeout: const Duration(minutes: 10),
          followRedirects: true,
          maxRedirects: 5,
        ),
        onReceiveProgress: (received, total) {
          if (total <= 0) {
            return;
          }
          final progress = received / total;
          downloadProgress = progress;
          statusText = kind == 'art'
              ? 'Загрузка текстур: ${(progress * 100).toStringAsFixed(0)}%'
              : 'Загрузка: ${(progress * 100).toStringAsFixed(0)}%';
          notifyListeners();
        },
      );

      addLog('Архив загружен: $zipPath');
      await _extractArchive(zipPath, installPath, archiveKind: kind);

      final installedVersion = _versionFromAsset(asset, {
        'tag_name': kind == 'art' ? remoteArtVersion : remoteVersion,
        'name': kind == 'art' ? remoteArtVersion : remoteVersion,
      });
      final prefs = await SharedPreferences.getInstance();
      if (kind == 'art') {
        await prefs.setString('installed_art_version', installedVersion);
        currentArtVersion = installedVersion;
        remoteArtVersion = installedVersion;
        hasArtUpdate = false;
      } else {
        await prefs.setString('installed_version', installedVersion);
        currentVersion = installedVersion;
        remoteVersion = installedVersion;
        hasUpdate = false;
      }

      downloadProgress = 1;
      statusText = kind == 'art'
          ? 'Установка текстур завершена'
          : 'Установка завершена';
      _pausedDuringDownload = false;
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 280));
      isDownloading = false;
      downloadingKind = null;
      downloadProgress = 0;
      addLog(
        kind == 'art'
            ? 'Установка графики и текстур завершена.'
            : 'Установка текста завершена.',
      );
      notifyListeners();
    } on DioException catch (error) {
      final interrupted = _pausedDuringDownload;
      _pausedDuringDownload = false;
      isDownloading = false;
      downloadingKind = null;
      final facing = describeInstallErrorDetailed(
        error,
        interruptedByBackground: interrupted,
      );
      lastUserFacingError = facing;
      lastUserError = facing.flatMessage;
      statusText = facing.summary;
      addLog('${facing.title}: ${facing.summary}');
      notifyListeners();
    } on FileSystemException catch (e) {
      _failInstall(e);
    } on PatchInstallException catch (e) {
      _failInstall(e);
    } catch (error) {
      _failInstall(error);
    }
  }

  Future<Map<String, dynamic>> _getAssets() async {
    final data = await _fetchLatestRelease();
    final asset = _pickTextAsset(_releaseAssets(data));
    if (asset == null) {
      final suffix = isPremium ? '_full.zip' : '_free.zip';
      final names = _releaseAssets(data)
          .map((a) => (a['name'] ?? '').toString())
          .join(', ');
      throw Exception(
        'Архив текста (*$suffix) для вашей платформы не найден в $_activeReleaseRepoLabel. '
        'Файлы в релизе: ${names.isEmpty ? '(пусто)' : names}',
      );
    }
    return asset;
  }

  Future<Map<String, dynamic>> _getArtAsset() async {
    final data = await _fetchLatestRelease();
    final asset = _pickArtAsset(_releaseAssets(data));
    if (asset == null) {
      final names = _releaseAssets(data)
          .map((a) => (a['name'] ?? '').toString())
          .join(', ');
      throw Exception(
        'Архив текстур (*_art.zip) для вашей платформы не найден в $_activeReleaseRepoLabel. '
        'Файлы в релизе: ${names.isEmpty ? '(пусто)' : names}',
      );
    }
    return asset;
  }

  String? lastInstallSource;
  String? lastInstallTarget;
  int lastInstallFileCount = 0;
  List<String> lastBackupFiles = [];
  String? lastBackupKind;

  /// Последняя ошибка установки для AlertDialog (null = успеха/нет ошибки).
  String? lastUserError;

  /// Структурированная ошибка (заголовок + шаги) для красивого диалога.
  UserFacingError? lastUserFacingError;

  /// Пользователь свернул приложение во время скачивания/установки.
  bool _pausedDuringDownload = false;

  /// Вызывать из UI при сворачивании / паузе приложения.
  void onAppPaused() {
    if (isDownloading) {
      _pausedDuringDownload = true;
    }
  }

  /// Вызывать из UI при возврате в приложение.
  void onAppResumed() {
    // Флаг сбрасываем только после завершения операции в _failInstall / success.
  }

  void _resetInstallUiState() {
    lastInstallSource = null;
    lastInstallTarget = null;
    lastInstallFileCount = 0;
    lastUserError = null;
    lastUserFacingError = null;
  }

  void _failInstall(Object error, {String? pathHint}) {
    final interrupted = _pausedDuringDownload;
    _pausedDuringDownload = false;
    final facing = describeInstallErrorDetailed(
      error,
      pathHint: pathHint,
      interruptedByBackground: interrupted,
    );
    lastUserFacingError = facing;
    lastUserError = facing.flatMessage;
    statusText = facing.summary;
    // В лог — кратко, без стека.
    addLog('${facing.title}: ${facing.summary}');
    isDownloading = false;
    downloadingKind = null;
    notifyListeners();
  }

  Future<void> _extractArchive(
    String zipPath,
    String targetDir, {
    String archiveKind = 'text',
  }) async {
    if (Platform.isAndroid) {
      if (!isShizukuActive) {
        addLog('Shizuku не активен — установка на Android невозможна');
        throw PatchInstallException(
          'Shizuku не запущен. Откройте Shizuku, нажмите Start и повторите.',
        );
      }
      await _ensureShizukuPermission();
      if (!isShizukuActive) {
        throw PatchInstallException(
          'Нет разрешения Shizuku. Откройте Shizuku → разрешите доступ SolidLeaf.',
        );
      }
      await _resolveAndroidGameInstallPath();
      await _ensureFileService();

      final tempRoot = await getTemporaryDirectory();
      final workDir = Directory(
        path.join(
          tempRoot.path,
          'SolidLeaf_Temp',
          'install_${archiveKind}_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );

      try {
        if (await workDir.exists()) {
          await workDir.delete(recursive: true);
        }
        await workDir.create(recursive: true);

        final archiveFile = File(zipPath);
        final bytes = await archiveFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        for (final file in archive) {
          final outPath = path.join(workDir.path, file.name);
          if (file.isFile) {
            final data = file.content as List<int>;
            final outFile = File(outPath);
            await outFile.parent.create(recursive: true);
            await outFile.writeAsBytes(data);
          } else {
            await Directory(outPath).create(recursive: true);
          }
        }

        final normTarget = path.normalize(installPath.isNotEmpty ? installPath : targetDir);
        String sourceDir = workDir.path;
        String finalTarget = normTarget;

        Directory? luabytesDir;
        try {
          luabytesDir = Directory(sourceDir)
              .listSync(recursive: true)
              .whereType<Directory>()
              .firstWhere(
                (d) => path.basename(d.path).toLowerCase() == 'luabytes',
              );
        } catch (_) {
          luabytesDir = null;
        }

        if (luabytesDir != null) {
          sourceDir = path.normalize(luabytesDir.parent.path);
          finalTarget = path.join(normTarget, 'files', 'ResLib', 'Android');
        }

        sourceDir = path.normalize(sourceDir);
        finalTarget = path.normalize(finalTarget);

        final sourceDirectory = Directory(sourceDir);
        final allFiles = sourceDirectory.existsSync()
            ? sourceDirectory
                  .listSync(recursive: true)
                  .whereType<File>()
                  .toList()
            : <File>[];

        await _backupOnlyOverwrittenFiles(
          sourceDir,
          finalTarget,
          allFiles,
          kind: archiveKind,
        );
        final mkOk = await _fsMkdirs(finalTarget);
        if (!mkOk) {
          throw PatchInstallException(
            'Shizuku запущен, но нельзя создать папку в данных игры:\n'
            '$finalTarget\n'
            'На HyperOS / Honor отключите оптимизацию батареи для Shizuku '
            'и SolidLeaf, перезапустите Shizuku и повторите.',
          );
        }

        int copied = 0;
        String? firstError;
        for (final f in allFiles) {
          final rel = path.relative(f.path, from: sourceDir);
          final dst = path.join(finalTarget, rel);
          try {
            await _fsWriteLocalFile(f, dst);
            copied++;
          } catch (e) {
            firstError ??= e.toString();
            addLog('Не удалось скопировать ${f.path} -> $dst: ${e.toString()}');
          }
        }

        if (allFiles.isNotEmpty && copied < allFiles.length) {
          throw PatchInstallException(
            'Скопировано $copied из ${allFiles.length} файлов через Shizuku'
            '${firstError != null ? '.\nПричина: $firstError' : '.'}\n'
            'Оболочка (HyperOS / Honor / MIUI) часто режет запись в '
            'Android/data. Перезапустите Shizuku, отключите ограничение '
            'фона/батареи для Shizuku и SolidLeaf, закройте игру и повторите.',
          );
        }

        final validated = await _fsExists(finalTarget);
        if (!validated) {
          throw Exception(
            'После копирования целевая папка не найдена: $finalTarget',
          );
        }

        lastInstallSource = sourceDir;
        lastInstallTarget = finalTarget;
        lastInstallFileCount = copied;
      } catch (e) {
        addLog('Ошибка распаковки/копирования архива: ${e.toString()}');
        rethrow;
      } finally {
        try {
          if (await workDir.exists()) {
            await workDir.delete(recursive: true);
            addLog('Временная папка установки удалена: ${workDir.path}');
          }
        } catch (e) {
          addLog(
            'Не удалось удалить временную папку установки: ${e.toString()}',
          );
        }
      }

      return;
    }

    // --- Windows / desktop: распаковка в temp + копирование с бэкапом ---
    try {
      if (!GamePathFinder.isValidGamePath(targetDir)) {
        throw PatchInstallException(
          'Неверный путь к игре: нет папки ${GamePathFinder.dataFolderName}.\n'
          'Укажите корень установки Reverse: 1999.',
        );
      }

      final archiveFile = File(zipPath);
      final bytes = await archiveFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final dir = Directory(targetDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final extractedDir = Directory(
        '${dir.path}/.solidleaf_extract_${DateTime.now().millisecondsSinceEpoch}',
      );
      await extractedDir.create(recursive: true);

      try {
        for (final file in archive) {
          final outPath = path.join(extractedDir.path, file.name);
          try {
            if (file.isFile) {
              final data = file.content as List<int>;
              final outFile = File(outPath);
              await outFile.parent.create(recursive: true);
              await outFile.writeAsBytes(data);
            } else {
              await Directory(outPath).create(recursive: true);
            }
          } on FileSystemException catch (e) {
            throw PatchInstallException(
              describeInstallError(e, pathHint: outPath),
              needsAdmin: isAccessDeniedError(e),
            );
          }
        }

        final sourceDirectory = extractedDir;
        final allFiles = sourceDirectory.existsSync()
            ? sourceDirectory
                  .listSync(recursive: true)
                  .whereType<File>()
                  .toList()
            : <File>[];

        final backupDirPath = _backupFolderName();
        final backupDir = Directory(backupDirPath);
        if (await backupDir.exists()) {
          await backupDir.delete(recursive: true);
        }
        await backupDir.create(recursive: true);

        for (final f in allFiles) {
          final rel = path.relative(f.path, from: sourceDirectory.path);
          final targetPath = path.join(targetDir, rel);
          final targetFile = File(targetPath);
          if (!await targetFile.exists()) {
            continue;
          }
          try {
            final backupFile = File(path.join(backupDirPath, rel));
            await backupFile.parent.create(recursive: true);
            await targetFile.copy(backupFile.path);
          } on FileSystemException catch (e) {
            addLog('Бэкап пропущен ($rel): ${e.message}');
          }
        }

        Object? firstWriteError;
        var written = 0;
        for (final file in archive) {
          final targetPath = path.join(dir.path, file.name);
          try {
            if (file.isFile) {
              final data = file.content as List<int>;
              final targetFile = File(targetPath);
              await targetFile.parent.create(recursive: true);
              await targetFile.writeAsBytes(data);
              written++;
            } else {
              await Directory(targetPath).create(recursive: true);
            }
          } on FileSystemException catch (e) {
            firstWriteError ??= e;
            addLog(
              'Не удалось записать $targetPath: ${e.osError?.message ?? e.message}',
            );
          }
        }

        if (written == 0 && allFiles.isNotEmpty) {
          throw PatchInstallException(
            describeInstallError(
              firstWriteError ??
                  Exception('Не удалось записать файлы в папку игры'),
              pathHint: targetDir,
            ),
            needsAdmin:
                firstWriteError != null && isAccessDeniedError(firstWriteError),
          );
        }

        if (firstWriteError != null && isAccessDeniedError(firstWriteError)) {
          throw PatchInstallException(
            describeInstallError(firstWriteError, pathHint: targetDir),
            needsAdmin: true,
          );
        }

        lastInstallSource = sourceDirectory.path;
        lastInstallTarget = targetDir;
        lastInstallFileCount = written;
      } finally {
        try {
          if (await extractedDir.exists()) {
            await extractedDir.delete(recursive: true);
          }
        } catch (e) {
          addLog('Не удалось удалить временную папку: $e');
        }
      }
    } on PatchInstallException {
      rethrow;
    } on FileSystemException catch (e) {
      throw PatchInstallException(
        describeInstallError(e, pathHint: targetDir),
        needsAdmin: isAccessDeniedError(e),
      );
    } catch (e) {
      addLog('Ошибка распаковки/копирования архива: $e');
      throw PatchInstallException(describeInstallError(e, pathHint: targetDir));
    }
  }

  Future<bool> checkShizukuStatus() async {
    try {
      const methodChannel = MethodChannel(shizukuChannel);
      final state = await methodChannel.invokeMethod<dynamic>(
        'getShizukuState',
      );
      bool active;
      String status;
      if (state is Map) {
        active = (state['active'] as bool?) ?? false;
        status =
            state['status']?.toString() ??
            (active ? 'Shizuku активен' : 'Shizuku не активен');
      } else {
        active =
            await methodChannel.invokeMethod<bool>('checkShizukuStatus') ??
            false;
        status = active ? 'Shizuku активен' : 'Shizuku не активен';
      }

      isShizukuActive = active;
      // Статус Shizuku только в чипе UI — не затираем operational statusText.
      if (!_isShizukuStatusText(statusText) && !isDownloading) {
        // оставляем как есть
      } else if (_isShizukuStatusText(statusText) && !isDownloading) {
        statusText = 'Готово';
      }
      addLog(status);
      notifyListeners();
      return active;
    } on PlatformException catch (error) {
      isShizukuActive = false;
      if (_isShizukuStatusText(statusText)) {
        statusText = 'Готово';
      }
      addLog(
        'Проверка Shizuku: ${error.message ?? 'не удалось проверить'}',
      );
      notifyListeners();
      return false;
    }
  }

  bool _isShizukuStatusText(String text) {
    final t = text.trim().toLowerCase();
    return t.startsWith('shizuku');
  }

  bool _isVersionNewer(String remote, String local) {
    final remoteParts = _parseVersion(remote);
    final localParts = _parseVersion(local);
    for (
      var i = 0;
      i <
          [
            remoteParts.length,
            localParts.length,
          ].reduce((a, b) => a > b ? a : b);
      i++
    ) {
      final remoteValue = i < remoteParts.length ? remoteParts[i] : 0;
      final localValue = i < localParts.length ? localParts[i] : 0;
      if (remoteValue > localValue) return true;
      if (remoteValue < localValue) return false;
    }
    return false;
  }

  List<int> _parseVersion(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty || cleaned == '.') {
      return [0];
    }
    return cleaned
        .split('.')
        .where((part) => part.isNotEmpty)
        .map(int.parse)
        .toList();
  }

  void _handleDioError(DioException exception) {
    final facing = describeInstallErrorDetailed(exception);
    statusText = facing.summary;
    addLog('${facing.title}: ${facing.summary}');
    notifyListeners();
  }
}

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
import '../telegram_auth_service.dart';

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
  bool isDownloading = false;
  bool hasUpdate = false;
  bool hasArtUpdate = false;
  bool isShizukuActive = false;
  double downloadProgress = 0;
  String installPath = '';
  String currentVersion = 'v0.0.0';
  String currentArtVersion = 'v0.0.0';
  String remoteVersion = 'вЂ”';
  String remoteArtVersion = 'вЂ”';
  String changelog = 'РџСЂРѕРІРµСЂРєР° РѕР±РЅРѕРІР»РµРЅРёР№ РЅРµ Р·Р°РїСѓСЃРєР°Р»Р°СЃСЊ';
  String statusText = 'Р“РѕС‚РѕРІРѕ';
  List<String> logs = [];

  Map<String, dynamic>? _cachedRelease;
  DateTime? _cachedReleaseAt;
  bool? _cachedReleaseIsPremium;
  static const _releaseCacheTtl = Duration(seconds: 45);

  // --- Telegram account tiers (login-gated launcher access) ----------------
  // The auth backend now issues a JWT to ANY member of the public community
  // group (t.me/reverse1999_solidleaf) вЂ” that's enough to use the launcher
  // and its text localization. Only members of the private premium channel
  // get access_level == "premium", which unlocks the "Р“СЂР°С„РёРєР° Рё С‚РµРєСЃС‚СѓСЂС‹"
  // card. [isPremium] reflects that server-decided tier, not merely "has a
  // token" (see TelegramAuthService.hasPremiumAccess).
  final TelegramAuthService telegramAuth = TelegramAuthService();
  bool isPremium = false;

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
  }

  void _invalidateReleaseCache() {
    _cachedRelease = null;
    _cachedReleaseAt = null;
    _cachedReleaseIsPremium = null;
  }

  String get _activeReleaseApiUrl =>
      isPremium ? githubPremiumLatestReleaseUrl : githubFreeLatestReleaseUrl;

  String get _activeReleaseRepoLabel =>
      isPremium ? 'FrauxHD/PREMIUM' : 'strixcyron/SOLIDLEAF-TEAM';

  Map<String, String> _releaseRequestHeaders() {
    final headers = <String, String>{
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'solidleaf-launcher-app',
    };

    if (isPremium) {
      final token = GitHubConfig.premiumToken;
      if (token.isEmpty) {
        throw Exception(
          'GITHUB_TOKEN не настроен. Соберите приложение с '
          '--dart-define=GITHUB_TOKEN=<ваш_токен> для доступа к премиум-релизам.',
        );
      }
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  @override
  void dispose() {
    telegramAuth.dispose();
    super.dispose();
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    isDarkMode = prefs.getBool('is_dark_mode') ?? true;
    currentVersion = prefs.getString('installed_version') ?? 'v0.0.0';
    currentArtVersion = prefs.getString('installed_art_version') ?? 'v0.0.0';
    installPath = _defaultInstallPath();
    await refreshPremiumStatus();
    if (Platform.isAndroid) {
      await checkShizukuStatus();
    }
    await checkForUpdates();
    if (isPremium) {
      await checkForArtUpdates();
    } else {
      hasArtUpdate = false;
    }
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    isDarkMode = !isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDarkMode);
    notifyListeners();
  }

  String _defaultInstallPath() {
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Android/data/com.bluepoch.m.en.reverse1999/';
    }
    if (Platform.isWindows) {
      return r'РЈРєР°Р¶РёС‚Рµ РїСѓС‚СЊ Рє РёРіСЂРµ, РЅР°РїСЂРёРјРµСЂ: C:\Games\Reverse1999\Reverse1999_EN';
    }
    return '/tmp/reverse1999_localization';
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

  String _backupFolderName() {
    return path.join(installPath, 'backup_solidleaf');
  }

  String _joinPath(String base, String relative) {
    return path.join(base, relative);
  }

  static const int _fsChunkSize = 512 * 1024;

  Future<void> _ensureFileService({int attempts = 4}) async {
    const methodChannel = MethodChannel(shizukuChannel);
    Object? lastError;

    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        final ok =
            await methodChannel.invokeMethod<bool>('ensureFileService') ??
            false;
        if (ok) {
          if (statusText.startsWith('Shizuku РЅРµ РїРѕРґРєР»СЋС‡С‘РЅ') ||
              statusText.startsWith('РџРѕРґРєР»СЋС‡РµРЅРёРµ Рє Shizuku')) {
            statusText = 'Shizuku: СЃРµСЂРІРёСЃ РґРѕСЃС‚СѓРїРµРЅ';
            notifyListeners();
          }
          return;
        }
        lastError = Exception('РќРµ СѓРґР°Р»РѕСЃСЊ РїРѕРґРєР»СЋС‡РёС‚СЊ Shizuku file service');
      } on PlatformException catch (e) {
        final message =
            'Shizuku file service РЅРµРґРѕСЃС‚СѓРїРµРЅ: ${e.message ?? e.code}';
        lastError = Exception(message);
      } catch (e) {
        lastError = e;
      }

      if (attempt < attempts) {
        statusText = 'РџРѕРґРєР»СЋС‡РµРЅРёРµ Рє Shizuku... РїРѕРїС‹С‚РєР° $attempt/$attempts';
        notifyListeners();
        await Future.delayed(Duration(milliseconds: 700 * attempt));
      }
    }

    const message =
        'Shizuku РЅРµ РїРѕРґРєР»СЋС‡С‘РЅ. РћС‚РєСЂРѕР№С‚Рµ Shizuku, РЅР°Р¶РјРёС‚Рµ Start, СЂР°Р·СЂРµС€РёС‚Рµ РґРѕСЃС‚СѓРї РїСЂРёР»РѕР¶РµРЅРёСЋ Рё РїРѕРІС‚РѕСЂРёС‚Рµ РїРѕРїС‹С‚РєСѓ.';
    statusText = message;
    addLog(message);
    notifyListeners();
    throw Exception(lastError?.toString() ?? message);
  }

  Future<bool> _fsMkdirs(String targetPath) async {
    const methodChannel = MethodChannel(shizukuChannel);
    return await methodChannel.invokeMethod<bool>('fsMkdirs', targetPath) ??
        false;
  }

  Future<bool> _fsWriteChunk(
    String targetPath,
    Uint8List data,
    bool append,
  ) async {
    const methodChannel = MethodChannel(shizukuChannel);
    return await methodChannel.invokeMethod<bool>('fsWriteChunk', {
          'path': targetPath,
          'data': data,
          'append': append,
        }) ??
        false;
  }

  Future<Uint8List?> _fsReadChunk(
    String targetPath,
    int offset,
    int length,
  ) async {
    const methodChannel = MethodChannel(shizukuChannel);
    final result = await methodChannel.invokeMethod('fsReadChunk', {
      'path': targetPath,
      'offset': offset,
      'length': length,
    });
    if (result == null) return null;
    return Uint8List.fromList(List<int>.from(result as List));
  }

  Future<int> _fsFileSize(String targetPath) async {
    const methodChannel = MethodChannel(shizukuChannel);
    final result = await methodChannel.invokeMethod<int>(
      'fsFileSize',
      targetPath,
    );
    return result ?? -1;
  }

  Future<bool> _fsDeleteRecursive(String targetPath) async {
    const methodChannel = MethodChannel(shizukuChannel);
    return await methodChannel.invokeMethod<bool>(
          'fsDeleteRecursive',
          targetPath,
        ) ??
        false;
  }

  Future<bool> _fsExists(String targetPath) async {
    const methodChannel = MethodChannel(shizukuChannel);
    return await methodChannel.invokeMethod<bool>('fsExists', targetPath) ??
        false;
  }

  Future<void> _fsCopyFile(String src, String dst) async {
    await _fsMkdirs(path.dirname(dst));
    final size = await _fsFileSize(src);
    if (size < 0) {
      throw Exception('РСЃС‚РѕС‡РЅРёРє РЅРµ РЅР°Р№РґРµРЅ РёР»Рё РЅРµРґРѕСЃС‚СѓРїРµРЅ: $src');
    }
    if (size == 0) {
      final ok = await _fsWriteChunk(dst, Uint8List(0), false);
      if (!ok) throw Exception('РќРµ СѓРґР°Р»РѕСЃСЊ СЃРѕР·РґР°С‚СЊ РїСѓСЃС‚РѕР№ С„Р°Р№Р»: $dst');
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
        throw Exception('РќРµ СѓРґР°Р»РѕСЃСЊ РїСЂРѕС‡РёС‚Р°С‚СЊ $src РЅР° СЃРјРµС‰РµРЅРёРё $offset');
      }
      final ok = await _fsWriteChunk(dst, chunk, !first);
      if (!ok) {
        throw Exception('РќРµ СѓРґР°Р»РѕСЃСЊ Р·Р°РїРёСЃР°С‚СЊ РІ $dst');
      }
      first = false;
      offset += len;
    }
  }

  Future<void> _fsWriteLocalFile(File localFile, String dstPath) async {
    await _fsMkdirs(path.dirname(dstPath));
    final data = await localFile.readAsBytes();
    if (data.isEmpty) {
      final ok = await _fsWriteChunk(dstPath, Uint8List(0), false);
      if (!ok) throw Exception('РќРµ СѓРґР°Р»РѕСЃСЊ СЃРѕР·РґР°С‚СЊ РїСѓСЃС‚РѕР№ С„Р°Р№Р»: $dstPath');
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
        throw Exception('РќРµ СѓРґР°Р»РѕСЃСЊ Р·Р°РїРёСЃР°С‚СЊ С‡Р°РЅРє РІ $dstPath (offset=$offset)');
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
    addLog('РЎРѕР·РґР°РЅРёРµ СЂРµР·РµСЂРІРЅРѕР№ РєРѕРїРёРё С„Р°Р№Р»РѕРІ...');

    lastBackupFiles = [];
    lastBackupKind = kind;

    try {
      if (Platform.isAndroid) {
        if (!isShizukuActive) {
          addLog('Shizuku РЅРµ Р°РєС‚РёРІРµРЅ вЂ” СЃРѕР·РґР°РЅРёРµ Р±СЌРєР°РїР° РЅР° Android РЅРµРІРѕР·РјРѕР¶РЅРѕ');
          throw Exception('Shizuku required for Android backup');
        }
        await _ensureFileService();
        final exists = await _fsExists(backupDirPath);
        if (exists) {
          final ok = await _fsDeleteRecursive(backupDirPath);
          if (!ok) {
            addLog('РќРµ СѓРґР°Р»РѕСЃСЊ РѕС‡РёСЃС‚РёС‚СЊ РїСЂРµРґС‹РґСѓС‰РёР№ Р±СЌРєР°Рї С‡РµСЂРµР· Shizuku');
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
          addLog('Р‘СЌРєР°Рї (Shizuku): $rel');
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
          addLog('Р‘СЌРєР°Рї: $rel');
        }
      }

      addLog(
        copied == 0
            ? 'РќРµС‡РµРіРѕ РєРѕРїРёСЂРѕРІР°С‚СЊ РІ Р±СЌРєР°Рї вЂ” С†РµР»РµРІС‹Рµ С„Р°Р№Р»С‹ РЅРµ РЅР°Р№РґРµРЅС‹.'
            : 'РЎРѕР·РґР°РЅРёРµ СЂРµР·РµСЂРІРЅРѕР№ РєРѕРїРёРё Р·Р°РІРµСЂС€РµРЅРѕ',
      );
    } catch (e) {
      addLog('РћС€РёР±РєР° СЃРѕР·РґР°РЅРёСЏ Р±СЌРєР°РїР°: $e');
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
        addLog('Shizuku РЅРµ Р°РєС‚РёРІРµРЅ вЂ” СЃРѕР·РґР°РЅРёРµ Р±СЌРєР°РїР° РЅР° Android РЅРµРІРѕР·РјРѕР¶РЅРѕ');
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
          addLog('РСЃС…РѕРґРЅС‹Р№ С„Р°Р№Р» РЅРµ РЅР°Р№РґРµРЅ, РїСЂРѕРїСѓСЃРє: $src');
          continue;
        }
        final dstFile = File(dst);
        await dstFile.parent.create(recursive: true);
        await srcFile.copy(dst);
        addLog('РЎРєРѕРїРёСЂРѕРІР°РЅРѕ РІ Р±СЌРєР°Рї: $rel');
      } else if (Platform.isAndroid) {
        final srcExists = await _fsExists(src);
        if (!srcExists) {
          addLog('РСЃС…РѕРґРЅС‹Р№ С„Р°Р№Р» РЅРµ РЅР°Р№РґРµРЅ, РїСЂРѕРїСѓСЃРє (Android): $src');
          continue;
        }
        await _fsCopyFile(src, dst);
        addLog('Shizuku: СЃРєРѕРїРёСЂРѕРІР°РЅ РІ Р±СЌРєР°РїРµ: $rel');
      }
    }

    addLog('РЎРѕР·РґР°РЅРёРµ СЂРµР·РµСЂРІРЅРѕР№ РєРѕРїРёРё Р·Р°РІРµСЂС€РµРЅРѕ');
  }

  Future<void> restoreBackup() async {
    addLog('Р’РѕСЃСЃС‚Р°РЅРѕРІР»РµРЅРёРµ РёР· Р±СЌРєР°РїР°...');
    final backupDirPath = _backupFolderName();
    try {
      if (Platform.isAndroid) {
        if (!isShizukuActive) {
          addLog('Shizuku РЅРµ Р°РєС‚РёРІРµРЅ вЂ” РІРѕСЃСЃС‚Р°РЅРѕРІР»РµРЅРёРµ РЅР° Android РЅРµРІРѕР·РјРѕР¶РЅРѕ');
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
            addLog('Р’ Р±СЌРєР°РїРµ РЅРµ РЅР°Р№РґРµРЅ С„Р°Р№Р», РїСЂРѕРїСѓСЃРє: $src');
            continue;
          }
          await File(dst).parent.create(recursive: true);
          await srcFile.copy(dst);
          addLog('Р’РѕСЃСЃС‚Р°РЅРѕРІР»РµРЅ С„Р°Р№Р»: $rel');
        } else if (Platform.isAndroid) {
          final srcExists = await _fsExists(src);
          if (!srcExists) {
            addLog('Р’ Р±СЌРєР°РїРµ РЅРµ РЅР°Р№РґРµРЅ С„Р°Р№Р», РїСЂРѕРїСѓСЃРє (Android): $src');
            continue;
          }

          await _fsCopyFile(src, dst);
          addLog('Shizuku: РІРѕСЃСЃС‚Р°РЅРѕРІР»РµРЅ С„Р°Р№Р»: $rel');
        }
      }

      if (Platform.isAndroid) {
        try {
          final exists = await _fsExists(backupDirPath);
          if (exists) {
            final ok = await _fsDeleteRecursive(backupDirPath);
            if (ok) {
              addLog('РџР°РїРєР° Р±СЌРєР°РїР° СѓРґР°Р»РµРЅР° (Shizuku)');
            } else {
              addLog('РќРµ СѓРґР°Р»РѕСЃСЊ СѓРґР°Р»РёС‚СЊ РїР°РїРєСѓ Р±СЌРєР°РїР° С‡РµСЂРµР· Shizuku');
            }
          }
        } catch (e) {
          addLog(
            'РќРµ СѓРґР°Р»РѕСЃСЊ СѓРґР°Р»РёС‚СЊ РїР°РїРєСѓ Р±СЌРєР°РїР° С‡РµСЂРµР· Shizuku: ${e.toString()}',
          );
        }
      } else {
        final backupDir = Directory(backupDirPath);
        if (await backupDir.exists()) {
          await backupDir.delete(recursive: true);
          addLog('РџР°РїРєР° Р±СЌРєР°РїР° СѓРґР°Р»РµРЅР°');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('installed_version', 'v0.0.0');
      currentVersion = 'v0.0.0';
      hasUpdate = false;
      statusText = 'Р СѓСЃРёС„РёРєР°С‚РѕСЂ СѓРґР°Р»С‘РЅ. РЎРѕСЃС‚РѕСЏРЅРёРµ: РќРµ СѓСЃС‚Р°РЅРѕРІР»РµРЅРѕ.';
      addLog('Р’РѕСЃСЃС‚Р°РЅРѕРІР»РµРЅРёРµ Р·Р°РІРµСЂС€РµРЅРѕ. Р’РµСЂСЃРёСЏ СЃР±СЂРѕС€РµРЅР°.');
      notifyListeners();
    } catch (e) {
      addLog('РћС€РёР±РєР° РІРѕСЃСЃС‚Р°РЅРѕРІР»РµРЅРёСЏ: $e');
      rethrow;
    }
  }

  Future<void> restoreBackupKind(String kind) async {
    addLog('Р’РѕСЃСЃС‚Р°РЅРѕРІР»РµРЅРёРµ РёР· Р±СЌРєР°РїР° (РїРѕРґРІРёРґ: $kind)...');
    final backupDirPath = _backupFolderName();
    try {
      if (Platform.isAndroid) {
        if (!isShizukuActive) {
          addLog('Shizuku РЅРµ Р°РєС‚РёРІРµРЅ вЂ” РІРѕСЃСЃС‚Р°РЅРѕРІР»РµРЅРёРµ РЅР° Android РЅРµРІРѕР·РјРѕР¶РЅРѕ');
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
        addLog('Р’ Р±СЌРєР°РїРµ РЅРµ РЅР°Р№РґРµРЅС‹ С„Р°Р№Р»С‹ РґР»СЏ РІРѕСЃСЃС‚Р°РЅРѕРІР»РµРЅРёСЏ (kind=$kind).');
        throw Exception('No backup files found for restore');
      }

      for (final rel in toRestore) {
        final src = _joinPath(backupDirPath, rel);
        final dst = _joinPath(installPath, rel);

        if (Platform.isWindows) {
          final srcFile = File(src);
          if (!await srcFile.exists()) {
            addLog('Р’ Р±СЌРєР°РїРµ РЅРµ РЅР°Р№РґРµРЅ С„Р°Р№Р», РїСЂРѕРїСѓСЃРє: $src');
            continue;
          }
          await File(dst).parent.create(recursive: true);
          await srcFile.copy(dst);
          addLog('Р’РѕСЃСЃС‚Р°РЅРѕРІР»РµРЅ С„Р°Р№Р»: $rel');
        } else if (Platform.isAndroid) {
          final srcExists = await _fsExists(src);
          if (!srcExists) {
            addLog('Р’ Р±СЌРєР°РїРµ РЅРµ РЅР°Р№РґРµРЅ С„Р°Р№Р», РїСЂРѕРїСѓСЃРє (Android): $src');
            continue;
          }
          await _fsCopyFile(src, dst);
          addLog('Shizuku: РІРѕСЃСЃС‚Р°РЅРѕРІР»РµРЅ С„Р°Р№Р»: $rel');
        }
      }

      if (Platform.isAndroid) {
        try {
          final exists = await _fsExists(backupDirPath);
          if (exists) {
            final ok = await _fsDeleteRecursive(backupDirPath);
            if (ok) {
              addLog('РџР°РїРєР° Р±СЌРєР°РїР° СѓРґР°Р»РµРЅР° (Shizuku)');
            } else {
              addLog('РќРµ СѓРґР°Р»РѕСЃСЊ СѓРґР°Р»РёС‚СЊ РїР°РїРєСѓ Р±СЌРєР°РїР° С‡РµСЂРµР· Shizuku');
            }
          }
        } catch (e) {
          addLog(
            'РќРµ СѓРґР°Р»РѕСЃСЊ СѓРґР°Р»РёС‚СЊ РїР°РїРєСѓ Р±СЌРєР°РїР° С‡РµСЂРµР· Shizuku: ${e.toString()}',
          );
        }
      } else {
        final backupDirLocal = Directory(backupDirPath);
        if (await backupDirLocal.exists()) {
          await backupDirLocal.delete(recursive: true);
          addLog('РџР°РїРєР° Р±СЌРєР°РїР° СѓРґР°Р»РµРЅР°');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      if (kind == 'art') {
        await prefs.setString('installed_art_version', 'v0.0.0');
        currentArtVersion = 'v0.0.0';
        hasArtUpdate = false;
        statusText = 'Р СѓСЃРёС„РёРєР°С‚РѕСЂ РіСЂР°С„РёРєРё СѓРґР°Р»С‘РЅ. РЎРѕСЃС‚РѕСЏРЅРёРµ: РќРµ СѓСЃС‚Р°РЅРѕРІР»РµРЅРѕ.';
      } else if (kind == 'text') {
        await prefs.setString('installed_version', 'v0.0.0');
        currentVersion = 'v0.0.0';
        hasUpdate = false;
        statusText = 'Р СѓСЃРёС„РёРєР°С‚РѕСЂ С‚РµРєСЃС‚Р° СѓРґР°Р»С‘РЅ. РЎРѕСЃС‚РѕСЏРЅРёРµ: РќРµ СѓСЃС‚Р°РЅРѕРІР»РµРЅРѕ.';
      } else {
        await prefs.setString('installed_version', 'v0.0.0');
        await prefs.setString('installed_art_version', 'v0.0.0');
        currentVersion = 'v0.0.0';
        currentArtVersion = 'v0.0.0';
        hasUpdate = false;
        hasArtUpdate = false;
        statusText = 'Р СѓСЃРёС„РёРєР°С‚РѕСЂ СѓРґР°Р»С‘РЅ РїРѕР»РЅРѕСЃС‚СЊСЋ. РЎРѕСЃС‚РѕСЏРЅРёРµ: РќРµ СѓСЃС‚Р°РЅРѕРІР»РµРЅРѕ.';
      }

      addLog('Р’РѕСЃСЃС‚Р°РЅРѕРІР»РµРЅРёРµ Р·Р°РІРµСЂС€РµРЅРѕ. Р’РµСЂСЃРёРё СЃР±СЂРѕС€РµРЅС‹.');
      notifyListeners();
    } catch (e) {
      addLog('РћС€РёР±РєР° РІРѕСЃСЃС‚Р°РЅРѕРІР»РµРЅРёСЏ: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _fetchLatestRelease({bool force = false}) async {
    if (!force &&
        _cachedRelease != null &&
        _cachedReleaseAt != null &&
        _cachedReleaseIsPremium == isPremium &&
        DateTime.now().difference(_cachedReleaseAt!) < _releaseCacheTtl) {
      return _cachedRelease!;
    }

    // Free repo is public — no Authorization header.
    // Premium repo is private — requires GITHUB_TOKEN (see GitHubConfig).
    final response = await _dio
        .get(
          _activeReleaseApiUrl,
          options: Options(headers: _releaseRequestHeaders()),
        )
        .timeout(const Duration(seconds: 15));

    final status = response.statusCode ?? 0;
    if (status == 401) {
      throw Exception(
        'GitHub отклонил авторизацию (401). Проверьте GITHUB_TOKEN для $_activeReleaseRepoLabel.',
      );
    }
    if (status == 403 || status == 429) {
      throw Exception('Превышен лимит запросов к GitHub. Попробуйте позже.');
    }
    if (status == 404) {
      throw Exception(
        'Релиз не найден в репозитории $_activeReleaseRepoLabel.',
      );
    }
    if (status != 200 || response.data == null) {
      throw Exception('Ошибка сервера GitHub: $status');
    }

    final data = Map<String, dynamic>.from(response.data as Map);
    _cachedRelease = data;
    _cachedReleaseAt = DateTime.now();
    _cachedReleaseIsPremium = isPremium;
    return data;
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
      final url = (asset['browser_download_url'] ?? '').toString().toLowerCase();
      if (test(name, url)) return asset;
    }
    return null;
  }

  /// Free tier: `*_pc_free.zip` / `*_android_free.zip` from SOLIDLEAF-TEAM.
  /// Premium tier: `*_pc_full.zip` / `*_android_full.zip` from FrauxHD/PREMIUM.
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

  String _artVersionFromAsset(
    Map<String, dynamic> asset,
    Map<String, dynamic> release,
  ) {
    final name = (asset['name'] ?? '').toString();
    final verMatch = RegExp(r'(\d+(?:\.\d+)*)').firstMatch(name);
    if (verMatch != null) return 'v${verMatch.group(1)}';
    return (release['tag_name'] ?? release['name'] ?? remoteArtVersion)
        .toString();
  }

  Future<void> checkForUpdates() async {
    try {
      statusText = 'РџСЂРѕРІРµСЂРєР° РѕР±РЅРѕРІР»РµРЅРёР№...';
      addLog('Запрос GitHub Releases ($_activeReleaseRepoLabel)...');
      final data = await _fetchLatestRelease(force: true);
      final version = (data['tag_name'] ?? data['name'] ?? 'v0.0.0').toString();
      final body = (data['body'] ?? 'Р‘РµР· СЃРїРёСЃРєР° РёР·РјРµРЅРµРЅРёР№').toString();
      final assets = _releaseAssets(data);
      final zipAsset = _pickTextAsset(assets);

      remoteVersion = version;
      changelog = body;

      if (zipAsset == null) {
        hasUpdate = false;
        final names = assets.map((a) => (a['name'] ?? '').toString()).join(', ');
        statusText = 'РђСЂС…РёРІ С‚РµРєСЃС‚Р° РґР»СЏ РІР°С€РµР№ РїР»Р°С‚С„РѕСЂРјС‹ РЅРµ РЅР°Р№РґРµРЅ РІ СЂРµР»РёР·Рµ';
        addLog(statusText);
        addLog('Р¤Р°Р№Р»С‹ РІ СЂРµР»РёР·Рµ: ${names.isEmpty ? '(РїСѓСЃС‚Рѕ)' : names}');
        notifyListeners();
        return;
      }

      final zipUrl = (zipAsset['browser_download_url'] ?? '').toString();
      final zipName = (zipAsset['name'] ?? '').toString();
      final isNewer = _isVersionNewer(remoteVersion, currentVersion);
      hasUpdate = isNewer;
      statusText = isNewer
          ? 'Р”РѕСЃС‚СѓРїРЅРѕ РѕР±РЅРѕРІР»РµРЅРёРµ'
          : 'РЈСЃС‚Р°РЅРѕРІР»РµРЅР° Р°РєС‚СѓР°Р»СЊРЅР°СЏ РІРµСЂСЃРёСЏ';
      addLog('Р’РµСЂСЃРёСЏ РЅР° СЃРµСЂРІРµСЂРµ: $remoteVersion');
      addLog('Р›РѕРєР°Р»СЊРЅР°СЏ РІРµСЂСЃРёСЏ: $currentVersion');
      addLog('РђСЂС…РёРІ С‚РµРєСЃС‚Р°: $zipName');
      addLog('РЎСЃС‹Р»РєР° РЅР° Р°СЂС…РёРІ: $zipUrl');
      notifyListeners();
    } on TimeoutException catch (_) {
      statusText = 'РџСЂРµРІС‹С€РµРЅРѕ РІСЂРµРјСЏ РѕР¶РёРґР°РЅРёСЏ СЃРµСЂРІРµСЂР°';
      addLog(statusText);
      notifyListeners();
    } on SocketException catch (_) {
      statusText = 'РќРµС‚ РїРѕРґРєР»СЋС‡РµРЅРёСЏ Рє РёРЅС‚РµСЂРЅРµС‚Сѓ';
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
        remoteArtVersion = _artVersionFromAsset(artAsset, data);
      } else {
        remoteArtVersion =
            (data['tag_name'] ?? data['name'] ?? remoteVersion).toString();
        addLog(
          'Art-архив не найден в релизе, версия взята из тега: $remoteArtVersion',
        );
      }

      hasArtUpdate = _isVersionNewer(remoteArtVersion, currentArtVersion);
      addLog(
        'Р’РµСЂСЃРёСЏ С‚РµРєСЃС‚СѓСЂ РЅР° СЃРµСЂРІРµСЂРµ: $remoteArtVersion, Р»РѕРєР°Р»СЊРЅРѕ: $currentArtVersion',
      );
      notifyListeners();
    } catch (e) {
      addLog('РќРµ СѓРґР°Р»РѕСЃСЊ РїСЂРѕРІРµСЂРёС‚СЊ РІРµСЂСЃРёСЋ С‚РµРєСЃС‚СѓСЂ: $e');
    }
  }

  Future<void> selectInstallPath() async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Р’С‹Р±РµСЂРёС‚Рµ РїР°РїРєСѓ СѓСЃС‚Р°РЅРѕРІРєРё',
    );
    if (selected != null && selected.isNotEmpty) {
      installPath = selected;
      addLog('Р’С‹Р±СЂР°РЅР° РїР°РїРєР°: $installPath');
      notifyListeners();
    }
  }

  Future<void> installOrUpdate() async {
    if (remoteVersion == 'вЂ”') {
      await checkForUpdates();
    }

    if (!hasUpdate && currentVersion != 'v0.0.0') {
      addLog('РћР±РЅРѕРІР»РµРЅРёР№ РЅРµ С‚СЂРµР±СѓРµС‚СЃСЏ. РЈСЃС‚Р°РЅРѕРІРєР° СѓР¶Рµ Р°РєС‚СѓР°Р»СЊРЅР°.');
      statusText = 'РЈСЃС‚Р°РЅРѕРІР»РµРЅР° Р°РєС‚СѓР°Р»СЊРЅР°СЏ РІРµСЂСЃРёСЏ';
      notifyListeners();
      return;
    }

    final asset = await _getAssets();
    await _downloadAndInstallReleaseAsset(asset, kind: 'text');
  }

  Future<void> installArtPack() async {
    if (!isPremium) {
      statusText = 'Текстуры доступны только с платной подпиской.';
      addLog(statusText);
      notifyListeners();
      return;
    }

    final asset = await _getArtAsset();
    await _downloadAndInstallReleaseAsset(asset, kind: 'art');
  }

  Future<void> _downloadAndInstallReleaseAsset(
    Map<String, dynamic> asset, {
    required String kind,
  }) async {
    final zipUrl = asset['browser_download_url'] as String?;
    if (zipUrl == null || zipUrl.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: _activeReleaseApiUrl),
        error: 'Не удалось найти zip-архив в GitHub Releases',
      );
    }

    try {
      isDownloading = true;
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
      await _dio.download(
        zipUrl,
        zipPath,
        options: Options(
          headers: {
            'Accept': '*/*',
            'User-Agent': 'solidleaf-launcher-app',
            if (isPremium) ..._releaseRequestHeaders(),
          },
          receiveTimeout: const Duration(minutes: 10),
        ),
        onReceiveProgress: (received, total) {
          if (total <= 0) {
            return;
          }
          final progress = received / total;
          downloadProgress = progress;
          statusText = kind == 'art'
              ? 'Р—Р°РіСЂСѓР·РєР° С‚РµРєСЃС‚СѓСЂ: ${(progress * 100).toStringAsFixed(0)}%'
              : 'Р—Р°РіСЂСѓР·РєР°: ${(progress * 100).toStringAsFixed(0)}%';
          notifyListeners();
        },
      );

      addLog('РђСЂС…РёРІ Р·Р°РіСЂСѓР¶РµРЅ: $zipPath');
      await _extractArchive(zipPath, installPath, archiveKind: kind);

      final prefs = await SharedPreferences.getInstance();
      if (kind == 'art') {
        await prefs.setString('installed_art_version', remoteArtVersion);
        currentArtVersion = remoteArtVersion;
        hasArtUpdate = false;
      } else {
        await prefs.setString('installed_version', remoteVersion);
        currentVersion = remoteVersion;
        hasUpdate = false;
      }

      isDownloading = false;
      downloadProgress = 1;
      statusText = kind == 'art'
          ? 'РЈСЃС‚Р°РЅРѕРІРєР° С‚РµРєСЃС‚СѓСЂ Р·Р°РІРµСЂС€РµРЅР°'
          : 'РЈСЃС‚Р°РЅРѕРІРєР° Р·Р°РІРµСЂС€РµРЅР°';
      addLog(
        kind == 'art'
            ? 'РЈСЃС‚Р°РЅРѕРІРєР° РіСЂР°С„РёРєРё Рё С‚РµРєСЃС‚СѓСЂ Р·Р°РІРµСЂС€РµРЅР°.'
            : 'Р Р°Р·РІС‘СЂС‚С‹РІР°РЅРёРµ С„Р°Р№Р»РѕРІ Р·Р°РєРѕРЅС‡РµРЅРѕ.',
      );
      notifyListeners();
    } on DioException catch (error) {
      isDownloading = false;
      _handleDioError(error);
    } catch (error) {
      isDownloading = false;
      final message = 'РћС€РёР±РєР° СѓСЃС‚Р°РЅРѕРІРєРё: ${error.toString()}';
      statusText = message;
      addLog(message);
      notifyListeners();
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

  Future<void> _extractArchive(
    String zipPath,
    String targetDir, {
    String archiveKind = 'text',
  }) async {
    if (Platform.isAndroid) {
      if (!isShizukuActive) {
        addLog('Shizuku РЅРµ Р°РєС‚РёРІРµРЅ вЂ” СѓСЃС‚Р°РЅРѕРІРєР° РЅР° Android РЅРµРІРѕР·РјРѕР¶РЅР°');
        throw Exception('Shizuku required for Android install');
      }
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

        final normTarget = path.normalize(targetDir);
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
        await _fsMkdirs(finalTarget);

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
            addLog('РќРµ СѓРґР°Р»РѕСЃСЊ СЃРєРѕРїРёСЂРѕРІР°С‚СЊ ${f.path} -> $dst: ${e.toString()}');
          }
        }

        if (copied == 0 && allFiles.isNotEmpty) {
          throw Exception(
            'РќРµ СѓРґР°Р»РѕСЃСЊ СЃРєРѕРїРёСЂРѕРІР°С‚СЊ РЅРё РѕРґРЅРѕРіРѕ С„Р°Р№Р»Р° С‡РµСЂРµР· Shizuku${firstError != null ? ': $firstError' : ''}',
          );
        }

        final validated = await _fsExists(finalTarget);
        if (!validated) {
          throw Exception(
            'РџРѕСЃР»Рµ РєРѕРїРёСЂРѕРІР°РЅРёСЏ С†РµР»РµРІР°СЏ РїР°РїРєР° РЅРµ РЅР°Р№РґРµРЅР°: $finalTarget',
          );
        }

        lastInstallSource = sourceDir;
        lastInstallTarget = finalTarget;
        lastInstallFileCount = copied;
      } catch (e) {
        addLog('РћС€РёР±РєР° СЂР°СЃРїР°РєРѕРІРєРё/РєРѕРїРёСЂРѕРІР°РЅРёСЏ Р°СЂС…РёРІР°: ${e.toString()}');
        rethrow;
      } finally {
        try {
          if (await workDir.exists()) {
            await workDir.delete(recursive: true);
            addLog('Р’СЂРµРјРµРЅРЅР°СЏ РїР°РїРєР° СѓСЃС‚Р°РЅРѕРІРєРё СѓРґР°Р»РµРЅР°: ${workDir.path}');
          }
        } catch (e) {
          addLog(
            'РќРµ СѓРґР°Р»РѕСЃСЊ СѓРґР°Р»РёС‚СЊ РІСЂРµРјРµРЅРЅСѓСЋ РїР°РїРєСѓ СѓСЃС‚Р°РЅРѕРІРєРё: ${e.toString()}',
          );
        }
      }

      return;
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
        if (file.isFile) {
          final data = file.content as List<int>;
          final outFile = File(outPath);
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(data);
        } else {
          await Directory(outPath).create(recursive: true);
        }
      }

      final sourceDirectory = extractedDir;
      final allFiles = sourceDirectory.existsSync()
          ? sourceDirectory.listSync(recursive: true).whereType<File>().toList()
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
        final backupFile = File(path.join(backupDirPath, rel));
        await backupFile.parent.create(recursive: true);
        await targetFile.copy(backupFile.path);
      }

      for (final file in archive) {
        final targetFile = File('${dir.path}/${file.name}');
        if (file.isFile) {
          final data = file.content as List<int>;
          await targetFile.parent.create(recursive: true);
          await targetFile.writeAsBytes(data);
        } else {
          await Directory('${dir.path}/${file.name}').create(recursive: true);
        }
      }

      lastInstallSource = sourceDirectory.path;
      lastInstallTarget = targetDir;
      lastInstallFileCount = allFiles.length;
    } finally {
      if (await extractedDir.exists()) {
        await extractedDir.delete(recursive: true);
      }
    }
  }

  Future<bool> checkShizukuStatus() async {
    try {
      const methodChannel = MethodChannel(shizukuChannel);
      final result =
          await methodChannel.invokeMethod<bool>('checkShizukuStatus') ?? false;
      isShizukuActive = result;
      statusText = result ? 'Shizuku Р°РєС‚РёРІРµРЅ' : 'Shizuku РЅРµ Р°РєС‚РёРІРµРЅ';
      addLog(result ? 'Shizuku РґРѕСЃС‚СѓРїРµРЅ' : 'Shizuku РЅРµРґРѕСЃС‚СѓРїРµРЅ');
      notifyListeners();
      return result;
    } on PlatformException catch (error) {
      isShizukuActive = false;
      addLog(
        'РџСЂРѕРІРµСЂРєР° Shizuku Р·Р°РІРµСЂС€РёР»Р°СЃСЊ РѕС€РёР±РєРѕР№: ${error.message ?? 'unknown'}',
      );
      notifyListeners();
      return false;
    }
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
    String message = 'РќРµ СѓРґР°Р»РѕСЃСЊ РІС‹РїРѕР»РЅРёС‚СЊ Р·Р°РїСЂРѕСЃ';

    if (exception.type == DioExceptionType.connectionTimeout) {
      message = 'РўР°Р№РјР°СѓС‚ СЃРѕРµРґРёРЅРµРЅРёСЏ. РџСЂРѕРІРµСЂСЊС‚Рµ РёРЅС‚РµСЂРЅРµС‚-РїРѕРґРєР»СЋС‡РµРЅРёРµ.';
    } else if (exception.type == DioExceptionType.receiveTimeout) {
      message = 'РЎРµСЂРІРµСЂ РґРѕР»РіРѕ РѕС‚РІРµС‡Р°РµС‚.';
    } else if (exception.type == DioExceptionType.connectionError) {
      message = 'РќРµС‚ РёРЅС‚РµСЂРЅРµС‚-СЃРѕРµРґРёРЅРµРЅРёСЏ РёР»Рё СЃРµСЂРІРµСЂ РЅРµРґРѕСЃС‚СѓРїРµРЅ.';
    } else if (exception.response?.statusCode == 401) {
      message = 'GitHub РѕС‚РєР»РѕРЅРёР» Р·Р°РїСЂРѕСЃ. РџРѕРІС‚РѕСЂРёС‚Рµ РїСЂРѕРІРµСЂРєСѓ Р±РµР· Р»РёС€РЅРµРіРѕ С‚РѕРєРµРЅР°.';
    } else if (exception.response?.statusCode == 403) {
      message = 'GitHub API РѕРіСЂР°РЅРёС‡РёР» С‡РёСЃР»Рѕ Р·Р°РїСЂРѕСЃРѕРІ. РџРѕРїСЂРѕР±СѓР№С‚Рµ РїРѕР·Р¶Рµ.';
    } else if (exception.response?.statusCode == 404) {
      message = 'Р РµР»РёР· РЅРµ РЅР°Р№РґРµРЅ. РџСЂРѕРІРµСЂСЊС‚Рµ СЂРµРїРѕР·РёС‚РѕСЂРёР№ SOLIDLEAF-TEAM.';
    } else if (exception.error != null) {
      message = exception.error.toString();
    }

    statusText = message;
    addLog(message);
    notifyListeners();
  }
}

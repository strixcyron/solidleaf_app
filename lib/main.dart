import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

const String githubLatestReleaseUrl =
    'https://api.github.com/repos/strixcyron/SOLIDLEAF-TEAM/releases/latest';
const String shizukuChannel = 'com.example.re_1999_solidleaf/shizuku';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1180, 760),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => LauncherController(),
      child: const LocalizationLauncher(),
    ),
  );
}

class LocalizationLauncher extends StatelessWidget {
  const LocalizationLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SOLIDLEAF TEAM',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF111019),
        cardColor: const Color(0xFF1D1A2B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B52F4),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Inter',
      ),
      home: const MainScreen(),
    );
  }
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

  bool isDownloading = false;
  bool hasUpdate = false;
  bool isShizukuActive = false;
  double downloadProgress = 0;
  String installPath = '';
  String currentVersion = 'v0.0.0';
  String remoteVersion = '—';
  String changelog = 'Проверка обновлений не запускалась';
  String statusText = 'Готово';
  List<String> logs = [];

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    currentVersion = prefs.getString('installed_version') ?? 'v0.0.0';
    installPath = _defaultInstallPath();
    if (Platform.isAndroid) {
      await checkShizukuStatus();
    }
    await checkForUpdates();
    notifyListeners();
  }

  String _defaultInstallPath() {
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Android/data/com.bluepoch.m.en.reverse1999/';
    }
    if (Platform.isWindows) {
      return r'C:\Games\Reverse1999\Reverse1999_EN';
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

  // Files that must be backed up before installing the localization
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
    // Place backup folder inside installPath to keep structure simple
    return path.join(installPath, 'backup_solidleaf');
  }

  String _joinPath(String base, String relative) {
    return path.join(base, relative);
  }

  Future<Map<String, dynamic>> _runShizukuCmd(String command) async {
    try {
      const methodChannel = MethodChannel(shizukuChannel);
      final result = await methodChannel.invokeMethod<Map>('executeShellCommand', command);
      if (result == null) throw Exception('Shizuku command returned no result');
      final map = Map<String, dynamic>.from(result.cast<String, dynamic>());
      final exitCodeRaw = map['exitCode'];
      final exitCode = exitCodeRaw is int ? exitCodeRaw : int.tryParse(exitCodeRaw?.toString() ?? '') ?? -1;
      if (exitCode != 0) {
        final stderr = (map['stderr'] ?? '').toString();
        final stdout = (map['stdout'] ?? '').toString();
        addLog('Shizuku command failed (exitCode=$exitCode): $stderr');
        throw Exception('Shizuku command failed: ${stderr.isNotEmpty ? stderr : stdout}');
      }
      return map;
    } on PlatformException catch (e) {
      addLog('Shizuku command failed: ${e.message ?? 'unknown'}');
      rethrow;
    }
  }

  Future<void> _runShizukuCopy(String src, String dst) async {
    try {
      final dstDir = path.dirname(dst);
      await _runShizukuCmd('mkdir -p "$dstDir"');
      final res = await _runShizukuCmd('cp -a "$src" "$dst"');
      addLog('Shizuku copy result: src=$src dst=$dst exit=${res['exitCode']} stderr=${res['stderr']}');
    } catch (e) {
      addLog('Shizuku copy failed: ${e.toString()}');
      rethrow;
    }
  }

  Future<bool> _shizukuExists(String checkPath) async {
    try {
      final outMap = await _runShizukuCmd('sh -c "[ -e "$checkPath" ] && echo exists || echo missing"');
      final out = (outMap['stdout'] ?? '').toString();
      return out.toLowerCase().contains('exists');
    } catch (e) {
      addLog('Shizuku exists check failed: ${e.toString()}');
      return false;
    }
  }

  Future<void> createBackup() async {
    addLog('Создание резервной копии файлов...');
    final backupDirPath = _backupFolderName();
    try {
      if (Platform.isAndroid && !isShizukuActive) {
        addLog('Shizuku не активен — создание бэкапа на Android невозможно');
        throw Exception('Shizuku required for Android backup');
      }

      final files = Platform.isWindows ? _backupFilesWindows : _backupFilesAndroid;

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
          if (await dstFile.exists()) {
            addLog('Файл уже есть в бэкапе, не перезаписываем: $dst');
            continue;
          }
          await dstFile.parent.create(recursive: true);
          await srcFile.copy(dst);
          addLog('Скопировано в бэкап: $rel');
        } else if (Platform.isAndroid) {
          // Using Shizuku shell command to copy files with preserved dirs
          final srcExists = await _shizukuExists(src);
          if (!srcExists) {
            addLog('Исходный файл не найден, пропуск (Android): $src');
            continue;
          }

          final dstExists = await _shizukuExists(dst);
          if (dstExists) {
            addLog('Файл уже есть в бэкапе, не перезаписываем (Android): $dst');
            continue;
          }

          await _runShizukuCmd('mkdir -p "${path.dirname(dst)}"');
          await _runShizukuCopy(src, dst);
          addLog('Shizuku: скопирован в бэкапе: $rel');
        }
      }

      addLog('Создание резервной копии завершено');
    } catch (e) {
      addLog('Ошибка создания бэкапа: $e');
      rethrow;
    }
  }

  Future<void> restoreBackup() async {
    addLog('Восстановление из бэкапа...');
    final backupDirPath = _backupFolderName();
    try {
      final files = Platform.isWindows ? _backupFilesWindows : _backupFilesAndroid;

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
          if (!isShizukuActive) {
            addLog('Shizuku не активен — восстановление на Android невозможно');
            throw Exception('Shizuku required for Android restore');
          }

          final srcExists = await _shizukuExists(src);
          if (!srcExists) {
            addLog('В бэкапе не найден файл, пропуск (Android): $src');
            continue;
          }

          await _runShizukuCmd('mkdir -p "${path.dirname(dst)}"');
          await _runShizukuCopy(src, dst);
          addLog('Shizuku: восстановлен файл: $rel');
        }
      }

      // Cleanup backup folder
      if (Platform.isAndroid) {
        try {
          final outMap = await _runShizukuCmd('sh -c "[ -d "$backupDirPath" ] && echo exists || echo missing"');
          final out = (outMap['stdout'] ?? '').toString();
          if (out.toLowerCase().contains('exists')) {
            await _runShizukuCmd('rm -rf "$backupDirPath"');
            addLog('Папка бэкапа удалена (Shizuku)');
          }
        } catch (e) {
          addLog('Не удалось удалить папку бэкапа через Shizuku: ${e.toString()}');
        }
      } else {
        final backupDir = Directory(backupDirPath);
        if (await backupDir.exists()) {
          await backupDir.delete(recursive: true);
          addLog('Папка бэкапа удалена');
        }
      }

      // Reset installed version state
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
  Future<void> checkForUpdates() async {
    try {
      statusText = 'Проверка обновлений...';
      addLog('Запрос к GitHub Releases...');
      final response = await _dio.get(githubLatestReleaseUrl).timeout(const Duration(seconds: 10));

      if (response.statusCode == null) {
        throw Exception('Пустой ответ от GitHub');
      }

      if (response.statusCode == 403 || response.statusCode == 429) {
        throw Exception('Превышен лимит запросов к GitHub. Попробуйте позже.');
      }

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Ошибка сервера GitHub: ${response.statusCode}');
      }

      final data = Map<String, dynamic>.from(response.data as Map);
      final version = (data['tag_name'] ?? data['name'] ?? 'v0.0.0').toString();
      final body = (data['body'] ?? 'Без списка изменений').toString();
      final assets = List<dynamic>.from(data['assets'] ?? const []);

      // Platform-aware asset selection: prefer a platform-specific full archive by filename
      final zipAsset = assets.firstWhere(
        (asset) {
          final name = (asset['name'] ?? '').toString().toLowerCase();
          if (Platform.isWindows) {
            return name.contains('_pc_full.zip');
          }
          if (Platform.isAndroid) {
            return name.contains('_android_full.zip');
          }
          // Fallback: accept any .zip for other platforms
          final url = (asset['browser_download_url'] ?? '').toString();
          return url.toLowerCase().endsWith('.zip');
        },
        orElse: () => null,
      );

      remoteVersion = version;
      changelog = body;

      if (zipAsset == null) {
        throw Exception('Архив для вашей платформы не найден в релизе');
      }

      final zipUrl = (zipAsset['browser_download_url'] ?? '').toString();
      final isNewer = _isVersionNewer(remoteVersion, currentVersion);
      hasUpdate = isNewer;
      statusText = isNewer ? 'Доступно обновление' : 'Установлена актуальная версия';
      addLog('Версия на GitHub: $remoteVersion');
      addLog('Локальная версия: $currentVersion');
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

  Future<void> selectInstallPath() async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Выберите папку установки',
    );
    if (selected != null && selected.isNotEmpty) {
      installPath = selected;
      addLog('Выбрана папка: $installPath');
      notifyListeners();
    }
  }

  Future<void> installOrUpdate() async {
    if (remoteVersion == '—') {
      await checkForUpdates();
    }

    if (!hasUpdate && currentVersion != 'v0.0.0') {
      addLog('Обновлений не требуется. Установка уже актуальна.');
      statusText = 'Установлена актуальная версия';
      notifyListeners();
      return;
    }

    try {
      isDownloading = true;
      downloadProgress = 0;
      notifyListeners();

      final assets = await _getAssets();
      final zipUrl = assets['browser_download_url'] as String?;
      if (zipUrl == null || zipUrl.isEmpty) {
        throw DioException(
          requestOptions: RequestOptions(path: githubLatestReleaseUrl),
          error: 'Не удалось найти zip-архив в GitHub Releases',
        );
      }

      final tempDir = await getTemporaryDirectory();
      final zipPath = '${tempDir.path}/reverse1999_${DateTime.now().millisecondsSinceEpoch}.zip';
      await _dio.download(
        zipUrl,
        zipPath,
        onReceiveProgress: (received, total) {
          if (total <= 0) {
            return;
          }
          final progress = received / total;
          downloadProgress = progress;
          statusText = 'Загрузка: ${(progress * 100).toStringAsFixed(0)}%';
          notifyListeners();
        },
      );

      addLog('Архив загружен: $zipPath');
      // Create backup of original files before extraction/deployment
      try {
        await createBackup();
      } catch (e) {
        addLog('Бэкап не выполнен: ${e.toString()}');
        // If backup fails on Android because Shizuku isn't available, abort installation
        rethrow;
      }

      await _extractArchive(zipPath, installPath);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('installed_version', remoteVersion);
      currentVersion = remoteVersion;
      hasUpdate = false;
      isDownloading = false;
      downloadProgress = 1;
      statusText = 'Установка завершена';
      addLog('Развёртывание файлов закончено.');
      notifyListeners();
    } on DioException catch (error) {
      isDownloading = false;
      _handleDioError(error);
    } catch (error) {
      isDownloading = false;
      final message = 'Ошибка установки: ${error.toString()}';
      statusText = message;
      addLog(message);
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _getAssets() async {
    try {
      final response = await _dio.get(githubLatestReleaseUrl).timeout(const Duration(seconds: 10));

      if (response.statusCode == 403 || response.statusCode == 429) {
        throw Exception('Превышен лимит запросов к GitHub. Попробуйте позже.');
      }

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Ошибка сервера GitHub: ${response.statusCode}');
      }

      final data = Map<String, dynamic>.from(response.data as Map);
      final assets = List<dynamic>.from(data['assets'] ?? const []);

      final zipAsset = assets.firstWhere(
        (asset) {
          final name = (asset['name'] ?? '').toString().toLowerCase();
          if (Platform.isWindows) {
            return name.contains('_pc_full.zip');
          }
          if (Platform.isAndroid) {
            return name.contains('_android_full.zip');
          }
          // Fallback: accept any .zip
          final url = (asset['browser_download_url'] ?? '').toString();
          return url.toLowerCase().endsWith('.zip');
        },
        orElse: () => null,
      );

      if (zipAsset == null) {
        throw Exception('Архив для вашей платформы не найден в релизе');
      }

      return Map<String, dynamic>.from(zipAsset as Map);
    } on TimeoutException catch (_) {
      throw Exception('Превышено время ожидания сервера');
    } on SocketException catch (_) {
      throw Exception('Нет подключения к интернету');
    } on DioException {
      rethrow;
    }
  }

  Future<void> _extractArchive(String zipPath, String targetDir) async {
    if (Platform.isAndroid) {
      // Two-step extraction to avoid relying on device 'unzip':
      // 1) extract archive in Dart to a temp directory
      // 2) use Shizuku to copy contents into the protected target
      // 3) remove temp directory
      final tempDir = await getTemporaryDirectory();
      final extractDir = path.join(tempDir.path, 'reverse1999_extract_${DateTime.now().millisecondsSinceEpoch}');
      final extractDirObj = Directory(extractDir);
      try {
        if (!await extractDirObj.exists()) await extractDirObj.create(recursive: true);

        final archiveFile = File(zipPath);
        final bytes = await archiveFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        for (final file in archive) {
          final outPath = path.join(extractDir, file.name);
          if (file.isFile) {
            final data = file.content as List<int>;
            final outFile = File(outPath);
            await outFile.parent.create(recursive: true);
            await outFile.writeAsBytes(data);
          } else {
            await Directory(outPath).create(recursive: true);
          }
        }

        // Ensure target exists and copy extracted contents into it using Shizuku
        final normExtract = path.normalize(extractDir);
        final normTarget = path.normalize(targetDir);
        await _runShizukuCmd('mkdir -p "$normTarget"');
        // Определяем базовые пути
        String sourceDir = normExtract;
        String finalTarget = normTarget;
        // Проверяем, содержит ли архив ПК-структуру
        final pcDataDir = Directory(path.join(normExtract, 'reverse1999_Data', 'StreamingAssets', 'PersistentRoot'));
        if (pcDataDir.existsSync()) {
          sourceDir = pcDataDir.path;
          finalTarget = path.join(normTarget, 'files', 'ResLib', 'Android');
        }
        // Нормализуем пути перед передачей в shell
        sourceDir = path.normalize(sourceDir);
        finalTarget = path.normalize(finalTarget);
        // Формируем команду с новыми переменными
        final command = "cd '$sourceDir' && chmod -R 777 . && find . -type d -exec mkdir -p '$finalTarget/{}' ';' && find . -type f -exec cp -f '{}' '$finalTarget/{}' ';'";
        await _runShizukuCmd(command);
      } catch (e) {
        addLog('Ошибка распаковки/копирования архива: ${e.toString()}');
        rethrow;
      } finally {
        try {
          if (await extractDirObj.exists()) {
            await extractDirObj.delete(recursive: true);
            addLog('Временная папка распаковки удалена: $extractDir');
          }
        } catch (e) {
          addLog('Не удалось удалить временную папку: ${e.toString()}');
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
  }

  Future<bool> checkShizukuStatus() async {
    try {
      const methodChannel = MethodChannel(shizukuChannel);
      final result = await methodChannel.invokeMethod<bool>('checkShizukuStatus') ?? false;
      isShizukuActive = result;
      statusText = result ? 'Shizuku активен' : 'Shizuku не активен';
      addLog(result ? 'Shizuku доступен' : 'Shizuku недоступен');
      notifyListeners();
      return result;
    } on PlatformException catch (error) {
      isShizukuActive = false;
      addLog('Проверка Shizuku завершилась ошибкой: ${error.message ?? 'unknown'}');
      notifyListeners();
      return false;
    }
  }

  bool _isVersionNewer(String remote, String local) {
    final remoteParts = _parseVersion(remote);
    final localParts = _parseVersion(local);
    for (var i = 0; i < [remoteParts.length, localParts.length].reduce((a, b) => a > b ? a : b); i++) {
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
    return cleaned.split('.').where((part) => part.isNotEmpty).map(int.parse).toList();
  }

  void _handleDioError(DioException exception) {
    String message = 'Не удалось выполнить запрос';

    if (exception.type == DioExceptionType.connectionTimeout) {
      message = 'Таймаут соединения. Проверьте интернет-подключение.';
    } else if (exception.type == DioExceptionType.receiveTimeout) {
      message = 'Сервер долго отвечает.';
    } else if (exception.type == DioExceptionType.connectionError) {
      message = 'Нет интернет-соединения или сервер недоступен.';
    } else if (exception.response?.statusCode == 403) {
      message = 'GitHub API ограничил число запросов. Попробуйте позже.';
    } else if (exception.error != null) {
      message = exception.error.toString();
    }

    statusText = message;
    addLog(message);
    notifyListeners();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LauncherController>().initialize();
    });
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  Future<void> _checkAndShowUpdateDialog() async {
    final controller = context.read<LauncherController>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B1826),
          title: const Text('Проверка обновлений'),
          content: const SizedBox(
            width: 300,
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Expanded(child: Text('Запрашиваем релиз с GitHub...')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена'),
            ),
          ],
        );
      },
    );

    try {
      await controller.checkForUpdates();
      if (!mounted) {
        return;
      }

      final rootNavigator = Navigator.of(context, rootNavigator: true);
      final bool canRootPop = rootNavigator.canPop();
      if (canRootPop) {
        rootNavigator.pop();
      }

      if (!controller.hasUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Обновлений не найдено.')),
        );
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1B1826),
            title: Text('Доступно обновление ${controller.remoteVersion}'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Text(
                  controller.changelog.isEmpty
                      ? 'Список изменений отсутствует.'
                      : controller.changelog,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Позже'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B52F4),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _runInstallFlow();
                },
                child: const Text('Обновить', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    } catch (_) {
      if (mounted == true) {
        final rootNavigator = Navigator.of(context, rootNavigator: true);
        final bool canRootPop = rootNavigator.canPop();
        if (canRootPop) {
          rootNavigator.pop();
        }
      }
    }
  }

  Future<void> _runInstallFlow() async {
    final controller = context.read<LauncherController>();

    if (!mounted) {
      return;
    }

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return Consumer<LauncherController>(
            builder: (context, value, child) {
              final progressPercent = value.isDownloading ? (value.downloadProgress * 100).clamp(0, 100).toInt() : 0;
              return AlertDialog(
                backgroundColor: const Color(0xFF1B1826),
                title: Text(
                  value.isDownloading ? 'Обновление ${value.remoteVersion}' : 'Установка завершена',
                  style: const TextStyle(fontSize: 18),
                ),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value.isDownloading
                            ? 'Скачивание обновления...'
                            : value.statusText,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(
                        value: null,
                        minHeight: 10,
                        backgroundColor: Color(0xFF2E2541),
                        color: Color(0xFF8A6AF6),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        value.isDownloading
                            ? 'Загружено: $progressPercent%'
                            : 'Готово',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                actions: [
                  if (!value.isDownloading)
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Закрыть'),
                    ),
                ],
              );
            },
          );
        },
      ),
    );

    try {
      await controller.installOrUpdate();
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LauncherController>();
    final isAndroidUi = Platform.isAndroid;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.jumpTo(_logScrollController.position.maxScrollExtent);
      }
    });

    return Scaffold(
      body: Column(
        children: [
          if (!isAndroidUi)
            const SizedBox(
              height: 42,
              child: WindowCaption(
                brightness: Brightness.dark,
                title: Text(
                  'SOLIDLEAF TEAM | Лаунчер русификаций',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          Expanded(
            child: isAndroidUi ? _buildAndroidLayout(controller) : _buildDesktopLayout(controller),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(LauncherController controller) {
    return Row(
      children: [
        Container(
          width: 80,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF201B2E), Color(0xFF181523)],
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 18),
              _navButton(Icons.home_rounded, true),
              _navButton(Icons.info_outline_rounded, false),
              const Spacer(),
              _navButton(Icons.settings_rounded, false),
              const SizedBox(height: 16),
            ],
          ),
        ),
        Container(
          width: 300,
          padding: const EdgeInsets.all(18),
          color: const Color(0xFF181523),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Библиотека',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const TextField(
                decoration: InputDecoration(
                  hintText: 'Поиск игр...',
                  filled: true,
                  fillColor: Color(0xFF252130),
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _buildGameListTile('Reverse: 1999', 'v 1.4.0', isActive: true),
            ],
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF101018), Color(0xFF17131F)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reverse: 1999',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Полная русификация (текст, интерфейс и графика)',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 26),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1B2C),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF4E3B8A), width: 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          controller.installPath,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontFamily: 'Consolas',
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: controller.selectInstallPath,
                        icon: const Icon(Icons.folder_open_rounded, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Компоненты',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1627),
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    border: Border.fromBorderSide(BorderSide(color: Color(0xFF2D2240), width: 1)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF8A6AF6)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Русская локализация', style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text(
                              'Перевод сюжета, текстур и внутриигровых меню',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text('~350 MB', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1627),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2A213D), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Статус: ${controller.statusText}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (controller.isDownloading)
                        LinearProgressIndicator(
                          value: controller.downloadProgress == 0 ? null : controller.downloadProgress,
                          minHeight: 8,
                          backgroundColor: const Color(0xFF302944),
                          color: const Color(0xFF8A6AF6),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF17131F),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2B243A), width: 1),
                    ),
                    child: ListView.builder(
                      controller: _logScrollController,
                      itemCount: controller.logs.length,
                      itemBuilder: (_, index) {
                        return Text(
                          controller.logs[index],
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: _checkAndShowUpdateDialog,
                        child: const Text('Проверить обновления', style: TextStyle(color: Colors.white70)),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1B1826),
                              title: const Text('Восстановление оригинальных файлов'),
                              content: const Text('Вы уверены, что хотите восстановить оригинальные файлы из бэкапа? Это удалит русификатор.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Отмена')),
                                ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Восстановить')),
                              ],
                            ),
                          );

                          if (!mounted) return;
                          if (confirmed == true) {
                            try {
                              await controller.restoreBackup();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Восстановление завершено')));
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка восстановления: ${e.toString()}')));
                            }
                          }
                        },
                        child: const Text('Удалить', style: TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B52F4),
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: controller.isDownloading ? null : _runInstallFlow,
                        child: Text(
                          controller.hasUpdate ? 'Обновить' : 'Установить',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAndroidLayout(LauncherController controller) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'SOLIDLEAF TEAM',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton.icon(
                onPressed: controller.checkShizukuStatus,
                icon: const Icon(Icons.security_rounded),
                label: const Text('Shizuku'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1627),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF4E3B8A), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reverse: 1999', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  controller.isShizukuActive ? 'Статус: Shizuku активен' : 'Статус: Shizuku не активен',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 14),
                if (controller.isDownloading)
                  LinearProgressIndicator(
                    value: controller.downloadProgress == 0 ? null : controller.downloadProgress,
                    minHeight: 12,
                    backgroundColor: const Color(0xFF2E2541),
                    color: const Color(0xFF8A6AF6),
                  ),
                const SizedBox(height: 12),
                Text('Версия: ${controller.currentVersion}', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                Text(controller.statusText, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF17131F),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              controller.changelog.isEmpty
                  ? 'Список изменений пока недоступен.'
                  : controller.changelog.length > 180
                      ? '${controller.changelog.substring(0, 180)}...'
                      : controller.changelog,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _checkAndShowUpdateDialog,
                  child: const Text('Проверить обновления'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1B1826),
                        title: const Text('Восстановление оригинальных файлов'),
                        content: const Text('Вы уверены, что хотите восстановить оригинальные файлы из бэкапа? Это удалит русификатор.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Отмена')),
                          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Восстановить')),
                        ],
                      ),
                    );

                    if (!mounted) return;
                    if (confirmed == true) {
                      try {
                        await controller.restoreBackup();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Восстановление завершено')));
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка восстановления: ${e.toString()}')));
                      }
                    }
                  },
                  child: const Text('Удалить', style: TextStyle(color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B52F4),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: controller.isDownloading ? null : _runInstallFlow,
                  child: Text(
                    controller.hasUpdate ? 'Обновить' : 'Установить',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameListTile(String title, String version, {required bool isActive}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF252130) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isActive ? Border.all(color: const Color(0xFF7B52F4), width: 1) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.gamepad_rounded, color: Colors.white54),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(version, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          if (isActive) const Icon(Icons.check_circle_rounded, color: Color(0xFF7B52F4), size: 18),
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, bool active) {
    return Container(
      width: 52,
      height: 52,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF2A2140) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: IconButton(
        onPressed: () {},
        icon: Icon(icon, color: active ? Colors.white : Colors.white54),
      ),
    );
  }
}

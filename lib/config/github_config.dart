import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// GitHub API configuration for release downloads.
///
/// The premium repository (`FrauxHD/PREMIUM`) is private and requires a
/// Personal Access Token with `repo` scope.
///
/// **Local development (Windows/Linux/macOS)** — create one of:
/// - `secrets/github_token.txt` in the project root
/// - `dart_defines.local.json` with `{"GITHUB_TOKEN": "ghp_..."}`
///
/// **Android / iOS** — token must be passed at build/run time:
/// `flutter run --dart-define-from-file=dart_defines.local.json`
/// (see `.vscode/launch.json` configuration «local secrets»).
///
/// **Release builds** — always use `--dart-define-from-file` or
/// `--dart-define=GITHUB_TOKEN=...`.
class GitHubConfig {
  GitHubConfig._();

  static String? _cachedToken;
  static bool _warmUpDone = false;

  /// Call once during app startup before any premium GitHub API request.
  static Future<void> warmUp() async {
    if (_warmUpDone) {
      return;
    }
    _warmUpDone = true;

    const fromEnv = String.fromEnvironment('GITHUB_TOKEN', defaultValue: '');
    if (fromEnv.isNotEmpty) {
      _cachedToken = fromEnv;
      return;
    }

    final projectRoot = _findProjectRoot();
    if (projectRoot != null) {
      _cachedToken = _readTokenFromDirectory(projectRoot);
      if (_cachedToken != null) {
        return;
      }
    }

    if (Platform.isAndroid || Platform.isIOS) {
      _cachedToken = await _readTokenFromAppSupport();
    }
  }

  /// PAT used only for authenticated requests to the private premium repo.
  static String get premiumToken => _cachedToken ?? '';

  static bool get hasPremiumToken => premiumToken.isNotEmpty;

  static String? _findProjectRoot() {
    try {
      var dir = Directory.current;
      for (var depth = 0; depth < 10; depth++) {
        if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
          return dir.path;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) {
          break;
        }
        dir = parent;
      }
    } catch (_) {
      // Ignore filesystem errors on restricted platforms.
    }
    return null;
  }

  static String? _readTokenFromDirectory(String root) {
    for (final relative in [
      p.join('secrets', 'github_token.txt'),
      'github_token.txt',
      p.join('dart_defines.local.json'),
      'dart_defines.json',
    ]) {
      final file = File(p.join(root, relative));
      if (!file.existsSync()) {
        continue;
      }

      if (relative.endsWith('.json')) {
        try {
          final data = jsonDecode(file.readAsStringSync());
          if (data is Map<String, dynamic>) {
            final token = (data['GITHUB_TOKEN'] ?? '').toString().trim();
            if (token.isNotEmpty) {
              return token;
            }
          }
        } catch (_) {
          // Ignore malformed JSON.
        }
        continue;
      }

      final token = file.readAsStringSync().trim();
      if (token.isNotEmpty && !token.startsWith('YOUR_')) {
        return token;
      }
    }
    return null;
  }

  static Future<String?> _readTokenFromAppSupport() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'github_token.txt'));
      if (!file.existsSync()) {
        return null;
      }
      final token = file.readAsStringSync().trim();
      return token.isNotEmpty ? token : null;
    } catch (_) {
      return null;
    }
  }

  /// Human-readable setup hint for the current platform.
  static String get setupHint {
    if (Platform.isAndroid || Platform.isIOS) {
      return 'Создайте dart_defines.local.json (см. dart_defines.local.json.example) '
          'и запускайте через конфигурацию «local secrets» в VS Code / Cursor, '
          'либо: flutter run --dart-define-from-file=dart_defines.local.json';
    }
    return 'Создайте secrets/github_token.txt в корне проекта '
        'или dart_defines.local.json (см. dart_defines.local.json.example), '
        'либо соберите с --dart-define=GITHUB_TOKEN=<ваш_токен>.';
  }
}

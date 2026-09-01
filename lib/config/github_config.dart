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
  static String _debugSource = 'none';
  static String _debugPath = '?';

  /// Whether a value looks like a real GitHub token rather than a placeholder
  /// (e.g. the `YOUR_GITHUB_PAT_HERE` sample) accidentally left in a config.
  static bool looksLikeToken(String value) {
    final v = sanitizeToken(value);
    if (v.length < 20) return false;
    if (v.startsWith('YOUR_')) return false;
    return v.startsWith('ghp_') ||
        v.startsWith('github_pat_') ||
        v.startsWith('gho_') ||
        v.startsWith('ghs_') ||
        v.startsWith('ghu_');
  }

  static String sanitizeToken(String raw) {
    return raw
        .replaceAll('\uFEFF', '')
        .replaceAll(RegExp(r'[\s\r\n]'), '')
        .trim();
  }

  /// Load the token from every available source.
  ///
  /// Project secret files are re-read on EVERY call (not just when [force] is
  /// set): they are the source of truth for local dev, and re-reading them is
  /// what lets a mid-session token change take effect without a full restart.
  ///
  /// This matters specifically for hot reload: [_cachedToken] is `static`, so
  /// a hot reload swaps in new code but keeps the token that was cached at the
  /// first launch. Previously an early `return` pinned that first token, so an
  /// old/expired token kept being sent — and GitHub returns 404 (not 401) for
  /// a *private* repo a token can't see, which looks exactly like "release not
  /// found". Always re-reading the file avoids that stale-token trap.
  static Future<void> warmUp({bool force = false}) async {
    const fromEnv = String.fromEnvironment('GITHUB_TOKEN', defaultValue: '');
    final envToken = sanitizeToken(fromEnv);

    // 1) Project secret files — always re-read so file edits win immediately.
    final projectRoot = _findProjectRoot();
    if (projectRoot != null) {
      final fromProject = _readTokenFromDirectory(projectRoot);
      if (looksLikeToken(fromProject ?? '')) {
        final token = sanitizeToken(fromProject!);
        _debugSource = 'project-file';
        if (token != _cachedToken) {
          _cachedToken = token;
          await _persistToken(token);
        }
        return;
      }
    }

    // No usable project file — reuse the resolved token unless forced.
    if (!force && looksLikeToken(_cachedToken ?? '')) {
      return;
    }
    _cachedToken = null;
    _debugSource = 'none';

    // 2) App-support cache (survives when the exe cwd is not the repo root).
    final fromSupport = await _readTokenFromAppSupport();
    if (looksLikeToken(fromSupport ?? '')) {
      _cachedToken = sanitizeToken(fromSupport!);
      _debugSource = 'app-support';
      _debugPath = 'app-support/github_token.txt';
      return;
    }

    // 3) Compile-time --dart-define (release / CI builds).
    if (looksLikeToken(envToken)) {
      _cachedToken = envToken;
      _debugSource = 'dart-define';
      _debugPath = 'env';
      return;
    }
  }

  /// PAT used only for authenticated requests to the private premium repo.
  static String get premiumToken => _cachedToken ?? '';

  static bool get hasPremiumToken => looksLikeToken(premiumToken);

  /// Short, non-sensitive description of where the token came from and its
  /// shape — safe to surface in logs (never prints the token itself).
  static String get debugState {
    final t = premiumToken;
    if (!looksLikeToken(t)) {
      return 'token: none (source=$_debugSource root=${_findProjectRoot() ?? "?"})';
    }
    return 'token: len=${t.length} prefix=${t.substring(0, 4)} '
        'source=$_debugSource path=$_debugPath';
  }

  static String? _findProjectRoot() {
    final starts = <String>{};
    try {
      starts.add(Directory.current.path);
      starts.add(File(Platform.resolvedExecutable).parent.path);
    } catch (_) {
      // Ignore filesystem errors on restricted platforms.
    }

    for (final start in starts) {
      var dir = Directory(start);
      for (var depth = 0; depth < 12; depth++) {
        if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
          return dir.path;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) {
          break;
        }
        dir = parent;
      }
    }
    return null;
  }

  static String? _readTokenFromDirectory(String root) {
    for (final relative in [
      p.join('secrets', 'github_token.txt'),
      'github_token.txt',
      'dart_defines.local.json',
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
            final token = sanitizeToken(
              (data['GITHUB_TOKEN'] ?? '').toString(),
            );
            if (looksLikeToken(token)) {
              _debugPath = file.path;
              return token;
            }
          }
        } catch (_) {
          // Ignore malformed JSON.
        }
        continue;
      }

      final token = sanitizeToken(file.readAsStringSync());
      if (looksLikeToken(token)) {
        _debugPath = file.path;
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
      final token = sanitizeToken(file.readAsStringSync());
      return looksLikeToken(token) ? token : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _persistToken(String token) async {
    try {
      final dir = await getApplicationSupportDirectory();
      await File(p.join(dir.path, 'github_token.txt')).writeAsString(token);
    } catch (_) {
      // Best-effort cache for the next launch.
    }
  }

  /// Подсказка при отсутствии токена (в основном для Windows-сборок).
  static String get setupHint {
    if (Platform.isAndroid || Platform.isIOS) {
      return 'На Android/iOS премиум-релизы идут через auth-backend по JWT после '
          'входа в Telegram. GITHUB_TOKEN в APK не требуется.';
    }
    return 'Создайте secrets/github_token.txt в корне проекта '
        'или dart_defines.local.json (см. dart_defines.local.json.example), '
        'либо соберите с --dart-define=GITHUB_TOKEN=<ваш_токен>.';
  }
}

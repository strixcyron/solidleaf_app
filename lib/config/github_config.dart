import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// GitHub API configuration for release downloads.
///
/// The premium repository (`FrauxHD/PREMIUM`) is private and requires a
/// Personal Access Token with `repo` scope.
///
/// **Local development** — create one of these files (they are gitignored):
/// - `secrets/github_token.txt` — paste the token as a single line
/// - `dart_defines.local.json` — `{"GITHUB_TOKEN": "ghp_..."}`
///
/// **Release builds** — pass at compile time:
/// `flutter build windows --dart-define-from-file=dart_defines.local.json`
class GitHubConfig {
  GitHubConfig._();

  static String? _fileToken;
  static bool _fileTokenResolved = false;

  /// PAT used only for authenticated requests to the private premium repo.
  static String get premiumToken {
    const fromEnv = String.fromEnvironment('GITHUB_TOKEN', defaultValue: '');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }

    if (kDebugMode) {
      return _readTokenFromProjectFiles() ?? '';
    }

    return '';
  }

  static bool get hasPremiumToken => premiumToken.isNotEmpty;

  static String? _readTokenFromProjectFiles() {
    if (_fileTokenResolved) {
      return _fileToken;
    }
    _fileTokenResolved = true;

    for (final path in ['secrets/github_token.txt', 'github_token.txt']) {
      final file = File(path);
      if (!file.existsSync()) {
        continue;
      }
      final token = file.readAsStringSync().trim();
      if (token.isNotEmpty) {
        _fileToken = token;
        return token;
      }
    }

    for (final path in ['dart_defines.local.json', 'dart_defines.json']) {
      final file = File(path);
      if (!file.existsSync()) {
        continue;
      }
      try {
        final data = jsonDecode(file.readAsStringSync());
        if (data is Map<String, dynamic>) {
          final token = (data['GITHUB_TOKEN'] ?? '').toString().trim();
          if (token.isNotEmpty) {
            _fileToken = token;
            return token;
          }
        }
      } catch (_) {
        // Ignore malformed local secrets file.
      }
    }

    return null;
  }
}

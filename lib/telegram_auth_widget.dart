import 'package:flutter/material.dart';

import 'telegram_auth_service.dart';

/// Example UI component demonstrating the Telegram login flow and premium
/// texture download exposed by [TelegramAuthService].
///
/// Drop this widget anywhere in the widget tree (e.g. inside the main
/// launcher screen) to offer a "Войти через Telegram" button, a loading
/// indicator while waiting for confirmation, a "Премиум активен" status once
/// logged in, and a button to download the premium textures archive.
class TelegramAuthWidget extends StatefulWidget {
  const TelegramAuthWidget({super.key});

  @override
  State<TelegramAuthWidget> createState() => _TelegramAuthWidgetState();
}

class _TelegramAuthWidgetState extends State<TelegramAuthWidget> {
  final _authService = TelegramAuthService();

  bool _isLoggingIn = false;
  bool _isLoggedIn = false;
  bool _isDownloading = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _refreshLoginState();
  }

  @override
  void dispose() {
    _authService.dispose();
    super.dispose();
  }

  Future<void> _refreshLoginState() async {
    final loggedIn = await _authService.isLoggedIn();
    if (!mounted) return;
    setState(() => _isLoggedIn = loggedIn);
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoggingIn = true;
      _statusMessage = 'Откройте Telegram и подтвердите вход...';
    });

    try {
      final success = await _authService.loginWithTelegram();
      if (!mounted) return;
      setState(() {
        _isLoggedIn = success;
        _statusMessage = success ? 'Вход выполнен успешно.' : null;
      });
    } on TelegramAuthException catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = 'Неизвестная ошибка входа: $e');
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  Future<void> _handleLogout() async {
    await _authService.logout();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = false;
      _statusMessage = null;
    });
  }

  Future<void> _handleDownloadTextures() async {
    setState(() {
      _isDownloading = true;
      _statusMessage = 'Скачивание премиум-текстур...';
    });

    try {
      final file = await _authService.downloadPremiumTextures();
      if (!mounted) return;
      setState(() => _statusMessage = 'Текстуры сохранены: ${file.path}');
    } on TelegramAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = e.message;
        // A 401 from the backend already triggered logout() inside the
        // service — reflect that in the UI so the login button reappears.
        _isLoggedIn = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = 'Ошибка скачивания: $e');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1627),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D2240), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                _isLoggedIn ? Icons.verified_rounded : Icons.send_rounded,
                color: _isLoggedIn ? const Color(0xFF4CAF50) : const Color(0xFF8A6AF6),
              ),
              const SizedBox(width: 8),
              Text(
                _isLoggedIn ? 'Премиум активен' : 'Вход не выполнен',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 8),
            Text(_statusMessage!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          if (!_isLoggedIn)
            ElevatedButton.icon(
              onPressed: _isLoggingIn ? null : _handleLogin,
              icon: _isLoggingIn
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_isLoggingIn ? 'Ожидание подтверждения...' : 'Войти через Telegram'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF229ED9)),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isDownloading ? null : _handleDownloadTextures,
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(_isDownloading ? 'Скачивание...' : 'Скачать премиум-текстуры'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B52F4)),
                ),
                OutlinedButton(
                  onPressed: _handleLogout,
                  child: const Text('Выйти'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

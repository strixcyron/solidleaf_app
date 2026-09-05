import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/github_config.dart';
import '../controllers/launcher_controller.dart';
import '../telegram_auth_config.dart';
import '../telegram_auth_service.dart';
import 'main_screen.dart';

// Public community group — joining this is enough to log in with "basic"
// (text-only) access.
const String telegramUrl = 'https://t.me/reverse1999_solidleaf';

/// Decides whether to show the mandatory [LoginScreen] or the main
/// [MainScreen], based on whether a Telegram-issued JWT is already stored
/// locally. The launcher cannot be used without completing the Telegram
/// login flow at least once (or until the stored token is cleared/expires).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final TelegramAuthService _authService = TelegramAuthService();

  bool _isChecking = true;
  bool _isLoggedIn = false;
  bool _launcherActive = true;
  String _maintenanceMessage = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _authService.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _checkStoredSession(),
      _checkLauncherStatus(),
    ]);
    if (!mounted) return;
    setState(() => _isChecking = false);
  }

  Future<void> _checkStoredSession() async {
    final loggedIn = await _authService.isLoggedIn();
    if (!mounted) return;
    setState(() => _isLoggedIn = loggedIn);
  }

  Future<void> _checkLauncherStatus() async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final res = await dio.get<Map<String, dynamic>>(
        '${TelegramAuthConfig.baseUrl}/api/launcher/status',
      );
      final data = res.data ?? {};
      if (!mounted) return;
      setState(() {
        _launcherActive = data['active'] as bool? ?? true;
        _maintenanceMessage =
            (data['maintenance_message'] as String?)?.trim() ?? '';
      });
    } catch (_) {
      // При недоступности API не блокируем вход.
    }
  }

  void _handleLoginSuccess() {
    setState(() => _isLoggedIn = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: Color(0xFF111019),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF7B52F4)),
        ),
      );
    }

    if (!_launcherActive) {
      return Scaffold(
        backgroundColor: const Color(0xFF111019),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 56,
                    color: Color(0xFF7B52F4),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Лаунчер временно недоступен',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFEEEEEE),
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _maintenanceMessage.isNotEmpty
                        ? _maintenanceMessage
                        : 'Ведутся технические работы. Попробуйте позже.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFA09CB0),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: () async {
                      setState(() => _isChecking = true);
                      await _checkLauncherStatus();
                      if (!mounted) return;
                      setState(() => _isChecking = false);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Проверить снова'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_isLoggedIn) {
      return LoginScreen(onLoginSuccess: _handleLoginSuccess);
    }

    return const MainScreen();
  }
}

/// Full-screen, mandatory Telegram login gate.
///
/// Layout: cover art on the bottom layer (`Stack`), a dark gradient scrim for
/// contrast, and a blurred glass-style card (`BackdropFilter`) on top holding
/// the actual login form/status.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoginSuccess});

  /// Called once the backend confirms the login and the JWT has been saved.
  final VoidCallback onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TelegramAuthService _authService = TelegramAuthService();

  bool _isLoggingIn = false;
  String? _errorMessage;
  bool _showJoinChannelHint = false;

  @override
  void dispose() {
    _authService.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoggingIn = true;
      _errorMessage = null;
      _showJoinChannelHint = false;
    });

    try {
      final success = await _authService.loginWithTelegram();
      if (!mounted) return;
      if (success) {
        // After successful login, re-check updates
        // so that the backend can use the JWT to determine which release to return
        final controller = context.read<LauncherController>();
        await GitHubConfig.warmUp();
        await controller.refreshPremiumStatus();
        await controller.checkForUpdates();
        if (controller.isPremium) {
          await controller.checkForArtUpdates();
        }
        widget.onLoginSuccess();
        return;
      }
    } on TelegramAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        // Подсказка про канал — только когда отказ похож на отсутствие подписки,
        // а не на сеть / таймаут / отмену.
        final msg = e.message.toLowerCase();
        _showJoinChannelHint = msg.contains('подпис') ||
            msg.contains('канал') ||
            msg.contains('не состоит') ||
            msg.contains('не удалось подтвердить');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Неизвестная ошибка входа: $e');
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  void _handleCancel() {
    _authService.cancelLogin();
    setState(() => _isLoggingIn = false);
  }

  Future<void> _openChannel() async {
    // Reuses the same community Telegram link shown elsewhere in the app.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final opened = await launchUrl(
      Uri.parse(telegramUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted && messenger != null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку: $telegramUrl')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- Background art (bottom layer) ---------------------------------
          Image.asset(
            'assets/images/cover.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3A2B6E), Color(0xFF1B1430)],
                ),
              ),
            ),
          ),
          // Dark scrim so the glass card and text stay readable over the art.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
          // --- Login form (glass card on top) --------------------------------
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    width: 380,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1627).withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color.fromARGB(255, 112, 89, 187),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.lock_person_rounded,
                          color: Color(0xFF8A6AF6),
                          size: 42,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'SOLIDLEAF TEAM',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Войдите через Telegram, чтобы продолжить работу с лаунчером',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        // Подсказка про VPN: сервер авторизации иногда
                        // недоступен из‑за маршрутизации/блокировок.
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.vpn_lock_rounded,
                                  size: 16,
                                  color: Colors.white54,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Если вход не работает — попробуйте включить VPN '
                                  'или, наоборот, отключить его и повторить попытку.',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11.5,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _isLoggingIn ? null : _handleLogin,
                          icon: _isLoggingIn
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            _isLoggingIn
                                ? 'Ожидание подтверждения...'
                                : 'Войти через Telegram',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 3, 1, 17),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        if (_isLoggingIn) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Откройте Telegram и подтвердите вход в открывшемся чате с ботом.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _handleCancel,
                            child: const Text(
                              'Отмена',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                        ],
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              // Warm amber tone reused across the app to flag
                              // "attention needed" states (see also
                              // _buildVersionBadge's "update available" color
                              // in main.dart) — keeps warning colors consistent.
                              color: const Color(0xFFD97706)
                                  .withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFD97706),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFD97706),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_showJoinChannelHint) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _openChannel,
                              icon: const Icon(Icons.diamond_rounded, size: 16),
                              label: const Text('Присоединиться к каналу'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

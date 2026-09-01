import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/launcher_controller.dart';
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

  @override
  void initState() {
    super.initState();
    _checkStoredSession();
  }

  @override
  void dispose() {
    _authService.dispose();
    super.dispose();
  }

  Future<void> _checkStoredSession() async {
    final loggedIn = await _authService.isLoggedIn();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = loggedIn;
      _isChecking = false;
    });
  }

  void _handleLoginSuccess() {
    setState(() => _isLoggedIn = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      // Brief splash while we read the secure storage for a saved session.
      return const Scaffold(
        backgroundColor: Color(0xFF111019),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF7B52F4)),
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
        // The backend only rejects the login when the user isn't subscribed
        // to the required channel — surface a join-channel hint in that case
        // (but not for a user-triggered cancel or a plain timeout).
        _showJoinChannelHint =
            !e.message.contains('отменён') && !e.message.contains('истекло');
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

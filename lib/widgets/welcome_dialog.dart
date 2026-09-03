import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

/// Показывает приветственный диалог первого запуска.
///
/// Закрывается кнопкой «Понятно, начать!» или тапом мимо окна.
Future<void> showWelcomeOnboardingDialog(
  BuildContext context, {
  bool animate = true,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Закрыть приветствие',
    barrierColor: Colors.black.withValues(alpha: 0.62),
    transitionDuration: animate
        ? const Duration(milliseconds: 380)
        : Duration.zero,
    pageBuilder: (ctx, _, __) {
      return SafeArea(
        child: Center(
          child: WelcomeDialog(
            onStart: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Стеклянная карточка онбординга: логотип, возможности, кнопка старта.
class WelcomeDialog extends StatelessWidget {
  const WelcomeDialog({super.key, required this.onStart});

  final VoidCallback onStart;

  static const _accent = Color(0xFF7B52F4);
  static const _accentSoft = Color(0xFF8A6AF6);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isNarrow = size.width < 520;
    final maxWidth = isNarrow ? size.width - 32 : 440.0;
    final maxHeight = size.height * 0.9;

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF16122A).withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _accentSoft.withValues(alpha: 0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.22),
                    blurRadius: 32,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  isNarrow ? 20 : 26,
                  22,
                  isNarrow ? 20 : 26,
                  22,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 18),
                    const _FeatureCard(
                      icon: Icons.bolt_rounded,
                      title: 'Автоматическое обновление',
                      subtitle:
                          'Актуальные текстовые и графические патчи в один клик.',
                    ),
                    const SizedBox(height: 8),
                    const _FeatureCard(
                      icon: Icons.key_rounded,
                      title: 'Telegram-авторизация',
                      subtitle:
                          'Эксклюзивный доступ для участников сообщества.',
                    ),
                    const SizedBox(height: 8),
                    const _FeatureCard(
                      icon: Icons.handyman_rounded,
                      title: 'Удобная установка',
                      subtitle:
                          'Поддержка ПК и Android (Shizuku) без лишних сложностей.',
                    ),
                    const SizedBox(height: 14),
                    _buildQuickStartHint(),
                    const SizedBox(height: 18),
                    _GlowStartButton(onPressed: onStart),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.4),
                blurRadius: 18,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/launcher_icon.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFF2A2150),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: _accentSoft,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Добро пожаловать в SolidLeaf Launcher!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Неофициальный лаунчер русификации Reverse: 1999',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.68),
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStartHint() {
    final hint = Platform.isAndroid
        ? 'Для начала работы укажите путь к игре или воспользуйтесь автопоиском. '
            'На Android сначала запустите Shizuku и разрешите доступ лаунчеру.'
        : 'Для начала работы укажите путь к игре или воспользуйтесь автопоиском.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              size: 16,
              color: Colors.white54,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF7B52F4).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFFB9A4FF), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowStartButton extends StatelessWidget {
  const _GlowStartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B52F4).withValues(alpha: 0.5),
            blurRadius: 22,
            spreadRadius: 0.5,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7B52F4),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Понятно, начать!',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

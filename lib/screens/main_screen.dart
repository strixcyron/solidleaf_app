// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../config/app_constants.dart';
import '../controllers/launcher_controller.dart';
import '../telegram_auth_service.dart';
import '../widgets/mini_player.dart';
import 'gift_codes_page.dart';
import 'login_screen.dart' hide telegramUrl;

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final ScrollController _logScrollController = ScrollController();

  Future<void> _openExternalLink(String url) async {
    final uri = Uri.parse(url);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted && messenger != null) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось открыть ссылку: $url')),
      );
    }
  }

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

  Future<void> _runInstallFlow() async {
    final controller = context.read<LauncherController>();

    if (!mounted) return;

    try {
      await controller.installOrUpdate();
      if (mounted) {
        final src = controller.lastInstallSource;
        if (src != null) {
          final tgt = controller.lastInstallTarget ?? '';
          final count = controller.lastInstallFileCount;
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text(
                'Установка успешно завершена',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              content: Text(
                'Откуда: $src\nКуда: $tgt\nСкопировано файлов: $count',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('ОК'),
                ),
              ],
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _runArtInstallFlow() async {
    final controller = context.read<LauncherController>();

    if (!mounted) return;

    try {
      await controller.installArtPack();
      if (mounted) {
        final src = controller.lastInstallSource;
        if (src != null) {
          final tgt = controller.lastInstallTarget ?? '';
          final count = controller.lastInstallFileCount;
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text(
                'Текстуры установлены',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              content: Text(
                'Откуда: $src\nКуда: $tgt\nСкопировано файлов: $count',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('ОК'),
                ),
              ],
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _showInstallChoiceDialog(LauncherController controller) async {
    if (!mounted) return;
    final choice = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Выбор установки',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Выберите, что вы хотите установить:',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop('text'),
              child: const Text('Русификация текста'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop('art'),
              child: const Text('Русификация текстур'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (choice == null) return;

    if (choice == 'text') {
      await _runInstallFlow();
    } else if (choice == 'art') {
      await _runArtInstallFlow();
    }
  }

  Future<void> _showProjectInfoDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'SolidLeaf | Reverse: 1999 Localization',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        content: Text(
          'Фанатский проект локализации.\n\n'
          'Цель — сделать комфортный и удобный лаунчер для установки и обновления русификатора, '
          'сохраняя удобство для игроков и простоту для поддержки проекта.',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _openGiftCodesPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const GiftCodesPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  /// Compact banner showing the current Telegram account state ("Премиум
  /// доступ" / "Обычный доступ") plus a "Выйти" button. Since the launcher
  /// only reaches [MainScreen] after a successful login (see [AuthGate]),
  /// this is always shown here — it doubles as a reminder of *why* the
  /// texture card may be locked (see [_showPremiumLockDialog]) and as the
  /// only way to end the session.
  Widget _buildAccountStatusBanner(LauncherController controller) {
    final isPremium = controller.isPremium;
    // Gold marks premium (matches _buildPremiumLockBadge's accent color so
    // the two states read as "the same concept"); grey marks a regular,
    // logged-in-but-not-subscribed account.
    final color = isPremium ? const Color(0xFFC9A227) : Colors.grey.shade500;
    final icon = isPremium
        ? Icons.workspace_premium_rounded
        : Icons.person_rounded;
    final label = isPremium ? 'Премиум доступ' : 'Обычный доступ';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => _handleLogout(controller),
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Выйти'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  /// Confirms, then clears the stored Telegram JWT and sends the user back
  /// to the mandatory [LoginScreen] (via a fresh [AuthGate]) — consistent
  /// with the "launcher requires login" rule enforced at startup.
  Future<void> _handleLogout(LauncherController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1826),
        title: const Text('Выйти из аккаунта?'),
        content: const Text(
          'Понадобится снова войти через Telegram, чтобы продолжить пользоваться лаунчером.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await controller.telegramAuth.logout();
    await controller.refreshPremiumStatus();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LauncherController>();
    final isAndroidUi = Platform.isAndroid;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.jumpTo(
          _logScrollController.position.maxScrollExtent,
        );
      }
    });

    return Scaffold(
      body: Column(
        children: [
          if (!isAndroidUi)
            SizedBox(
              height: 42,
              child: WindowCaption(
                brightness: controller.isDarkMode
                    ? Brightness.dark
                    : Brightness.light,
                title: Text(
                  'SOLIDLEAF TEAM | Лаунчер русификаций',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          Expanded(
            child: isAndroidUi
                ? _buildAndroidLayout(controller)
                : _buildDesktopLayout(controller),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(LauncherController controller) {
    final isDark = controller.isDarkMode;

    return Row(
      children: [
        Container(
          width: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [const Color(0xFF271C35), const Color(0xFF271E33)]
                  : [const Color(0xFFE3DDD3), const Color(0xFFD6CFC3)],
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 14),
              _buildLauncherIcon(size: 52),
              const SizedBox(height: 16),
              _navButton(
                Icons.info_outline_rounded,
                true,
                onTap: _showProjectInfoDialog,
                tooltip: 'О проекте',
              ),
              _navButton(
                Icons.card_giftcard_rounded,
                false,
                onTap: _openGiftCodesPage,
                tooltip: 'Подарочные коды',
              ),
              _navButton(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                false,
                onTap: controller.toggleTheme,
                tooltip: isDark
                    ? 'Переключить на светлую тему'
                    : 'Переключить на тёмную тему',
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSocialIconButton(
                      assetName: 'boosty_icon.png',
                      icon: Icons.stars_rounded,
                      label: 'Boosty',
                      tooltip: 'Boosty',
                      size: 52,
                      onTap: () => _openExternalLink(boostyUrl),
                    ),
                    const SizedBox(height: 16),
                    _buildSocialIconButton(
                      assetName: 'telegram_icon.png',
                      icon: Icons.send_rounded,
                      label: 'Telegram',
                      tooltip: 'Telegram',
                      size: 52,
                      onTap: () => _openExternalLink(telegramUrl),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 270,
          padding: const EdgeInsets.all(18),
          color: Theme.of(context).cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Библиотека',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 18),
              _buildGameListTile('Reverse: 1999', 'v 3.7.0', isActive: true),

              // Spacer выталкивает все, что под ним, в самый низ контейнера
              const Spacer(),

              // Вывод нашего нового плеера
              const MiniPlayer(),
            ],
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF101018), const Color(0xFF17131F)]
                    : [const Color(0xFFFAF7F0), const Color(0xFFF0EBE0)],
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCoverArt(controller, height: 190),
                      const SizedBox(height: 12),
                      _buildAccountStatusBanner(controller),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary
                                .withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                controller.installPath,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                  fontFamily: 'Consolas',
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              onPressed: controller.selectInstallPath,
                              icon: Icon(
                                Icons.folder_open_rounded,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Компоненты',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildComponentTile(
                        icon: Icons.translate_rounded,
                        title: 'Текстовая локализация',
                        subtitle: 'Перевод сюжета и внутриигровых меню',
                        trailing: _buildVersionBadge(controller),
                      ),
                      const SizedBox(height: 10),
                      _buildComponentTile(
                        icon: Icons.image_rounded,
                        title: 'Графика и текстуры',
                        subtitle: 'Локализация интерфейса и графических файлов',
                        // Locked (dimmed + gold "Недоступно" badge) until the
                        // user has active Telegram-channel premium access.
                        trailing: controller.isPremium
                            ? _buildArtVersionBadge(controller)
                            : _buildPremiumLockBadge(),
                        dimmed: !controller.isPremium,
                        onTap: controller.isPremium
                            ? null
                            : () => _showPremiumLockDialog(controller),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Статус: ${controller.statusText}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (controller.isDownloading)
                              LinearProgressIndicator(
                                value: controller.downloadProgress == 0
                                    ? null
                                    : controller.downloadProgress,
                                minHeight: 8,
                                backgroundColor: Theme.of(context).dividerColor,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildUpdateInfoPanel(controller, height: 130),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 180,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                              width: 1,
                            ),
                          ),
                          child: ListView.builder(
                            controller: _logScrollController,
                            itemCount: controller.logs.length,
                            itemBuilder: (_, index) {
                              return Text(
                                controller.logs[index],
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () async {
                                final choice = await showDialog<String?>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: Theme.of(context)
                                        .cardColor,
                                    title: Text(
                                      'Удалить/восстановить',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color,
                                      ),
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Выберите, что вы хотите удалить из установки:',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.color,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop('text'),
                                          child: const Text(
                                            'Удалить русификатор текста',
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop('art'),
                                          child: const Text(
                                            'Удалить русификатор текстур',
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                          ),
                                          onPressed: () =>
                                              Navigator.of(ctx).pop('all'),
                                          child: const Text(
                                            'Удалить всё',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(null),
                                        child: const Text('Отмена'),
                                      ),
                                    ],
                                  ),
                                );

                                if (!mounted) return;
                                if (choice == null) return;

                                final localContext = context;
                                final messenger = ScaffoldMessenger.maybeOf(
                                  localContext,
                                );
                                final confirmed = await showDialog<bool>(
                                  context: localContext,
                                  builder: (c2) => AlertDialog(
                                    backgroundColor: Theme.of(context)
                                        .cardColor,
                                    title: Text(
                                      'Подтвердите действие',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color,
                                      ),
                                    ),
                                    content: Text(
                                      'Вы уверены, что хотите выполнить действие: ${choice == 'all'
                                          ? 'Удалить всё'
                                          : choice == 'art'
                                          ? 'Удалить текстуры'
                                          : 'Удалить текст'}?',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(c2).pop(false),
                                        child: const Text('Отмена'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.of(c2).pop(true),
                                        child: const Text('Выполнить'),
                                      ),
                                    ],
                                  ),
                                );

                                if (!mounted) return;
                                if (confirmed != true) return;

                                try {
                                  await controller.restoreBackupKind(choice);
                                  if (!mounted || messenger == null) return;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Операция удаления/восстановления завершена',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted || messenger == null) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Ошибка: ${e.toString()}'),
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                'Удалить',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: controller.isDownloading
                                  ? null
                                  : () => _showInstallChoiceDialog(controller),
                              child: Text(
                                controller.hasUpdate
                                    ? 'Обновить'
                                    : 'Установить',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAndroidLayout(LauncherController controller) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'SOLIDLEAF TEAM',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    controller.isDarkMode
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                  ),
                  onPressed: controller.toggleTheme,
                  tooltip: 'Сменить тему',
                ),
                ElevatedButton.icon(
                  onPressed: controller.checkShizukuStatus,
                  icon: const Icon(Icons.security_rounded),
                  label: const Text('Shizuku'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCoverArt(controller, height: 170, showSocialInCorners: true),
            const SizedBox(height: 12),
            _buildAccountStatusBanner(controller),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.isShizukuActive
                        ? 'Статус: Shizuku активен'
                        : 'Статус: Shizuku не активен',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (controller.isDownloading)
                    LinearProgressIndicator(
                      value: controller.downloadProgress == 0
                          ? null
                          : controller.downloadProgress,
                      minHeight: 12,
                      backgroundColor: Theme.of(context).dividerColor,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  const SizedBox(height: 12),
                  Text(
                    controller.statusText,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildComponentTile(
              icon: Icons.translate_rounded,
              title: 'Текстовая локализация',
              subtitle: 'Перевод сюжета и внутриигровых меню',
              trailing: _buildVersionBadge(controller),
            ),
            const SizedBox(height: 10),
            _buildComponentTile(
              icon: Icons.image_rounded,
              title: 'Графика и текстуры',
              subtitle: 'Локализация интерфейса и графических файлов',
              // Locked (dimmed + gold "Недоступно" badge) until the user
              // has active Telegram-channel premium access.
              trailing: controller.isPremium
                  ? _buildArtVersionBadge(controller)
                  : _buildPremiumLockBadge(),
              dimmed: !controller.isPremium,
              onTap: controller.isPremium
                  ? null
                  : () => _showPremiumLockDialog(controller),
            ),
            const SizedBox(height: 18),
            _buildUpdateInfoPanel(controller, height: 140),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final choice = await showDialog<String?>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: Theme.of(context).cardColor,
                          title: Text(
                            'Удалить/восстановить',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color,
                            ),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Выберите, что вы хотите удалить из установки:',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => Navigator.of(ctx).pop('text'),
                                child: const Text('Удалить русификатор текста'),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () => Navigator.of(ctx).pop('art'),
                                child: const Text(
                                  'Удалить русификатор текстур',
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                ),
                                onPressed: () => Navigator.of(ctx).pop('all'),
                                child: const Text(
                                  'Удалить всё',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(null),
                              child: const Text('Отмена'),
                            ),
                          ],
                        ),
                      );

                      if (!mounted) return;
                      if (choice == null) return;

                      final messenger = ScaffoldMessenger.maybeOf(context);
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (c2) => AlertDialog(
                          backgroundColor: Theme.of(context).cardColor,
                          title: Text(
                            'Подтвердите действие',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color,
                            ),
                          ),
                          content: Text(
                            'Вы уверены, что хотите выполнить действие: ${choice == 'all'
                                ? 'Удалить всё'
                                : choice == 'art'
                                ? 'Удалить текстуры'
                                : 'Удалить текст'}?',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(c2).pop(false),
                              child: const Text('Отмена'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(c2).pop(true),
                              child: const Text('Выполнить'),
                            ),
                          ],
                        ),
                      );

                      if (!mounted) return;
                      if (confirmed != true) return;

                      try {
                        await controller.restoreBackupKind(choice);
                        if (!mounted || messenger == null) return;
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Операция удаления/восстановления завершена',
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!mounted || messenger == null) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text('Ошибка: ${e.toString()}')),
                        );
                      }
                    },
                    child: Text(
                      'Удалить',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: controller.isDownloading
                        ? null
                        : () => _showInstallChoiceDialog(controller),
                    child: Text(
                      controller.hasUpdate ? 'Обновить' : 'Установить',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverArt(
    LauncherController controller, {
    double height = 180,
    bool showSocialInCorners = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/cover.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: controller.isDarkMode
                        ? [const Color(0xFF3A2B6E), const Color(0xFF1B1430)]
                        : [const Color(0xFF8C6D3B), const Color(0xFF4A351A)],
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.78),
                  ],
                  stops: const [0.35, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reverse: 1999',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Полная русификация (текст, интерфейс и графика)',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  (controller.hasUpdate || controller.hasArtUpdate)
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFA726)
                                .withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFFFA726),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.update_rounded,
                                color: Color(0xFFFFA726),
                                size: 14,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Доступно обновление',
                                style: TextStyle(
                                  color: Color(0xFFFFA726),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildVersionBadge(controller),
                ],
              ),
            ),
            if (showSocialInCorners)
              Positioned(
                top: 10,
                right: 10,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildSocialIconButton(
                      assetName: 'boosty_icon.png',
                      icon: Icons.stars_rounded,
                      label: 'Boosty',
                      tooltip: 'Boosty',
                      size: 32,
                      onTap: () => _openExternalLink(boostyUrl),
                    ),
                    const SizedBox(height: 8),
                    _buildSocialIconButton(
                      assetName: 'telegram_icon.png',
                      icon: Icons.send_rounded,
                      label: 'Telegram',
                      tooltip: 'Telegram',
                      size: 32,
                      onTap: () => _openExternalLink(telegramUrl),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLauncherIcon({double size = 36}) {
    final glowColor = Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).cardColor,
            Theme.of(context).scaffoldBackgroundColor,
          ],
        ),
        border: Border.all(color: glowColor.withValues(alpha: 0.9), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.36),
            blurRadius: 18,
            spreadRadius: 1.5,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/launcher_icon.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [glowColor, Theme.of(context).cardColor],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.white,
                  size: size * 0.58,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIconButton({
    required String assetName,
    required IconData icon,
    required String label,
    required String tooltip,
    double size = 20,
    required VoidCallback onTap,
  }) {
    final radius = size / 4;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white24),
          ),
          alignment: Alignment.center,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.asset(
              'assets/images/$assetName',
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                if (label == 'Boosty') {
                  return const Text(
                    'P',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }
                return Icon(icon, color: Colors.white, size: size * 0.52);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateInfoPanel(
    LauncherController controller, {
    double height = 130,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Информация об обновлении',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: height,
            child: SingleChildScrollView(
              child: Text(
                controller.changelog.isEmpty
                    ? 'Список изменений пока недоступен.'
                    : controller.changelog,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionBadge(LauncherController controller) {
    final notInstalled = controller.currentVersion == 'v0.0.0';
    final Color color;
    final String label;
    final IconData icon;
    if (notInstalled) {
      color = Colors.grey.shade500;
      label = 'Не установлено';
      icon = Icons.remove_circle_outline_rounded;
    } else if (controller.hasUpdate) {
      color = const Color(0xFFD97706);
      label = 'Обновление ${controller.remoteVersion}';
      icon = Icons.upgrade_rounded;
    } else {
      color = const Color(0xFF2E7D32);
      label = controller.currentVersion;
      icon = Icons.check_circle_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtVersionBadge(LauncherController controller) {
    final notInstalled = controller.currentArtVersion == 'v0.0.0';
    final Color color;
    final String label;
    final IconData icon;
    if (notInstalled) {
      color = Colors.grey.shade500;
      label = 'Не установлено';
      icon = Icons.remove_circle_outline_rounded;
    } else if (controller.hasArtUpdate) {
      color = const Color(0xFFD97706);
      label = 'Обновление ${controller.remoteArtVersion}';
      icon = Icons.upgrade_rounded;
    } else {
      color = const Color(0xFF2E7D32);
      label = controller.currentArtVersion;
      icon = Icons.check_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// Gold "locked" badge shown instead of [_buildArtVersionBadge] on the
  /// "Графика и текстуры" card when the user doesn't have active premium
  /// (Telegram channel) access. Gold was chosen (rather than plain grey) so
  /// it reads as "premium/PRO feature" instead of a generic disabled state.
  Widget _buildPremiumLockBadge() {
    const color = Color(0xFFC9A227); // gold accent for the "PRO" lock state
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, color: color, size: 14),
          SizedBox(width: 6),
          Text(
            'Недоступно',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// Shown when a locked "Графика и текстуры" card is tapped: explains that
  /// texture packs require Telegram channel membership and offers a way to
  /// join the channel or retry the login (e.g. after the JWT expired).
  Future<void> _showPremiumLockDialog(LauncherController controller) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1826),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: Color(0xFFC9A227)),
            SizedBox(width: 8),
            Text('Доступ ограничен'),
          ],
        ),
        content: const Text(
          'Графическая локализация доступна только участникам нашего приватного премиум-канала. '
          'Присоединитесь к каналу, а затем повторно войдите через Telegram, чтобы разблокировать установку текстур.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final opened = await launchUrl(
                Uri.parse(premiumChannelUrl),
                mode: LaunchMode.externalApplication,
              );
              if (!opened && mounted && messenger != null) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Не удалось открыть ссылку: $premiumChannelUrl'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.diamond_rounded, size: 16),
            label: const Text('Присоединиться к премиум-каналу'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _retryTelegramLogin(controller);
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Проверить доступ повторно'),
          ),
        ],
      ),
    );
  }

  /// Re-runs the Telegram login flow inline (without leaving the main
  /// screen) and refreshes [LauncherController.isPremium] on success. Used
  /// by the locked-card dialog so an expired/missing session can be renewed
  /// without restarting the whole app.
  Future<void> _retryTelegramLogin(LauncherController controller) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final success = await controller.telegramAuth.loginWithTelegram();
      if (!mounted) return;
      if (success) {
        await controller.refreshPremiumStatus();
        if (controller.isPremium) {
          await controller.checkForArtUpdates();
        }
        if (!mounted || messenger == null) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              controller.isPremium
                  ? 'Вход выполнен. Текстуры разблокированы.'
                  : 'Вход выполнен. Текстовая локализация доступна.',
            ),
          ),
        );
      }
    } on TelegramAuthException catch (e) {
      if (!mounted || messenger == null) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted || messenger == null) return;
      messenger.showSnackBar(SnackBar(content: Text('Ошибка входа: $e')));
    }
  }

  Widget _buildComponentTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    bool dimmed = false,
    VoidCallback? onTap,
  }) {
    final content = Opacity(
      // Dimming (opacity 0.55) is the visual cue for a component the user
      // can't access yet — currently used for the locked "Графика и
      // текстуры" card when the user has no active premium (Telegram) access.
      opacity: dimmed ? 0.55 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );

    if (onTap == null) {
      return content;
    }

    // Wrap in a tappable surface only when the caller needs it (e.g. the
    // locked texture card opens an explanation dialog on tap).
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: content,
      ),
    );
  }

  Widget _buildGameListTile(
    String title,
    String version, {
    required bool isActive,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.gamepad_rounded,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                Text(
                  version,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isActive)
            Icon(
              Icons.check_circle_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 18,
            ),
        ],
      ),
    );
  }

  Widget _navButton(
    IconData icon,
    bool active, {
    VoidCallback? onTap,
    String tooltip = '',
  }) {
    final button = Container(
      width: 52,
      height: 52,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: IconButton(
        onPressed: onTap ?? () {},
        icon: Icon(
          icon,
          color: active
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
    );

    if (tooltip.isEmpty) {
      return button;
    }

    return Tooltip(message: tooltip, child: button);
  }
}

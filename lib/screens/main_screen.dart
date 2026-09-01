// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../config/app_constants.dart';
import '../controllers/launcher_controller.dart';
import '../telegram_auth_service.dart';
import '../widgets/effects/animated_status_badge.dart';
import '../widgets/effects/arcane_hover_border.dart';
import '../widgets/effects/confetti_burst.dart';
import '../widgets/effects/epoch_progress_bar.dart';
import '../widgets/effects/magnetic_hover.dart';
import '../widgets/effects/rain_glass_overlay.dart';
import '../widgets/effects/staggered_fade_in.dart';
import '../widgets/mini_player.dart';
import 'gift_codes_page.dart';
import 'login_screen.dart' hide telegramUrl;

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _LibraryGame {
  const _LibraryGame({
    required this.title,
    required this.iconAssets,
  });

  final String title;
  final List<String> iconAssets;
}

const _libraryGames = [
  _LibraryGame(
    title: 'Reverse: 1999',
    iconAssets: [
      'assets/images/game_icon.jpg',
      'assets/images/cover.jpg',
      'assets/images/launcher_icon.png',
    ],
  ),
];

class _MainScreenState extends State<MainScreen> {
  final ScrollController _mainScrollController = ScrollController();
  bool _ctaHighlight = false;

  @override
  void dispose() {
    _mainScrollController.dispose();
    super.dispose();
  }

  Future<void> _focusGameInMainPanel(LauncherController controller) async {
    if (_mainScrollController.hasClients) {
      await _mainScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
    if (!mounted) return;

    setState(() => _ctaHighlight = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      setState(() => _ctaHighlight = false);
    }

    if (!mounted) return;
    if (_primaryActionEnabled(controller)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Нажмите «Установить» или «Обновить» справа'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
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

  Future<void> _runInstallFlow() async {
    final controller = context.read<LauncherController>();

    if (!mounted) return;

    try {
      await controller.installOrUpdate();
      if (mounted) {
        final src = controller.lastInstallSource;
        if (src != null) {
          await showConfettiBurst(context);
          if (!mounted) return;
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
          await showConfettiBurst(context);
          if (!mounted) return;
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

  Future<void> _showChangelogDialog(LauncherController controller) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Что нового',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Text(
              controller.changelog.isEmpty
                  ? 'Список изменений пока недоступен.'
                  : controller.changelog,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 13,
                height: 1.45,
              ),
            ),
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

  String _primaryActionLabel(LauncherController controller) {
    if (controller.isDownloading) {
      final pct = (controller.downloadProgress * 100).toStringAsFixed(0);
      return 'Загрузка $pct%';
    }
    if (controller.hasUpdate || controller.hasArtUpdate) {
      return 'Обновить';
    }
    if (controller.currentVersion == 'v0.0.0') {
      return 'Установить';
    }
    return 'Установлено';
  }

  bool _primaryActionEnabled(LauncherController controller) {
    if (controller.isDownloading) return false;
    if (controller.hasUpdate ||
        controller.hasArtUpdate ||
        controller.currentVersion == 'v0.0.0') {
      return true;
    }
    return false;
  }

  Widget _buildHeroSection(
    LauncherController controller, {
    bool showSocialInCorners = false,
    bool highlightCta = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCoverArt(
          controller,
          height: 200,
          showSocialInCorners: showSocialInCorners,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: MagneticHover(
                child: ArcaneHoverBorder(
                  borderRadius: 12,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: highlightCta
                          ? [
                              BoxShadow(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.55),
                                blurRadius: 18,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        disabledBackgroundColor:
                            const Color(0xFF2E7D32).withValues(alpha: 0.35),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _primaryActionEnabled(controller)
                          ? () => _showInstallChoiceDialog(controller)
                          : null,
                      icon: Icon(
                        controller.isDownloading
                            ? Icons.downloading_rounded
                            : controller.hasUpdate || controller.hasArtUpdate
                                ? Icons.system_update_alt_rounded
                                : Icons.download_rounded,
                        color: Colors.white,
                      ),
                      label: Text(
                        _primaryActionLabel(controller),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            MagneticHover(
              child: Tooltip(
                message: 'Список изменений последней версии русификатора',
                child: OutlinedButton(
                  onPressed: () => _showChangelogDialog(controller),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Что нового?'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsCard(LauncherController controller) {
    final isPremium = controller.isPremium;
    final isAndroidUi = Platform.isAndroid;
    final accountColor =
        isPremium ? const Color(0xFFC9A227) : Colors.grey.shade500;
    final accountIcon = isPremium
        ? Icons.workspace_premium_rounded
        : Icons.person_rounded;
    final accountLabel =
        isPremium ? 'Премиум доступ' : 'Обычный доступ';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.9),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(accountIcon, color: accountColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  accountLabel,
                  style: TextStyle(
                    color: accountColor,
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
                  foregroundColor:
                      Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
          if (!isAndroidUi) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(
                height: 1,
                color: Theme.of(context).dividerColor,
              ),
            ),
            Row(
              children: [
                Icon(
                  controller.isInstallPathValid
                      ? Icons.folder_outlined
                      : Icons.folder_off_outlined,
                  size: 18,
                  color: controller.isInstallPathValid
                      ? Theme.of(context).textTheme.bodySmall?.color
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    controller.installPath,
                    style: TextStyle(
                      color: controller.isInstallPathValid
                          ? Theme.of(context).textTheme.bodySmall?.color
                          : Theme.of(context).colorScheme.error,
                      fontFamily: 'Consolas',
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: controller.detectInstallPath,
                  icon: Icon(
                    Icons.search_rounded,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  tooltip: 'Найти игру автоматически',
                ),
                IconButton(
                  onPressed: controller.selectInstallPath,
                  icon: Icon(
                    Icons.folder_open_rounded,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  tooltip: 'Выбрать папку вручную',
                ),
              ],
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(
              height: 1,
              color: Theme.of(context).dividerColor,
            ),
          ),
          Text(
            controller.statusText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRemoveBackupDialog(LauncherController controller) async {
    final choice = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Удалить/восстановить',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Выберите, что вы хотите удалить из установки:',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
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
              child: const Text('Удалить русификатор текстур'),
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
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите выполнить действие: ${choice == 'all'
              ? 'Удалить всё'
              : choice == 'art'
                  ? 'Удалить текстуры'
                  : 'Удалить текст'}?',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color,
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
          content: Text('Операция удаления/восстановления завершена'),
        ),
      );
    } catch (e) {
      if (!mounted || messenger == null) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Ошибка: ${e.toString()}')),
      );
    }
  }

  /// Confirms, then clears the stored Telegram JWT and sends the user back
  /// to the mandatory [LoginScreen] (via a fresh [AuthGate]) — consistent
  /// with the "launcher requires login" rule enforced at startup.
  Future<void> _handleLogout(LauncherController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Выйти из аккаунта?',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        content: Text(
          'Понадобится снова войти через Telegram, чтобы продолжить пользоваться лаунчером.',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
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
              Row(
                children: [
                  Text(
                    'Библиотека',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_libraryGames.length} ${_libraryGames.length == 1 ? 'игра' : 'игры'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _libraryGames.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: StaggeredFadeIn(
                    index: i,
                    child: _buildGameListTile(controller, _libraryGames[i]),
                  ),
                ),
              _buildLibraryActivityCard(controller),
              const Spacer(),
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
                controller: _mainScrollController,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroSection(
                        controller,
                        highlightCta: _ctaHighlight,
                      ),
                      const SizedBox(height: 18),
                      _buildSettingsCard(controller),
                      const SizedBox(height: 20),
                      Text(
                        'Компоненты',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildComponentTile(
                        icon: Icons.translate_rounded,
                        title: 'Текстовая локализация',
                        subtitle: 'Перевод сюжета и внутриигровых меню',
                        trailing: _buildVersionBadge(controller),
                        showDownloadProgress: controller.isDownloadingText,
                        downloadProgress: controller.downloadProgress,
                      ),
                      const SizedBox(height: 10),
                      _buildComponentTile(
                        icon: Icons.image_rounded,
                        title: 'Графика и текстуры',
                        subtitle: 'Локализация интерфейса и графических файлов',
                        trailing: controller.isPremium
                            ? _buildArtVersionBadge(controller)
                            : _buildPremiumLockBadge(),
                        dimmed: !controller.isPremium,
                        premiumLocked: !controller.isPremium,
                        showDownloadProgress: controller.isDownloadingArt,
                        downloadProgress: controller.downloadProgress,
                        onTap: controller.isPremium
                            ? null
                            : () => _showPremiumLockDialog(controller),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () =>
                              _showRemoveBackupDialog(controller),
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: const Text('Удалить русификатор'),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).textTheme.bodySmall?.color,
                          ),
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
            _buildHeroSection(
              controller,
              showSocialInCorners: true,
              highlightCta: _ctaHighlight,
            ),
            const SizedBox(height: 16),
            _buildSettingsCard(controller),
            if (!controller.isShizukuActive)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Shizuku не активен — установка на Android невозможна',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Компоненты',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 12),
            _buildComponentTile(
              icon: Icons.translate_rounded,
              title: 'Текстовая локализация',
              subtitle: 'Перевод сюжета и внутриигровых меню',
              trailing: _buildVersionBadge(controller),
              showDownloadProgress: controller.isDownloadingText,
              downloadProgress: controller.downloadProgress,
            ),
            const SizedBox(height: 10),
            _buildComponentTile(
              icon: Icons.image_rounded,
              title: 'Графика и текстуры',
              subtitle: 'Локализация интерфейса и графических файлов',
              trailing: controller.isPremium
                  ? _buildArtVersionBadge(controller)
                  : _buildPremiumLockBadge(),
              dimmed: !controller.isPremium,
              premiumLocked: !controller.isPremium,
              showDownloadProgress: controller.isDownloadingArt,
              downloadProgress: controller.downloadProgress,
              onTap: controller.isPremium
                  ? null
                  : () => _showPremiumLockDialog(controller),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => _showRemoveBackupDialog(controller),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Удалить русификатор'),
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
            const Positioned.fill(child: RainGlassOverlay()),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.45, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reverse: 1999',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Полная русификация (текст, интерфейс и графика)',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
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

  Widget _buildVersionBadge(LauncherController controller) {
    final notInstalled = controller.currentVersion == 'v0.0.0';
    if (notInstalled) {
      return AnimatedStatusBadge(
        label: 'Не установлено',
        color: Colors.grey.shade500,
        icon: Icons.remove_circle_outline_rounded,
        kind: StatusBadgeKind.neutral,
      );
    }
    if (controller.hasUpdate) {
      return AnimatedStatusBadge(
        label: 'Обновление ${controller.remoteVersion}',
        color: const Color(0xFFD97706),
        icon: Icons.upgrade_rounded,
        kind: StatusBadgeKind.updateAvailable,
      );
    }
    return AnimatedStatusBadge(
      label: controller.displayCurrentVersion,
      color: const Color(0xFF2E7D32),
      icon: Icons.check_circle_rounded,
      kind: StatusBadgeKind.installed,
    );
  }

  Widget _buildArtVersionBadge(LauncherController controller) {
    final notInstalled = controller.currentArtVersion == 'v0.0.0';
    if (notInstalled) {
      return AnimatedStatusBadge(
        label: 'Не установлено',
        color: Colors.grey.shade500,
        icon: Icons.remove_circle_outline_rounded,
        kind: StatusBadgeKind.neutral,
        compact: true,
      );
    }
    if (controller.hasArtUpdate) {
      return AnimatedStatusBadge(
        label: 'Обновление ${controller.remoteArtVersion}',
        color: const Color(0xFFD97706),
        icon: Icons.upgrade_rounded,
        kind: StatusBadgeKind.updateAvailable,
        compact: true,
      );
    }
    return AnimatedStatusBadge(
      label: controller.currentArtVersion,
      color: const Color(0xFF2E7D32),
      icon: Icons.check_circle_rounded,
      kind: StatusBadgeKind.installed,
      compact: true,
    );
  }

  /// Gold "locked" badge shown instead of [_buildArtVersionBadge] on the
  /// "Графика и текстуры" card when the user doesn't have active premium
  /// (Telegram channel) access. Gold was chosen (rather than plain grey) so
  /// it reads as "premium/PRO feature" instead of a generic disabled state.
  Widget _buildPremiumLockBadge() {
    const color = Color(0xFFC9A227);
    return Tooltip(
      message: 'Доступно участникам премиум-канала SOLIDLEAF TEAM',
      child: Container(
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
              'Только Premium',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
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
        backgroundColor: Theme.of(context).cardColor,
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Color(0xFFC9A227)),
            const SizedBox(width: 8),
            Text(
              'Доступ ограничен',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
        content: Text(
          'Графическая локализация доступна только участникам нашего приватного премиум-канала. '
          'Присоединитесь к каналу, а затем повторно войдите через Telegram, чтобы разблокировать установку текстур.',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
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
    bool premiumLocked = false,
    bool showDownloadProgress = false,
    double downloadProgress = 0,
    VoidCallback? onTap,
  }) {
    final borderColor = premiumLocked
        ? const Color(0xFFC9A227).withValues(alpha: 0.45)
        : Theme.of(context).dividerColor;

    final content = Opacity(
      opacity: dimmed ? 0.72 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color:
                              Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            if (showDownloadProgress) ...[
              const SizedBox(height: 12),
              EpochProgressBar(
                progress: downloadProgress,
                indeterminate: downloadProgress == 0,
                height: 5,
              ),
            ],
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

  Widget _buildLibraryActivityCard(LauncherController controller) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.history_rounded,
            size: 16,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Последняя активность',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  controller.statusText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameIcon(List<String> assets, {double size = 52}) {
    Widget imageAt(int index) {
      if (index >= assets.length) {
        return ColoredBox(
          color: Theme.of(context).dividerColor,
          child: Icon(
            Icons.gamepad_rounded,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        );
      }

      return Image.asset(
        assets[index],
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => imageAt(index + 1),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: imageAt(0),
      ),
    );
  }

  Widget _buildGameListTile(LauncherController controller, _LibraryGame game) {
    final installed = controller.currentVersion != 'v0.0.0';
    final versionLabel = installed
        ? controller.currentVersion
        : 'Русификатор не установлен';
    final statusColor = controller.hasUpdate
        ? const Color(0xFFD97706)
        : installed
            ? const Color(0xFF2E7D32)
            : Theme.of(context).textTheme.bodySmall?.color;

    return ArcaneHoverBorder(
      borderRadius: 14,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _focusGameInMainPanel(controller),
          child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.55),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              _buildGameIcon(game.iconAssets),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      versionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (controller.hasUpdate) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Доступно ${controller.remoteVersion}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFD97706),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                controller.hasUpdate
                    ? Icons.system_update_alt_rounded
                    : Icons.chevron_right_rounded,
                color: statusColor,
                size: 18,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _navButton(
    IconData icon,
    bool active, {
    VoidCallback? onTap,
    String tooltip = '',
  }) {
    final button = MagneticHover(
      child: Container(
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
      ),
    );

    if (tooltip.isEmpty) {
      return button;
    }

    return Tooltip(message: tooltip, child: button);
  }
}

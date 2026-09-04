// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../config/app_constants.dart';
import '../controllers/launcher_controller.dart';
import '../data/animated_covers.dart';
import '../telegram_auth_service.dart';
import '../utils/install_errors.dart';
import '../widgets/animated_cover_view.dart';
import '../widgets/effects/animated_status_badge.dart';
import '../widgets/effects/arcane_hover_border.dart';
import '../widgets/effects/confetti_burst.dart';
import '../widgets/effects/epoch_progress_bar.dart';
import '../widgets/effects/magnetic_hover.dart';
import '../widgets/effects/rain_glass_overlay.dart';
import '../widgets/effects/staggered_fade_in.dart';
import '../widgets/launcher_version_badge.dart';
import '../widgets/mini_player.dart';
import '../widgets/remove_localization_dialog.dart';
import '../widgets/welcome_dialog.dart';
import 'about_project_page.dart';
import 'settings_page.dart';
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

class _MainScreenState extends State<MainScreen>
    with WindowListener, WidgetsBindingObserver {
  final ScrollController _mainScrollController = ScrollController();
  bool _ctaHighlight = false;
  bool _welcomeHandled = false;
  LauncherController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrapMainScreen();
    });
  }

  /// Загрузка контроллера и Welcome-диалог при первом запуске.
  Future<void> _bootstrapMainScreen() async {
    final controller = context.read<LauncherController>();
    try {
      await controller.initialize();
    } catch (_) {
      // Welcome всё равно показываем — экран уже нарисован.
    }
    if (!mounted) return;
    await _maybeShowWelcome(controller);
  }

  Future<void> _maybeShowWelcome(LauncherController controller) async {
    if (_welcomeHandled) return;
    _welcomeHandled = true;
    final firstLaunch = await controller.isFirstLaunch();
    if (!firstLaunch || !mounted) return;
    await showWelcomeOnboardingDialog(
      context,
      animate: controller.animationsEnabled,
    );
    await controller.markFirstLaunchSeen();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = context.read<LauncherController>();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    _controller?.stopGameProcessWatch();
    _mainScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      controller.onAppPaused();
      controller.pauseGameProcessWatch();
    } else if (state == AppLifecycleState.resumed) {
      controller.onAppResumed();
      controller.resumeGameProcessWatch();
    }
  }

  @override
  void onWindowMinimize() {
    _controller?.pauseGameProcessWatch();
  }

  @override
  void onWindowRestore() {
    _controller?.resumeGameProcessWatch();
  }

  @override
  void onWindowClose() {
    _controller?.stopGameProcessWatch();
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

  /// Пошаговая инструкция по настройке Shizuku на Android. Открывается по чипу
  /// «Shizuku» в шапке и по кнопке в баннере, когда Shizuku не активен.
  Future<void> _showShizukuGuide(LauncherController controller) async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        // Consumer, чтобы статус в шапке инструкции обновлялся после
        // нажатия «Проверить снова» без закрытия листа.
        return Consumer<LauncherController>(
          builder: (ctx, ctrl, _) {
            final active = ctrl.isShizukuActive;
            final textColor = Theme.of(ctx).textTheme.bodyMedium?.color;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      _infoDialogTitle(
                        Icons.security_rounded,
                        'Настройка Shizuku',
                      ),
                      const SizedBox(height: 12),
                      // Текущий статус Shizuku.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: (active ? Colors.green : scheme.error)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              active
                                  ? Icons.check_circle_rounded
                                  : Icons.error_outline_rounded,
                              color: active ? Colors.green : scheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                active
                                    ? 'Shizuku активен — можно устанавливать локализацию.'
                                    : 'Shizuku не активен. Следуйте шагам ниже.',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Shizuku нужен, чтобы лаунчер мог копировать файлы '
                        'русификатора в защищённую папку Android/data — без '
                        'root и без подключения к ПК.',
                        style: TextStyle(
                          color: textColor?.withValues(alpha: 0.8),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _shizukuStep(
                        1,
                        'Установите приложение Shizuku',
                        'Нажмите «Скачать Shizuku» ниже и установите APK '
                            '(или из Google Play / F-Droid).',
                      ),
                      _shizukuStep(
                        2,
                        'Включите «Параметры разработчика»',
                        'Настройки → «О телефоне» → нажмите 7 раз по '
                            '«Номер сборки».',
                      ),
                      _shizukuStep(
                        3,
                        'Включите «Беспроводную отладку»',
                        'Настройки → «Для разработчиков» → включите '
                            '«Беспроводная отладка».',
                      ),
                      _shizukuStep(
                        4,
                        'Запустите Shizuku без ПК',
                        'Откройте Shizuku → «Запустить через беспроводную '
                            'отладку» и следуйте подсказкам (сопряжение по коду).',
                      ),
                      _shizukuStep(
                        5,
                        'Выдайте доступ лаунчеру',
                        'При первом запросе разрешите этому приложению доступ '
                            'в Shizuku.',
                      ),
                      _shizukuStep(
                        6,
                        'Проверьте статус',
                        'Вернитесь сюда и нажмите «Проверить снова».',
                        last: true,
                      ),
                      const SizedBox(height: 8),
                      _fullWidthDialogButton(
                        icon: Icons.download_rounded,
                        label: 'Скачать Shizuku',
                        onPressed: () => _openExternalLink(shizukuDownloadUrl),
                      ),
                      const SizedBox(height: 8),
                      _fullWidthDialogButton(
                        icon: Icons.menu_book_rounded,
                        label: 'Подробная инструкция (сайт)',
                        onPressed: () => _openExternalLink(shizukuGuideUrl),
                      ),
                      const SizedBox(height: 8),
                      _fullWidthDialogButton(
                        icon: Icons.refresh_rounded,
                        label: 'Проверить снова',
                        filled: true,
                        onPressed: () async {
                          await ctrl.checkShizukuStatus();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Один пронумерованный шаг инструкции по Shizuku.
  Widget _shizukuStep(
    int number,
    String title,
    String subtitle, {
    bool last = false,
  }) {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 16 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF6C4BF6),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
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
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: textColor?.withValues(alpha: 0.75),
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runInstallFlow() async {
    final controller = context.read<LauncherController>();

    if (!mounted) return;

    try {
      await controller.installOrUpdate();
      if (!mounted) return;

      if (controller.lastUserError != null) {
        await _showInstallErrorDialog(
          controller.lastUserFacingError ??
              describeInstallErrorDetailed(controller.lastUserError!),
        );
        return;
      }

      if (controller.lastInstallSource != null) {
        await showConfettiBurst(context);
        if (!mounted) return;
        _showSuccessSnackBar('Готово 🎉  Текстовая локализация установлена');
      }
    } catch (e) {
      if (!mounted) return;
      await _showInstallErrorDialog(describeInstallErrorDetailed(e));
    }
  }

  Future<void> _runArtInstallFlow() async {
    final controller = context.read<LauncherController>();

    if (!mounted) return;

    try {
      await controller.installArtPack();
      if (!mounted) return;

      if (controller.lastUserError != null) {
        await _showInstallErrorDialog(
          controller.lastUserFacingError ??
              describeInstallErrorDetailed(controller.lastUserError!),
        );
        return;
      }

      if (controller.lastInstallSource != null) {
        await showConfettiBurst(context);
        if (!mounted) return;
        _showSuccessSnackBar('Готово 🎉  Графика и текстуры установлены');
      }
    } catch (e) {
      if (!mounted) return;
      await _showInstallErrorDialog(describeInstallErrorDetailed(e));
    }
  }

  void _showSuccessSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        backgroundColor: const Color(0xFF1B4332),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF95D5B2)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Диалог ошибки установки — без сырых Exception / стеков.
  Future<void> _showInstallErrorDialog(UserFacingError error) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error.title,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error.summary,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                height: 1.4,
              ),
            ),
            if (error.steps.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Что сделать',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < error.steps.length; i++) ...[
                if (i > 0) const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error.steps[i],
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  Future<void> _showInstallChoiceDialog(LauncherController controller) async {
    if (!mounted) return;

    final textInstalled = controller.isTextInstalled;
    final artInstalled = controller.isTexturesInstalled;
    // Уже стоящие и актуальные компоненты в диалоге недоступны.
    final textLocked = textInstalled && !controller.hasTextUpdate;
    final artLocked = artInstalled && !controller.hasTexturesUpdate;
    final artPremiumLocked = !controller.isPremium;

    var pickText = !textLocked;
    var pickArt = !artLocked && !artPremiumLocked;

    final choice = await showDialog<({bool text, bool art})?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text(
                controller.isNothingInstalled
                    ? 'Выбор установки'
                    : 'Доустановка компонентов',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    controller.isNothingInstalled
                        ? 'Выберите, что установить:'
                        : 'Отметьте компоненты, которые ещё нужно поставить:',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: pickText,
                    onChanged: textLocked
                        ? null
                        : (v) => setLocal(() => pickText = v ?? false),
                    title: Text(
                      textLocked
                          ? 'Текст (уже установлено)'
                          : 'Русификация текста',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: pickArt && !artPremiumLocked,
                    onChanged: (artLocked || artPremiumLocked)
                        ? null
                        : (v) => setLocal(() => pickArt = v ?? false),
                    title: Text(
                      artPremiumLocked
                          ? 'Текстуры (нужен Premium)'
                          : artLocked
                              ? 'Текстуры (уже установлено)'
                              : 'Графика и текстуры',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (!textLocked && !artLocked && !artPremiumLocked)
                    TextButton(
                      onPressed: () => setLocal(() {
                        pickText = true;
                        pickArt = true;
                      }),
                      child: const Text('Выбрать всё'),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: (!pickText && !(pickArt && !artPremiumLocked))
                      ? null
                      : () => Navigator.of(ctx).pop((
                            text: pickText,
                            art: pickArt && !artPremiumLocked,
                          )),
                  child: const Text('Установить'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || choice == null) return;

    if (choice.text) {
      await _runInstallFlow();
      if (!mounted) return;
      if (controller.lastUserError != null) return;
    }
    if (choice.art) {
      await _runArtInstallFlow();
    }
  }

  /// Главная кнопка: приоритет «Обновить» для установленных с апдейтом,
  /// иначе установка / доустановка через диалог.
  Future<void> _handlePrimaryAction(LauncherController controller) async {
    if (controller.hasAnyComponentUpdate) {
      await _runBatchUpdate(controller);
      return;
    }

    if (controller.isNothingInstalled || !controller.isAllInstalled) {
      await _showInstallChoiceDialog(controller);
      return;
    }
    // Всё установлено и актуально — кнопка disabled, сюда не попадаем.
  }

  /// Фоном обновляет только те УСТАНОВЛЕННЫЕ компоненты, где есть новая версия.
  Future<void> _runBatchUpdate(LauncherController controller) async {
    if (!mounted) return;

    final needText = controller.hasTextUpdate;
    final needArt = controller.hasTexturesUpdate && controller.isPremium;

    if (needText) {
      await _runInstallFlow();
      if (!mounted) return;
      if (controller.lastUserError != null) return;
    }

    if (needArt) {
      await _runArtInstallFlow();
    }
  }

  Future<void> _openAboutProjectPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AboutProjectPage(),
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

  Future<void> _openSettingsPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SettingsPage(),
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
    if (controller.hasAnyComponentUpdate) {
      return 'Обновить';
    }
    if (controller.isNothingInstalled) {
      return 'Установить';
    }
    if (!controller.isAllInstalled) {
      if (controller.isTextInstalled && !controller.isTexturesInstalled) {
        return controller.isPremium
            ? 'Установить графику'
            : 'Доустановить компоненты';
      }
      if (!controller.isTextInstalled && controller.isTexturesInstalled) {
        return 'Установить текст';
      }
      return 'Доустановить компоненты';
    }
    return 'Установлено';
  }

  bool _primaryActionEnabled(LauncherController controller) {
    if (controller.isDownloading) return false;
    if (!Platform.isAndroid && !controller.isInstallPathValid) return false;
    if (controller.hasAnyComponentUpdate) return true;
    if (controller.isNothingInstalled || !controller.isAllInstalled) {
      return true;
    }
    return false;
  }

  /// Оранжевый акцент для кнопки «Обновить».
  static const _updateAccent = Color(0xFFD97706);

  Widget _buildHeroSection(
    LauncherController controller, {
    bool showSocialInCorners = false,
    bool showAboutButton = false,
    bool highlightCta = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCoverArt(
          controller,
          height: 200,
          showSocialInCorners: showSocialInCorners,
          showAboutButton: showAboutButton,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Builder(
                builder: (context) {
                  final isUpdateAction = !controller.isDownloading &&
                      controller.hasAnyComponentUpdate;
                  final accent = isUpdateAction
                      ? _updateAccent
                      : Theme.of(context).colorScheme.primary;
                  final enabled = _primaryActionEnabled(controller);

                  return MagneticHover(
                    child: ArcaneHoverBorder(
                      borderRadius: 12,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: enabled &&
                                  (highlightCta || isUpdateAction)
                              ? [
                                  BoxShadow(
                                    color: accent.withValues(
                                      alpha: isUpdateAction ? 0.65 : 0.55,
                                    ),
                                    blurRadius: isUpdateAction ? 22 : 18,
                                    spreadRadius: isUpdateAction ? 2 : 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            disabledBackgroundColor:
                                Colors.grey.shade700.withValues(alpha: 0.45),
                            disabledForegroundColor: Colors.white70,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: enabled
                              ? () => _handlePrimaryAction(controller)
                              : null,
                          icon: Icon(
                            controller.isDownloading
                                ? Icons.downloading_rounded
                                : isUpdateAction
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
                  );
                },
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

  /// Баннер first-run: ждём процесс игры или показываем успех автоопределения.
  Widget _buildGamePathOnboardingBanner(LauncherController controller) {
    final scheme = Theme.of(context).colorScheme;
    final textPrimary = Theme.of(context).textTheme.bodyMedium?.color;
    final textSecondary = Theme.of(context).textTheme.bodySmall?.color;

    if (controller.gamePathJustDetected) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Папка игры определена:\n${controller.installPath}',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: scheme.error, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Путь к игре не найден. Запустите игру один раз через '
                  'официальный ярлык для автоопределения, либо укажите папку вручную.',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          if (controller.isWaitingForGameProcess) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ожидание запуска игры (Reverse1999.exe)...',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Лёгкая тень карточки: работает и в светлой, и в Material You теме.
  List<BoxShadow> _cardShadows(BuildContext context) {
    final shadow = Theme.of(context).colorScheme.shadow;
    return [
      BoxShadow(
        color: shadow.withValues(alpha: 0.10),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
  }

  /// Статус про Shizuku — на Android его показывает чип в шапке, не эта строка.
  bool _isShizukuStatusText(String text) {
    final t = text.trim().toLowerCase();
    return t.startsWith('shizuku');
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
    final showStatus = !(isAndroidUi &&
        _isShizukuStatusText(controller.statusText));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.9),
          width: 1,
        ),
        boxShadow: _cardShadows(context),
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
            Text(
              'Папка игры',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 8),
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
                  onPressed: () async {
                    await controller.selectInstallPath();
                    if (!mounted) return;
                    if (controller.lastUserError != null) {
                      await _showInstallErrorDialog(
                        controller.lastUserFacingError ??
                            describeInstallErrorDetailed(
                              controller.lastUserError!,
                            ),
                      );
                    }
                  },
                  icon: Icon(
                    Icons.folder_open_rounded,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  tooltip: 'Выбрать папку вручную',
                ),
              ],
            ),
            if (!controller.isInstallPathValid ||
                controller.isWaitingForGameProcess ||
                controller.gamePathJustDetected) ...[
              const SizedBox(height: 10),
              _buildGamePathOnboardingBanner(controller),
            ],
          ],
          if (showStatus) ...[
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
                onTap: _openAboutProjectPage,
                tooltip: 'О проекте',
              ),
              _navButton(
                Icons.card_giftcard_rounded,
                false,
                onTap: _openGiftCodesPage,
                tooltip: 'Подарочные коды',
              ),
              _navButton(
                Icons.settings_rounded,
                false,
                onTap: _openSettingsPage,
                tooltip: 'Настройки',
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
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LauncherVersionBadge(compact: true),
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
                      const SizedBox(height: 12),
                      _buildLibraryActivityCard(controller),
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
                      _buildTextLocalizationTile(controller),
                      const SizedBox(height: 10),
                      _buildComponentTile(
                        icon: Icons.image_rounded,
                        title: 'Графика и текстуры',
                        subtitle:
                            'Локализация интерфейса и графических файлов',
                        trailing: controller.isPremium
                            ? _buildArtVersionBadge(controller)
                            : _buildPremiumLockBadge(),
                        dimmed: !controller.isPremium,
                        premiumLocked: !controller.isPremium,
                        showDownloadProgress: controller.isDownloadingArt,
                        downloadProgress: controller.downloadProgress,
                        showRemoveMenu: true,
                        onTap: controller.isPremium
                            ? null
                            : () => _showPremiumLockDialog(controller),
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
    // Нижний inset — чтобы «Удалить» и версия не прятались за навигацией.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final shizukuActive = controller.isShizukuActive;
    final shizukuLabel =
        shizukuActive ? 'Shizuku (активен)' : 'Shizuku (не запущен)';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'SOLIDLEAF',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _ShizukuStatusChip(
                  active: shizukuActive,
                  label: shizukuLabel,
                  onTap: () => _showShizukuGuide(controller),
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
                IconButton(
                  icon: const Icon(Icons.settings_rounded),
                  onPressed: _openSettingsPage,
                  tooltip: 'Настройки',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildHeroSection(
              controller,
              showSocialInCorners: false,
              showAboutButton: true,
              highlightCta: _ctaHighlight,
            ),
            const SizedBox(height: 16),
            _buildSettingsCard(controller),
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
            _buildTextLocalizationTile(controller),
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
            const SizedBox(height: 24),
            Text(
              'Музыка',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 12),
            const MiniPlayer(useCardColor: true, collapsible: true),
            const SizedBox(height: 16),
            const Center(child: LauncherVersionBadge()),
            SizedBox(height: 12 + bottomInset),
          ],
        ),
      ),
    );
  }

  /// Обложка: анимированная (выбранный вариант из assets/video/) при
  /// включённой настройке, иначе — статичная. На Android приоритет у mp4
  /// через video_player, затем откат на webp → gif → статичную jpg.
  Widget _buildCoverImage(LauncherController controller) {
    if (controller.animatedCoverEnabled) {
      final cover = animatedCovers[
          controller.animatedCoverIndex.clamp(0, animatedCovers.length - 1)];
      return AnimatedCoverView(
        cover: cover,
        imageFallback: _animatedImageFallback(controller, cover),
      );
    }
    return _staticCover(controller);
  }

  /// Анимированная обложка без видео: webp → gif → статичная jpg.
  Widget _animatedImageFallback(
    LauncherController controller,
    AnimatedCover cover,
  ) {
    return Image.asset(
      cover.webp,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Image.asset(
        cover.gif,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _staticCover(controller),
      ),
    );
  }

  /// Статичная обложка с градиентным фолбэком, если картинки нет.
  Widget _staticCover(LauncherController controller) {
    return Image.asset(
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
    );
  }

  Widget _buildCoverArt(
    LauncherController controller, {
    double height = 180,
    bool showSocialInCorners = false,
    bool showAboutButton = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCoverImage(controller),
            if (controller.animationsEnabled)
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
                    controller.isPremium
                        ? 'Полная русификация (текст, интерфейс и графика)'
                        : 'Бесплатная версия: перевод сюжета',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (showAboutButton || showSocialInCorners)
              Positioned(
                top: 10,
                left: 10,
                child: _buildAboutCoverButton(),
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
                    const SizedBox(height: 8),
                    _buildCoverIconButton(
                      icon: Icons.settings_rounded,
                      tooltip: 'Настройки',
                      size: 32,
                      onTap: _openSettingsPage,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Круглая кнопка в углу баннера (иконка на полупрозрачном фоне).
  Widget _buildCoverIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    double size = 32,
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
          child: Icon(icon, color: Colors.white, size: size * 0.55),
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

  /// Стеклянная кнопка «О проекте» в левом верхнем углу обложки (Android).
  /// Симметрична соц-иконкам справа и открывает страницу «О проекте».
  Widget _buildAboutCoverButton() {
    return Tooltip(
      message: 'О проекте',
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _openAboutProjectPage,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                SizedBox(width: 6),
                Text(
                  'О проекте',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
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

  /// Заголовок диалога: иконка + текст с переносом, без обрезки на узком экране.
  Widget _infoDialogTitle(IconData icon, String title) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFC9A227)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  /// Кнопка на всю ширину диалога — длинные подписи не вылезают за край.
  Widget _fullWidthDialogButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool filled = false,
  }) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (filled) {
      return ElevatedButton(
        onPressed: onPressed,
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      child: child,
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: _infoDialogTitle(
          Icons.lock_rounded,
          'Доступ ограничен',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Графическая локализация доступна только участникам нашего приватного премиум-канала. '
              'Присоединитесь к каналу, а затем повторно войдите через Telegram, чтобы разблокировать установку текстур.',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            _fullWidthDialogButton(
              icon: Icons.diamond_rounded,
              label: 'Премиум-канал',
              filled: true,
              onPressed: () async {
                Navigator.of(ctx).pop();
                final opened = await launchUrl(
                  Uri.parse(premiumChannelUrl),
                  mode: LaunchMode.externalApplication,
                );
                if (!opened && mounted && messenger != null) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Не удалось открыть ссылку: $premiumChannelUrl',
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            _fullWidthDialogButton(
              icon: Icons.refresh_rounded,
              label: 'Проверить доступ',
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _retryTelegramLogin(controller);
              },
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Отмена'),
            ),
          ],
        ),
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

  /// Карточка текста: у бесплатных — только сюжет и пометка о неполной версии.
  Widget _buildTextLocalizationTile(LauncherController controller) {
    final isFree = !controller.isPremium;
    return _buildComponentTile(
      icon: Icons.translate_rounded,
      title: 'Текстовая локализация',
      subtitle: isFree
          ? 'Перевод сюжета'
          : 'Перевод сюжета и внутриигровых меню',
      trailing: _buildVersionBadge(controller),
      showDownloadProgress: controller.isDownloadingText,
      downloadProgress: controller.downloadProgress,
      footer: isFree ? _buildPartialTextHint() : null,
      showRemoveMenu: !Platform.isAndroid,
      onTap: isFree ? () => _showPartialTextDialog(controller) : null,
    );
  }

  /// Компактная золотая пометка: бесплатный пакет не покрывает меню и UI.
  Widget _buildPartialTextHint() {
    const color = Color(0xFFC9A227);
    return Row(
      children: [
        const Icon(Icons.info_outline_rounded, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Неполная версия. Меню и интерфейс игры — в Premium',
            style: TextStyle(
              color: color.withValues(alpha: 0.95),
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showPartialTextDialog(LauncherController controller) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: _infoDialogTitle(
          Icons.translate_rounded,
          'Неполная локализация',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'В бесплатной версии переведён только сюжет. '
              'Тексты меню, интерфейса и системных окон остаются на английском. '
              'Полная русификация текстовой части доступна с Premium — '
              'после вступления в премиум-канал и повторного входа через Telegram.',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            _fullWidthDialogButton(
              icon: Icons.workspace_premium_rounded,
              label: 'Premium',
              filled: true,
              onPressed: () async {
                Navigator.of(ctx).pop();
                await launchUrl(
                  Uri.parse(premiumChannelUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Понятно'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComponentTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    Widget? footer,
    bool dimmed = false,
    bool premiumLocked = false,
    bool showDownloadProgress = false,
    double downloadProgress = 0,
    bool showRemoveMenu = false,
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
          boxShadow: _cardShadows(context),
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
                if (showRemoveMenu)
                  PopupMenuButton<String>(
                    tooltip: 'Действия',
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    onSelected: (value) {
                      if (value == 'remove') {
                        showRemoveLocalizationDialog(context);
                      }
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                        value: 'remove',
                        child: Text('Удалить русификатор…'),
                      ),
                    ],
                  ),
              ],
            ),
            if (footer != null) ...[
              const SizedBox(height: 10),
              footer,
            ],
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

/// Компактный чип Shizuku: зелёный — активен, красная пульсирующая обводка — нет.
class _ShizukuStatusChip extends StatefulWidget {
  const _ShizukuStatusChip({
    required this.active,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final String label;
  final VoidCallback onTap;

  @override
  State<_ShizukuStatusChip> createState() => _ShizukuStatusChipState();
}

class _ShizukuStatusChipState extends State<_ShizukuStatusChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (!widget.active) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _ShizukuStatusChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!widget.active && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = widget.active
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);
    final baseBorder = widget.active
        ? Theme.of(context).dividerColor.withValues(alpha: 0.9)
        : const Color(0xFFEF4444).withValues(alpha: 0.55);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final pulseAlpha = widget.active ? 0.0 : (0.35 + _pulse.value * 0.55);
        return Container(
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: widget.active
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: pulseAlpha * 0.45),
                      blurRadius: 6 + _pulse.value * 4,
                      spreadRadius: _pulse.value * 0.6,
                    ),
                  ],
          ),
          child: child,
        );
      },
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final borderColor = widget.active
                  ? baseBorder
                  : Color.lerp(
                      const Color(0xFFEF4444).withValues(alpha: 0.45),
                      const Color(0xFFEF4444),
                      _pulse.value,
                    )!;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: borderColor,
                    width: widget.active ? 1 : 1.4,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: dot.withValues(alpha: 0.45),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

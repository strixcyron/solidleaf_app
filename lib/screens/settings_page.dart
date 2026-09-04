import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';

import '../controllers/launcher_controller.dart';
import '../data/animated_covers.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_cover_view.dart';
import '../widgets/remove_localization_dialog.dart';

/// Экран настроек лаунчера: оформление (тема, пресеты, акцентный цвет,
/// адаптивные цвета), интерфейс (масштаб шрифта) и эффекты (анимации,
/// анимированная обложка).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LauncherController>();
    final textPrimary = Theme.of(context).textTheme.bodyMedium?.color;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        foregroundColor: textPrimary,
        elevation: 0,
        title: const Text('Настройки'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _sectionTitle(context, 'Тема оформления'),
            const SizedBox(height: 12),
            _ThemePresetGrid(controller: controller),
            const SizedBox(height: 20),
            _settingsCard(
              context,
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.dark_mode_rounded),
                    title: const Text('Тёмная тема'),
                    subtitle: const Text(
                      'Для тем «Из обложки» и адаптивных цветов',
                    ),
                    value: controller.isDarkMode,
                    onChanged: (_) => controller.toggleTheme(),
                  ),
                  if (Platform.isAndroid) ...[
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.palette_outlined),
                      title: const Text('Адаптивные цвета системы'),
                      subtitle: const Text(
                        'Material You — цвета из обоев (Android 12+)',
                      ),
                      value: controller.dynamicColorEnabled,
                      onChanged: controller.setDynamicColor,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle(context, 'Акцентный цвет'),
            const SizedBox(height: 12),
            _settingsCard(
              context,
              child: _AccentColorPicker(controller: controller),
            ),
            const SizedBox(height: 24),
            _sectionTitle(context, 'Интерфейс'),
            const SizedBox(height: 12),
            _settingsCard(
              context,
              child: _UiScaleSetting(controller: controller),
            ),
            const SizedBox(height: 24),
            _sectionTitle(context, 'Эффекты'),
            const SizedBox(height: 12),
            _settingsCard(
              context,
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.animation_rounded),
                    title: const Text('Анимации'),
                    subtitle: const Text(
                      'Дождь по стеклу и другие анимации. Отключите для '
                      'экономии ресурсов.',
                    ),
                    value: controller.animationsEnabled,
                    onChanged: controller.setAnimationsEnabled,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.movie_creation_outlined),
                    title: const Text('Анимированная обложка'),
                    subtitle: const Text(
                      'Проигрывать анимацию из assets/video (иначе — статичная)',
                    ),
                    value: controller.animatedCoverEnabled,
                    onChanged: controller.setAnimatedCover,
                  ),
                  // Выбор одной из 7 анимированных обложек.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: controller.animatedCoverEnabled
                        ? Padding(
                            padding: const EdgeInsets.only(
                              top: 4,
                              bottom: 10,
                            ),
                            child: _AnimatedCoverPicker(controller: controller),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
            if (Platform.isAndroid) ...[
              const SizedBox(height: 28),
              _sectionTitle(context, 'Опасная зона'),
              const SizedBox(height: 12),
              _settingsCard(
                context,
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: const Text('Удалить текстовую локализацию'),
                      subtitle: const Text(
                        'Восстановить оригинальные текстовые файлы из бэкапа',
                      ),
                      onTap: () => confirmAndRemoveComponent(
                        context,
                        kind: 'text',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.image_not_supported_outlined,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: const Text('Удалить графику и текстуры'),
                      subtitle: const Text(
                        'Восстановить оригинальные графические файлы из бэкапа',
                      ),
                      onTap: () => confirmAndRemoveComponent(
                        context,
                        kind: 'art',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).textTheme.bodyMedium?.color,
      ),
    );
  }

  Widget _settingsCard(BuildContext context, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: child,
    );
  }
}

/// Сетка выбора пресета темы с превью цветов.
class _ThemePresetGrid extends StatelessWidget {
  const _ThemePresetGrid({required this.controller});

  final LauncherController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final preset in AppThemePreset.values)
          _PresetTile(
            preset: preset,
            selected: controller.themePreset == preset,
            onTap: () => controller.setThemePreset(preset),
          ),
      ],
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final AppThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.previewAccent(preset);
    final bg = AppTheme.previewBackground(preset);
    final textPrimary = Theme.of(context).textTheme.bodyMedium?.color;

    return SizedBox(
      width: 158,
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Мини-превью темы: фон + акцентная точка.
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white24),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (selected)
                        Text(
                          'Выбрано',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
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
    );
  }
}

/// Выбор акцентного цвета: набор быстрых образцов, «Авто» (из пресета) и
/// полноценный color picker для произвольного цвета.
class _AccentColorPicker extends StatelessWidget {
  const _AccentColorPicker({required this.controller});

  final LauncherController controller;

  // Готовая палитра приятных акцентов.
  static const List<Color> _swatches = [
    Color(0xFF7B52F4),
    Color(0xFFB026FF),
    Color(0xFF00B4D8),
    Color(0xFF00E5D0),
    Color(0xFF2ECC71),
    Color(0xFFF1C40F),
    Color(0xFFFF8C42),
    Color(0xFFE75A7C),
    Color(0xFFE74C3C),
    Color(0xFF5DADE2),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = controller.customAccent;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Задайте свой цвет акцентов или выберите «Авто», чтобы '
            'использовать цвет темы.',
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // «Авто» — сброс на цвет пресета/обложки.
              _AccentDot(
                color: scheme.primary,
                selected: selected == null,
                isAuto: true,
                onTap: () => controller.setCustomAccent(null),
              ),
              for (final color in _swatches)
                _AccentDot(
                  color: color,
                  selected: selected != null &&
                      selected.toARGB32() == color.toARGB32(),
                  onTap: () => controller.setCustomAccent(color),
                ),
              // Произвольный цвет через полноценный picker.
              _AccentDot(
                color: selected ?? scheme.primary,
                selected: selected != null &&
                    !_swatches.any(
                      (c) => c.toARGB32() == selected.toARGB32(),
                    ),
                isCustom: true,
                onTap: () => _openPicker(context, selected ?? scheme.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openPicker(BuildContext context, Color initial) async {
    Color picked = initial;
    final result = await showDialog<Color>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(dialogContext).cardColor,
          title: const Text('Свой акцентный цвет'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: initial,
              enableAlpha: false,
              labelTypes: const [],
              pickerAreaHeightPercent: 0.7,
              onColorChanged: (color) => picked = color,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(picked),
              child: const Text('Применить'),
            ),
          ],
        );
      },
    );
    if (result != null) {
      await controller.setCustomAccent(result);
    }
  }
}

/// Кружок-образец акцентного цвета.
class _AccentDot extends StatelessWidget {
  const _AccentDot({
    required this.color,
    required this.selected,
    required this.onTap,
    this.isAuto = false,
    this.isCustom = false,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final bool isAuto;
  final bool isCustom;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 3 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Icon(
          isAuto
              ? Icons.auto_awesome_rounded
              : isCustom
                  ? Icons.colorize_rounded
                  : (selected ? Icons.check_rounded : null),
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Горизонтальная лента выбора одной из анимированных обложек.
class _AnimatedCoverPicker extends StatelessWidget {
  const _AnimatedCoverPicker({required this.controller});

  final LauncherController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Выберите обложку',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: animatedCovers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final cover = animatedCovers[index];
              return _CoverThumb(
                cover: cover,
                selected: controller.animatedCoverIndex == index,
                onTap: () => controller.setAnimatedCoverIndex(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Превью-плитка анимированной обложки.
class _CoverThumb extends StatelessWidget {
  const _CoverThumb({
    required this.cover,
    required this.selected,
    required this.onTap,
  });

  final AnimatedCover cover;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 132,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 74,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? primary : Theme.of(context).dividerColor,
                  width: selected ? 2.5 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedCoverView(
                    cover: cover,
                    imageFallback: Image.asset(
                      cover.webp,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => Image.asset(
                        cover.gif,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        alignment: Alignment.center,
                        errorBuilder: (_, __, ___) => _placeholder(context),
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              cover.label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? primary
                    : Theme.of(context).textTheme.bodySmall?.color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      alignment: Alignment.center,
      child: Icon(
        Icons.movie_creation_outlined,
        color: Theme.of(context).textTheme.bodySmall?.color,
      ),
    );
  }
}

/// Настройка масштаба шрифта интерфейса.
class _UiScaleSetting extends StatelessWidget {
  const _UiScaleSetting({required this.controller});

  final LauncherController controller;

  @override
  Widget build(BuildContext context) {
    final scale = controller.uiScale;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_size_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Размер шрифта',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ),
              Text(
                '${(scale * 100).round()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: scale,
            min: 0.8,
            max: 1.4,
            divisions: 12,
            label: '${(scale * 100).round()}%',
            onChanged: (value) => controller.setUiScale(value),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Мельче',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              Text(
                'Крупнее',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

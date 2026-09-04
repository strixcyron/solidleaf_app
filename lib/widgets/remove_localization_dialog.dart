import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/launcher_controller.dart';

/// Диалог удаления русификатора (текст / текстуры / всё).
Future<void> showRemoveLocalizationDialog(BuildContext context) async {
  final controller = context.read<LauncherController>();

  final choice = await showDialog<String?>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(ctx).cardColor,
      title: Text(
        'Удалить русификатор',
        style: TextStyle(
          color: Theme.of(ctx).textTheme.bodyMedium?.color,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Выберите, что восстановить из резервной копии:',
            style: TextStyle(
              color: Theme.of(ctx).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop('text'),
            child: const Text('Только текст'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop('art'),
            child: const Text('Только текстуры'),
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

  if (!context.mounted || choice == null) return;

  final label = choice == 'all'
      ? 'удалить всё'
      : choice == 'art'
          ? 'удалить текстуры'
          : 'удалить текст';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (c2) => AlertDialog(
      backgroundColor: Theme.of(c2).cardColor,
      title: Text(
        'Подтвердите',
        style: TextStyle(
          color: Theme.of(c2).textTheme.bodyMedium?.color,
        ),
      ),
      content: Text(
        'Вы уверены, что хотите $label?',
        style: TextStyle(
          color: Theme.of(c2).textTheme.bodySmall?.color,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(c2).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(c2).pop(true),
          child: const Text('Удалить'),
        ),
      ],
    ),
  );

  if (!context.mounted || confirmed != true) return;

  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    if (choice == 'all') {
      await controller.restoreBackup();
    } else {
      await controller.restoreBackupKind(choice);
    }
    if (!context.mounted) return;
    messenger?.showSnackBar(
      const SnackBar(content: Text('Русификатор удалён')),
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger?.showSnackBar(
      SnackBar(content: Text('Не удалось удалить: $e')),
    );
  }
}

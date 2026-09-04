import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/launcher_controller.dart';

/// Подтверждение и удаление одного компонента: `text` или `art`.
Future<void> confirmAndRemoveComponent(
  BuildContext context, {
  required String kind,
}) async {
  assert(kind == 'text' || kind == 'art');

  final title = kind == 'art'
      ? 'Удалить графику и текстуры?'
      : 'Удалить текстовую локализацию?';
  final body = kind == 'art'
      ? 'Файлы графики будут восстановлены из резервной копии.'
      : 'Файлы текста будут восстановлены из резервной копии.';
  final doneLabel = kind == 'art'
      ? 'Графика и текстуры удалены'
      : 'Текстовая локализация удалена';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(ctx).cardColor,
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(ctx).textTheme.bodyMedium?.color,
        ),
      ),
      content: Text(
        body,
        style: TextStyle(
          color: Theme.of(ctx).textTheme.bodySmall?.color,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Удалить'),
        ),
      ],
    ),
  );

  if (!context.mounted || confirmed != true) return;

  final controller = context.read<LauncherController>();
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await controller.restoreBackupKind(kind);
    if (!context.mounted) return;
    messenger?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(doneLabel),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          'Не удалось удалить: ${e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')}',
        ),
      ),
    );
  }
}

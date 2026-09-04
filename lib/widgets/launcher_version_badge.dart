import 'package:flutter/material.dart';

import '../data/launcher_changelog.dart';

/// Компактный бейдж версии лаунчера («alpha v0.2»). По клику открывает диалог
/// с историей изменений лаунчера.
class LauncherVersionBadge extends StatelessWidget {
  const LauncherVersionBadge({super.key, this.compact = false});

  /// Компактный режим — короткая подпись без иконки (для узких панелей).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Tooltip(
      message: 'Что нового в лаунчере',
      child: Material(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showLauncherChangelogDialog(context),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: compact ? 3 : 5,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!compact) ...[
                  Icon(Icons.rocket_launch_rounded, size: 13, color: accent),
                  const SizedBox(width: 5),
                ],
                Text(
                  launcherVersionLabel,
                  style: TextStyle(
                    color: accent,
                    fontSize: compact ? 11 : 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
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

/// Показывает всплывающее окно с историей версий лаунчера.
Future<void> showLauncherChangelogDialog(BuildContext context) {
  final textPrimary = Theme.of(context).textTheme.bodyMedium?.color;
  final textSecondary = Theme.of(context).textTheme.bodySmall?.color;
  final accent = Theme.of(context).colorScheme.primary;

  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Row(
          children: [
            Icon(Icons.rocket_launch_rounded, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Лаунчер SolidLeaf',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                launcherVersionLabel,
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final release in launcherChangelog) ...[
                  Row(
                    children: [
                      Text(
                        'Версия ${release.version}',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        release.date,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final change in release.changes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6, right: 8),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              change,
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      );
    },
  );
}

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_constants.dart';
import '../data/project_team.dart';
import '../models/team_member.dart';

/// Страница «О проекте» с описанием и карточками команды.
class AboutProjectPage extends StatelessWidget {
  const AboutProjectPage({super.key});

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть ссылку: $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).textTheme.bodyMedium?.color;
    final textSecondary = Theme.of(context).textTheme.bodySmall?.color;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        foregroundColor: textPrimary,
        elevation: 0,
        title: const Text('О проекте'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SolidLeaf | Reverse: 1999',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Фанатский проект полной русификации Reverse: 1999. '
                'Лаунчер помогает устанавливать и обновлять текстовую локализацию, '
                'а для участников премиум-канала — графику и текстуры.',
                style: TextStyle(
                  color: textSecondary,
                  height: 1.55,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              _SupportButton(
                onTap: () => _openLink(context, boostyUrl),
              ),
              const SizedBox(height: 28),
              for (final section in ProjectTeam.sections) ...[
                _SectionTitle(title: section.title),
                const SizedBox(height: 12),
                for (final member in section.members) ...[
                  _TeamMemberCard(
                    member: member,
                    roleIcon: section.roleIcon,
                    onOpenLink: member.profileUrl == null
                        ? null
                        : () => _openLink(context, member.profileUrl!),
                    onOpenChannel: member.channelUrl == null
                        ? null
                        : () => _openLink(context, member.channelUrl!),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportButton extends StatelessWidget {
  const _SupportButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Продолговатая карточка по центру страницы, не на всю ширину.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Material(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Поддержать проект',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Картинка растянута на всю ширину карточки со скруглением.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/images/abou_boosty.png',
                      width: double.infinity,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: double.infinity,
                        height: 85,
                        alignment: Alignment.center,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.12),
                        child: Icon(
                          Icons.favorite_rounded,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).textTheme.bodyMedium?.color,
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  const _TeamMemberCard({
    required this.member,
    this.roleIcon,
    this.onOpenLink,
    this.onOpenChannel,
  });

  final TeamMember member;
  final IconData? roleIcon;
  final VoidCallback? onOpenLink;
  final VoidCallback? onOpenChannel;

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).textTheme.bodyMedium?.color;
    final textSecondary = Theme.of(context).textTheme.bodySmall?.color;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MemberAvatar(member: member),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (member.isLead) ...[
                            const Icon(
                              FluentIcons.crown_24_filled,
                              size: 18,
                              color: Color(0xFFC9A227),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              member.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                                color: textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (roleIcon != null) ...[
                            const SizedBox(width: 6),
                            Icon(
                              roleIcon,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                          if (member.isLead) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFC9A227,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(
                                    0xFFC9A227,
                                  ).withValues(alpha: 0.5),
                                ),
                              ),
                              child: const Text(
                                'Главный',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFC9A227),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onOpenChannel != null)
                      IconButton(
                        onPressed: onOpenChannel,
                        icon: Icon(
                          Icons.campaign_rounded,
                          size: 18,
                          color: textSecondary,
                        ),
                        tooltip: 'Открыть канал',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    if (onOpenLink != null)
                      IconButton(
                        onPressed: onOpenLink,
                        icon: Icon(
                          Icons.open_in_new_rounded,
                          size: 18,
                          color: textSecondary,
                        ),
                        tooltip: 'Открыть профиль',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  member.description,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.member});

  final TeamMember member;

  @override
  Widget build(BuildContext context) {
    const size = 52.0;
    final initial = member.name.isNotEmpty ? member.name[0].toUpperCase() : '?';

    if (member.avatarAsset != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          member.avatarAsset!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsAvatar(context, size, initial),
        ),
      );
    }

    return _initialsAvatar(context, size, initial);
  }

  Widget _initialsAvatar(BuildContext context, double size, String initial) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

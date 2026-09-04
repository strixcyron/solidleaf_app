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
              _CommunityLinksRow(
                shadows: _cardShadows(context),
                onBoosty: () => _openLink(context, boostyUrl),
                onTelegram: () => _openLink(context, telegramUrl),
                onMax: () => _openLink(context, maxMessengerUrl),
              ),
              const SizedBox(height: 28),
              for (final section in ProjectTeam.sections) ...[
                _SectionTitle(title: section.title),
                const SizedBox(height: 12),
                for (final member in section.members) ...[
                  _TeamMemberCard(
                    member: member,
                    roleIcon: section.roleIcon,
                    shadows: _cardShadows(context),
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

/// Ряд ссылок: Boosty / Telegram / MAX.
class _CommunityLinksRow extends StatelessWidget {
  const _CommunityLinksRow({
    required this.shadows,
    required this.onBoosty,
    required this.onTelegram,
    required this.onMax,
  });

  final List<BoxShadow> shadows;
  final VoidCallback onBoosty;
  final VoidCallback onTelegram;
  final VoidCallback onMax;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).dividerColor),
            boxShadow: shadows,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Поддержать и связаться',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _LinkChip(
                      label: 'Boosty',
                      assetName: 'boosty_icon.png',
                      fallbackIcon: Icons.favorite_rounded,
                      onTap: onBoosty,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _LinkChip(
                      label: 'Telegram',
                      assetName: 'telegram_icon.png',
                      fallbackIcon: Icons.send_rounded,
                      onTap: onTelegram,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _LinkChip(
                      label: 'MAX',
                      fallbackIcon: Icons.chat_rounded,
                      onTap: onMax,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.label,
    required this.fallbackIcon,
    required this.onTap,
    this.assetName,
  });

  final String label;
  final String? assetName;
  final IconData fallbackIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (assetName != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/$assetName',
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      fallbackIcon,
                      size: 26,
                      color: primary,
                    ),
                  ),
                )
              else
                Icon(fallbackIcon, size: 26, color: primary),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
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
    this.shadows = const [],
    this.onOpenLink,
    this.onOpenChannel,
  });

  final TeamMember member;
  final IconData? roleIcon;
  final List<BoxShadow> shadows;
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
        boxShadow: shadows,
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

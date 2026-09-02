import 'package:flutter/widgets.dart';

/// Участник команды в разделе «О проекте».
class TeamMember {
  const TeamMember({
    required this.name,
    required this.description,
    this.profileUrl,
    this.channelUrl,
    this.avatarAsset,
    this.isLead = false,
  });

  final String name;
  final String description;

  /// Ссылка на профиль (GitHub, Boosty, Telegram и т.д.).
  final String? profileUrl;

  /// Ссылка на Telegram-канал участника (опционально).
  final String? channelUrl;

  /// Локальный ассет аватара, например `assets/images/team/strix.png`.
  final String? avatarAsset;

  /// Ведущий участник (главный) — рядом с именем показывается золотая корона.
  final bool isLead;
}

/// Группа участников: разработчики, редакторы, дизайнеры.
class TeamSection {
  const TeamSection({
    required this.title,
    required this.members,
    this.roleIcon,
  });

  final String title;
  final List<TeamMember> members;

  /// Иконка роли секции (карандаш для редакторов, палитра для дизайнеров
  /// и т.д.) — показывается рядом с именем каждого участника секции.
  final IconData? roleIcon;
}

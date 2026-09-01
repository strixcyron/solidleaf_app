/// Участник команды в разделе «О проекте».
class TeamMember {
  const TeamMember({
    required this.name,
    required this.description,
    this.profileUrl,
    this.avatarAsset,
  });

  final String name;
  final String description;

  /// Ссылка на профиль (GitHub, Boosty, Telegram и т.д.).
  final String? profileUrl;

  /// Локальный ассет аватара, например `assets/images/team/strix.png`.
  final String? avatarAsset;
}

/// Группа участников: разработчики, редакторы, дизайнеры.
class TeamSection {
  const TeamSection({
    required this.title,
    required this.members,
  });

  final String title;
  final List<TeamMember> members;
}

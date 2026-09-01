import '../models/team_member.dart';

/// Состав команды SOLIDLEAF — редактируйте этот файл при изменении состава.
class ProjectTeam {
  ProjectTeam._();

  static const sections = <TeamSection>[
    TeamSection(
      title: 'Разработчики',
      members: [
        TeamMember(
          name: 'STRIX CYRON',
          description:
              'Разработчик лаунчера для Windows и Android, Telegram-авторизация, '
              'инфраструктура обновлений и премиум-доступа.',
          profileUrl: 'https://github.com/strixcyron',
          avatarAsset: 'assets/images/launcher_icon.png',
        ),
        TeamMember(
          name: 'FrauxHD',
          description:
              'Backend-авторизация, Telegram-бот, приватные релизы премиум-контента '
              'и поддержка GitHub-инфраструктуры.',
          profileUrl: 'https://github.com/FrauxHD',
        ),
      ],
    ),
    TeamSection(
      title: 'Редакторы',
      members: [
        TeamMember(
          name: 'SOLIDLEAF TEAM',
          description:
              'Редактура и адаптация текстовой локализации: сюжет, диалоги, '
              'интерфейс и внутриигровые тексты.',
          profileUrl: 'https://t.me/reverse1999_solidleaf',
          avatarAsset: 'assets/images/telegram_icon.png',
        ),
      ],
    ),
    TeamSection(
      title: 'Дизайнеры',
      members: [
        TeamMember(
          name: 'SOLIDLEAF TEAM',
          description:
              'Визуальное оформление лаунчера, иконки, обложки и графика '
              'премиум-локализации.',
          profileUrl: 'https://boosty.to/strix.cyron',
          avatarAsset: 'assets/images/boosty_icon.png',
        ),
      ],
    ),
  ];
}

import 'package:flutter/material.dart';

import '../models/team_member.dart';

/// Состав команды SOLIDLEAF — редактируйте этот файл при изменении состава.
class ProjectTeam {
  ProjectTeam._();

  static const sections = <TeamSection>[
    TeamSection(
      title: 'Разработчики',
      members: [
        TeamMember(
          name: 'Strix',
          description:
              'Разработчик лаунчера для Windows и Android а также русификатора для игры',
          profileUrl: 'https://t.me/strix_gfx',
          avatarAsset: 'assets/images/strix_avatar.png',
          isLead: true,
        ),
        TeamMember(
          name: 'Super Clever',
          description:
              'Разработчик русификатора, фронтенд-бэкенд разработчик'
              'и создатель баззы данных для русификатора',
          profileUrl: 'https://t.me/SuperKlever',
          avatarAsset: 'assets/images/super_clever_avatar.png',
          isLead: true,
        ),
      ],
    ),
    TeamSection(
      title: 'Редакторы',
      roleIcon: Icons.edit_document,
      members: [
        TeamMember(
          name: 'Koven',
          description:
              'Главный редактор текстовой локализации: сюжета, диалогав,'
              'интерфейса и внутриигровых текстов.',
          profileUrl: 'https://t.me/Kovven',
          avatarAsset: 'assets/images/coven.png',
          isLead: true,
        ),
        TeamMember(
          name: '❀ Mr. Florister ❀',
          description:
              'Редактор текстовой локализации игры'
              ' атак же глава Фонада Святого Павлова',
          profileUrl: 'https://t.me/Mr_florister',
          channelUrl: 'https://t.me/stpf_info',
          avatarAsset: 'assets/images/florister.png',
        ),
         TeamMember(
          name: 'сін рэп шушы GSG9',
          description:
              'Редактор текстовой локализации игры',
          profileUrl: 'https://t.me/dicekin',
          avatarAsset: 'assets/images/sin.png',
        ),
         TeamMember(
          name: '꒰ эдем꒱୧ ‧₊˚',
          description:
              'Редактор текстовой локализации игры',
          profileUrl: 'https://t.me/tenshitenshi8hn',
          avatarAsset: 'assets/images/edem.png',
        ),
      ],
    ),
    TeamSection(
      title: 'Дизайнеры',
      roleIcon: Icons.palette_rounded,
      members: [
        TeamMember(
          name: 'Strix',
          description:
              'Визуальное оформление лаунчера, иконки, обложки и графика '
              'локализация текстур игры.',
          profileUrl: 'https://t.me/strix_gfx',
          avatarAsset: 'assets/images/strix_avatar.png',
        ),
        TeamMember(
          name: 'Ares Sideris',
          description:
              'Локализация текстур игры.',
          profileUrl: 'https://t.me/Ares_Sideris',
          avatarAsset: 'assets/images/ares_sideris.png',
        ),
      ],
    ),
    TeamSection(
      title: 'Медия',
      roleIcon: Icons.music_note,
      members: [
        TeamMember(
          name: 'Бусинка',
          description:
              'Медия по игре',
          profileUrl: 'https://t.me/F_ftornik',
          channelUrl: '',
          avatarAsset: 'assets/images/no_avatar.png',
        ),
      ],
    ),
  ];
}

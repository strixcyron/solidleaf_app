import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:text_scroll/text_scroll.dart';

import '../models/audio_track.dart';
import 'effects/audio_visualizer.dart';
import 'effects/magnetic_hover.dart';
import 'effects/parallax_cover.dart';
import 'wave_slider_track_shape.dart';

class MiniPlayer extends StatefulWidget {
  /// Использовать `cardColor` вместо `scaffoldBackgroundColor` для фона —
  /// чтобы плеер визуально совпадал с карточками компонентов (Android).
  final bool useCardColor;

  /// Сворачиваемая мини-панель: показывается только верхняя строка,
  /// остальное разворачивается по тапу (экономит место на Android).
  final bool collapsible;

  const MiniPlayer({
    super.key,
    this.useCardColor = false,
    this.collapsible = false,
  });

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer>
    with SingleTickerProviderStateMixin {
  final AudioPlayer player = AudioPlayer();
  bool isPlaying = false;
  late AnimationController _vinylController;

  /// Развёрнут ли плеер. В несворачиваемом режиме (десктоп) — всегда true.
  bool _expanded = true;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Список альбомов
  final List<Album> albums = [
    Album(
      title: 'The Suitcase OST',
      coverAsset: 'assets/images/music_cover/cover.jpg',
      year: '1999',
      tracks: [
        AudioTrack(
          title: 'Main Theme',
          fileName: 'theme1.mp3',
          coverAsset: 'assets/images/music_cover/cover.jpg',
          durationStr: '2:15',
        ),
        AudioTrack(
          title: 'Re-re-re-regulus!',
          fileName: 'Re-re-re-regulus!.mp3',
          coverAsset: 'assets/images/music_cover/cover.jpg',
          durationStr: '3:40',
        ),
        AudioTrack(
          title: 'The Gleaming',
          fileName: 'The Gleaming.mp3',
          coverAsset: 'assets/images/music_cover/cover.jpg',
          durationStr: '1:55',
        ),
      ],
    ),
    Album(
      title: 'A Nightmare at Green Lake',
      coverAsset: 'assets/images/music_cover/cover.jpg',
      year: '2023',
      tracks: [
        AudioTrack(
          title: 'A Nightmare at Green Lake - Battle',
          fileName: 'A Nightmare at Green Lake - Battle.mp3',
          coverAsset: 'assets/images/music_cover/cover.jpg',
          durationStr: '1:36',
        ),
        AudioTrack(
          title: 'A Nightmare at Green Lake - Final Boss Theme',
          fileName: 'A Nightmare at Green Lake - Final Boss Theme.mp3',
          coverAsset: 'assets/images/music_cover/cover.jpg',
          durationStr: '3:23',
        ),
      ],
    ),
    Album(
      title: 'Полярная ночь',
      coverAsset: 'assets/images/music_cover/polar_night.jpg',
      year: '2024',
      tracks: [
        AudioTrack(
          title: 'Polar Night',
          fileName: 'Polar Night.mp3',
          coverAsset: 'assets/images/music_cover/polar_night.jpg',
          durationStr: '3:53',
        ),
          AudioTrack(
          title: 'Polar Night (Instrumental)',
          fileName: 'Polar Night (Instrumental).mp3',
          coverAsset: 'assets/images/music_cover/polar_night.jpg',
          durationStr: '3:53',
        ),
      ],
    ),
  ];

  // Плоский список всех треков для переключения кнопками Next/Prev
  List<AudioTrack> get allTracks =>
      albums.expand((album) => album.tracks).toList();

  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Сворачиваемый плеер стартует свёрнутым, обычный — всегда развёрнут.
    _expanded = !widget.collapsible;
    _vinylController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // Слушатели времени для прогресс-бара
    player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    player.onPlayerComplete.listen((_) {
      nextTrack();
    });
  }

  @override
  void dispose() {
    player.dispose();
    _vinylController.dispose();
    super.dispose();
  }

  void togglePlay() async {
    if (isPlaying) {
      await player.pause();
      _vinylController.stop();
    } else {
      await player
          .play(AssetSource('music/${allTracks[currentIndex].fileName}'));
      _vinylController.repeat();
    }
    setState(() {
      isPlaying = !isPlaying;
    });
  }

  void nextTrack() async {
    await player.stop();
    setState(() {
      currentIndex = (currentIndex + 1) % allTracks.length;
      isPlaying = false;
      _position = Duration.zero;
    });
    togglePlay();
  }

  void prevTrack() async {
    await player.stop();
    setState(() {
      currentIndex = (currentIndex - 1 < 0)
          ? allTracks.length - 1
          : currentIndex - 1;
      isPlaying = false;
      _position = Duration.zero;
    });
    togglePlay();
  }

  void playSpecificTrack(AudioTrack track) async {
    int index = allTracks.indexOf(track);
    if (index != -1) {
      await player.stop();
      setState(() {
        currentIndex = index;
        isPlaying = false;
        _position = Duration.zero;
      });
      togglePlay();
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

// Окно с альбомами и треками
  void _showPlaylist() {
    showDialog(
      context: context,
      builder: (ctx) {
        Album? selectedAlbum;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Row(
                children: [
                  if (selectedAlbum != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => setDialogState(() => selectedAlbum = null),
                    ),
                  Text(
                    // Если альбом открыт, можно написать "Назад" или оставить название
                    selectedAlbum == null ? 'Альбомы' : 'Альбом',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 360,
                height: 500, // Увеличил высоту, чтобы влезла квадратная обложка и треки
                child: selectedAlbum == null
                    // --- Список альбомов (до открытия) ---
                    ? ListView.separated(
                        itemCount: albums.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final album = albums[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setDialogState(() {
                                selectedAlbum = album;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                ),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.asset(
                                      album.coverAsset,
                                      width: 45,
                                      height: 45,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          album.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.color,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Год: ${album.year} • Треков: ${album.tracks.length}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    // --- Содержимое выбранного альбома ---
                    : Column(
                        children: [
                          // Шапка альбома (Квадратная обложка с градиентом)
                          Center(
                            child: ParallaxCover(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 355,
                                  height: 300,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.asset(
                                        selectedAlbum!.coverAsset,
                                        fit: BoxFit.cover,
                                      ),
                                    // Градиентное затемнение (плавно от центра к низу)
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withValues(alpha: 0.1),
                                            Colors.black.withValues(alpha: 0.85),
                                          ],
                                          stops: const [0.4, 0.7, 1.0],
                                        ),
                                      ),
                                    ),
                                    // Текст поверх затемнения
                                    Positioned(
                                      left: 16,
                                      right: 16,
                                      bottom: 16,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            selectedAlbum!.title,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white, // Белый для контраста
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Выпуск: ${selectedAlbum!.year} год',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.white.withValues(alpha: 0.8),
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
                          ),
                          const Divider(height: 20),
                          // Список треков альбома
                          Expanded(
                            child: ListView.separated(
                              itemCount: selectedAlbum!.tracks.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final track = selectedAlbum!.tracks[index];
                                final isCurrent =
                                    allTracks[currentIndex] == track;

                                return InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    playSpecificTrack(track);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCurrent
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.15)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isCurrent
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isCurrent
                                              ? Icons.graphic_eq
                                              : Icons.music_note,
                                          size: 18,
                                          color: isCurrent
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            track.title,
                                            style: TextStyle(
                                              fontWeight: isCurrent
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          track.durationStr,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final track = allTracks[currentIndex];

    // Показывать ли разворачиваемое тело (визуализатор, прогресс, управление).
    final showBody = !widget.collapsible || _expanded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: widget.useCardColor
            ? Theme.of(context).cardColor
            : Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ParallaxCover(
                maxOffset: 2.5,
                child: RotationTransition(
                  turns: _vinylController,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF111111),
                      border: Border.all(color: Colors.black45, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3.0),
                      child: ClipOval(
                        child: Image.asset(track.coverAsset, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Название трека (Бегущая строка)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextScroll(
                      track.title,
                      mode: TextScrollMode.endless, 
                      velocity: const Velocity(pixelsPerSecond: Offset(25, 0)), 
                      delayBefore: const Duration(seconds: 2), 
                      pauseBetween: const Duration(seconds: 1), 
                      
                      // --- Эффект нативного интерфейса (растворение краев) ---
                      fadedBorder: true, 
                      fadedBorderWidth: 0.1, // 10% ширины виджета будет уходить в плавный градиент
                      // --------------------------------------------------------

                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Воспроизведение',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Компактная play/pause — видна, когда плеер свёрнут.
              if (widget.collapsible && !_expanded)
                IconButton(
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: isPlaying ? 'Пауза' : 'Воспроизвести',
                  onPressed: togglePlay,
                ),

              // Кнопка плейлиста/альбомов
              IconButton(
                icon: Icon(
                  Icons.queue_music_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                tooltip: 'Альбомы',
                onPressed: _showPlaylist,
              ),

              // Переключатель сворачивания (только в сворачиваемом режиме).
              if (widget.collapsible)
                IconButton(
                  icon: Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  tooltip: _expanded ? 'Свернуть' : 'Развернуть',
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
            ],
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: !showBody
                ? const SizedBox(width: double.infinity)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: AudioVisualizer(isPlaying: isPlaying),
                      ),

// Прогресс-бар длительности
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    // --- ПОДКЛЮЧАЕМ НАШ КАСТОМНЫЙ КЛАСС ВОЛНЫ ---
                    trackShape: WaveSliderTrackShape(waveHeight: 3.0, waveLength: 12.0), 
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    inactiveTrackColor:
                        Theme.of(context).dividerColor.withValues(alpha: 0.3),
                    thumbColor: Theme.of(context).colorScheme.primary,
                  ),
                  // --- ВЕРНУЛИ СТАНДАРТНЫЙ SLIDER ---
                  child: Slider(
                    value: _position.inSeconds.toDouble().clamp(
                          0,
                          _duration.inSeconds.toDouble() > 0
                              ? _duration.inSeconds.toDouble()
                              : 1,
                        ),
                    max: _duration.inSeconds.toDouble() > 0
                        ? _duration.inSeconds.toDouble()
                        : 1,
                    onChanged: (val) {
                      player.seek(Duration(seconds: val.toInt()));
                    },
                  ),
                  // ---------------------------------------------------
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),



          // Элементы управления
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded),
                color: Theme.of(context).textTheme.bodyMedium?.color,
                onPressed: prevTrack,
              ),
              MagneticHover(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.2),
                  ),
                  child: IconButton(
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    color: Theme.of(context).colorScheme.primary,
                    iconSize: 28,
                    onPressed: togglePlay,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded),
                color: Theme.of(context).textTheme.bodyMedium?.color,
                onPressed: nextTrack,
              ),
            ],
          ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

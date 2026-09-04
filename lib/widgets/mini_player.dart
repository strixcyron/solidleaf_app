import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:text_scroll/text_scroll.dart';

import '../controllers/launcher_controller.dart';
import '../models/audio_track.dart';
import '../utils/app_dialogs.dart';
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
        AudioTrack(
          title: 'A Farewell',
          fileName: 'A Farewell.mp3',
          coverAsset: 'assets/images/music_cover/polar_night.jpg',
          durationStr: '—',
        ),
        AudioTrack(
          title: 'A New World',
          fileName: 'A New World.mp3',
          coverAsset: 'assets/images/music_cover/polar_night.jpg',
          durationStr: '—',
        ),
      ],
    ),
  ];

  // Плоский список всех треков.
  List<AudioTrack> get allTracks =>
      albums.expand((album) => album.tracks).toList();

  /// Очередь с учётом избранного / shuffle.
  List<AudioTrack> _queueFor(LauncherController ctrl) {
    var list = List<AudioTrack>.from(allTracks);
    if (ctrl.playbackMode == PlaybackMode.favorites) {
      final fav = list
          .where((t) => ctrl.isFavoriteTrack(t.fileName))
          .toList();
      if (fav.isNotEmpty) list = fav;
    }
    if (ctrl.playbackMode == PlaybackMode.shuffle) {
      list = List<AudioTrack>.from(list)..shuffle(math.Random());
    }
    return list;
  }

  AudioTrack get currentTrack => allTracks[
      currentIndex.clamp(0, allTracks.isEmpty ? 0 : allTracks.length - 1)];

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
    if (allTracks.isEmpty) return;
    final ctrl = context.read<LauncherController>();
    final queue = _queueFor(ctrl);
    final current = allTracks[currentIndex];
    var qi = queue.indexWhere((t) => t.fileName == current.fileName);
    if (qi < 0) qi = 0;
    final next = queue[(qi + 1) % queue.length];
    await playSpecificTrack(next);
  }

  void prevTrack() async {
    if (allTracks.isEmpty) return;
    final ctrl = context.read<LauncherController>();
    final queue = _queueFor(ctrl);
    final current = allTracks[currentIndex];
    var qi = queue.indexWhere((t) => t.fileName == current.fileName);
    if (qi < 0) qi = 0;
    final prev = queue[(qi - 1 < 0) ? queue.length - 1 : qi - 1];
    await playSpecificTrack(prev);
  }

  Future<void> playSpecificTrack(AudioTrack track) async {
    final index = allTracks.indexWhere((t) => t.fileName == track.fileName);
    if (index == -1) return;
    await player.stop();
    setState(() {
      currentIndex = index;
      isPlaying = false;
      _position = Duration.zero;
    });
    togglePlay();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }


  /// Плейлист в стиле bottom sheet (как инструкция Shizuku).
  Future<void> _showPlaylist() async {
    final ctrl = context.read<LauncherController>();
    Album? selectedAlbum;

    await showAppBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final textColor = Theme.of(context).textTheme.bodyMedium?.color;
            final maxH = MediaQuery.sizeOf(context).height * 0.75;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxH),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      appSheetHandle(context),
                      Row(
                        children: [
                          if (selectedAlbum != null)
                            IconButton(
                              icon: const Icon(Icons.arrow_back_rounded),
                              onPressed: () =>
                                  setSheetState(() => selectedAlbum = null),
                            ),
                          Expanded(
                            child: Text(
                              selectedAlbum == null
                                  ? 'Альбомы и треки'
                                  : selectedAlbum!.title,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Только избранные',
                            icon: Icon(
                              Icons.favorite_rounded,
                              color: ctrl.playbackMode == PlaybackMode.favorites
                                  ? Colors.redAccent
                                  : Theme.of(context).textTheme.bodySmall?.color,
                            ),
                            onPressed: () async {
                              await ctrl.setPlaybackMode(
                                ctrl.playbackMode == PlaybackMode.favorites
                                    ? PlaybackMode.all
                                    : PlaybackMode.favorites,
                              );
                              setSheetState(() {});
                            },
                          ),
                          IconButton(
                            tooltip: 'Случайный порядок',
                            icon: Icon(
                              Icons.shuffle_rounded,
                              color: ctrl.playbackMode == PlaybackMode.shuffle
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).textTheme.bodySmall?.color,
                            ),
                            onPressed: () async {
                              await ctrl.setPlaybackMode(
                                ctrl.playbackMode == PlaybackMode.shuffle
                                    ? PlaybackMode.all
                                    : PlaybackMode.shuffle,
                              );
                              setSheetState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: selectedAlbum == null
                            ? ListView.separated(
                                shrinkWrap: true,
                                itemCount: albums.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final album = albums[index];
                                  return ListTile(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: Theme.of(context).dividerColor,
                                      ),
                                    ),
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.asset(
                                        album.coverAsset,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    title: Text(album.title),
                                    subtitle: Text(
                                      '${album.year} · ${album.tracks.length} треков',
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => setSheetState(
                                      () => selectedAlbum = album,
                                    ),
                                  );
                                },
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: selectedAlbum!.tracks.length,
                                itemBuilder: (context, index) {
                                  final track = selectedAlbum!.tracks[index];
                                  final fav =
                                      ctrl.isFavoriteTrack(track.fileName);
                                  final playing =
                                      allTracks[currentIndex].fileName ==
                                          track.fileName;
                                  return ListTile(
                                    leading: Icon(
                                      playing
                                          ? Icons.equalizer_rounded
                                          : Icons.music_note_rounded,
                                      color: playing
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : null,
                                    ),
                                    title: Text(track.title),
                                    subtitle: Text(track.durationStr),
                                    trailing: IconButton(
                                      icon: Icon(
                                        fav
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        color: fav ? Colors.redAccent : null,
                                      ),
                                      onPressed: () async {
                                        await ctrl.toggleFavoriteTrack(
                                          track.fileName,
                                        );
                                        setSheetState(() {});
                                        setState(() {});
                                      },
                                    ),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      playSpecificTrack(track);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
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
                        child: AudioVisualizer(
                          isPlaying: isPlaying,
                          expanded: true,
                          height: 28,
                        ),
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
              Consumer<LauncherController>(
                builder: (context, ctrl, _) {
                  final fav = ctrl.isFavoriteTrack(
                    allTracks[currentIndex].fileName,
                  );
                  return IconButton(
                    tooltip: fav ? 'Убрать из избранного' : 'В избранное',
                    icon: Icon(
                      fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: fav ? Colors.redAccent : null,
                    ),
                    onPressed: () => ctrl.toggleFavoriteTrack(
                      allTracks[currentIndex].fileName,
                    ),
                  );
                },
              ),
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
              Consumer<LauncherController>(
                builder: (context, ctrl, _) {
                  final shuffle = ctrl.playbackMode == PlaybackMode.shuffle;
                  final favOnly = ctrl.playbackMode == PlaybackMode.favorites;
                  return IconButton(
                    tooltip: shuffle
                        ? 'Случайный порядок'
                        : favOnly
                            ? 'Только избранные'
                            : 'Режим воспроизведения',
                    icon: Icon(
                      shuffle
                          ? Icons.shuffle_on_rounded
                          : favOnly
                              ? Icons.favorite_rounded
                              : Icons.repeat_rounded,
                      color: (shuffle || favOnly)
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    onPressed: () {
                      final next = switch (ctrl.playbackMode) {
                        PlaybackMode.all => PlaybackMode.favorites,
                        PlaybackMode.favorites => PlaybackMode.shuffle,
                        PlaybackMode.shuffle => PlaybackMode.all,
                      };
                      ctrl.setPlaybackMode(next);
                    },
                  );
                },
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

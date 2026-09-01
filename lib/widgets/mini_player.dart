import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:text_scroll/text_scroll.dart';

import '../models/audio_track.dart';
import 'wave_slider_track_shape.dart';
// --- РџР»РµРµСЂ ---
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer>
    with SingleTickerProviderStateMixin {
  final AudioPlayer player = AudioPlayer();
  bool isPlaying = false;
  late AnimationController _vinylController;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // РЎРїРёСЃРѕРє Р°Р»СЊР±РѕРјРѕРІ
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
      title: 'РџРѕР»СЏСЂРЅР°СЏ РЅРѕС‡СЊ',
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

  // РџР»РѕСЃРєРёР№ СЃРїРёСЃРѕРє РІСЃРµС… С‚СЂРµРєРѕРІ РґР»СЏ РїРµСЂРµРєР»СЋС‡РµРЅРёСЏ РєРЅРѕРїРєР°РјРё Next/Prev
  List<AudioTrack> get allTracks =>
      albums.expand((album) => album.tracks).toList();

  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _vinylController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // РЎР»СѓС€Р°С‚РµР»Рё РІСЂРµРјРµРЅРё РґР»СЏ РїСЂРѕРіСЂРµСЃСЃ-Р±Р°СЂР°
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

// РћРєРЅРѕ СЃ Р°Р»СЊР±РѕРјР°РјРё Рё С‚СЂРµРєР°РјРё
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
                    // Р•СЃР»Рё Р°Р»СЊР±РѕРј РѕС‚РєСЂС‹С‚, РјРѕР¶РЅРѕ РЅР°РїРёСЃР°С‚СЊ "РќР°Р·Р°Рґ" РёР»Рё РѕСЃС‚Р°РІРёС‚СЊ РЅР°Р·РІР°РЅРёРµ
                    selectedAlbum == null ? 'РђР»СЊР±РѕРјС‹' : 'РђР»СЊР±РѕРј',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 360,
                height: 500, // РЈРІРµР»РёС‡РёР» РІС‹СЃРѕС‚Сѓ, С‡С‚РѕР±С‹ РІР»РµР·Р»Р° РєРІР°РґСЂР°С‚РЅР°СЏ РѕР±Р»РѕР¶РєР° Рё С‚СЂРµРєРё
                child: selectedAlbum == null
                    // --- РЎРїРёСЃРѕРє Р°Р»СЊР±РѕРјРѕРІ (РґРѕ РѕС‚РєСЂС‹С‚РёСЏ) ---
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
                                          'Р“РѕРґ: ${album.year} вЂў РўСЂРµРєРѕРІ: ${album.tracks.length}',
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
                    // --- РЎРѕРґРµСЂР¶РёРјРѕРµ РІС‹Р±СЂР°РЅРЅРѕРіРѕ Р°Р»СЊР±РѕРјР° ---
                    : Column(
                        children: [
                          // РЁР°РїРєР° Р°Р»СЊР±РѕРјР° (РљРІР°РґСЂР°С‚РЅР°СЏ РѕР±Р»РѕР¶РєР° СЃ РіСЂР°РґРёРµРЅС‚РѕРј)
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 355, // Р—Р°РґР°РµРј РєРІР°РґСЂР°С‚РЅС‹Рµ РїСЂРѕРїРѕСЂС†РёРё
                                height: 300, 
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // РЎР°РјР° РѕР±Р»РѕР¶РєР°
                                    Image.asset(
                                      selectedAlbum!.coverAsset,
                                      fit: BoxFit.cover,
                                    ),
                                    // Р“СЂР°РґРёРµРЅС‚РЅРѕРµ Р·Р°С‚РµРјРЅРµРЅРёРµ (РїР»Р°РІРЅРѕ РѕС‚ С†РµРЅС‚СЂР° Рє РЅРёР·Сѓ)
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
                                    // РўРµРєСЃС‚ РїРѕРІРµСЂС… Р·Р°С‚РµРјРЅРµРЅРёСЏ
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
                                              color: Colors.white, // Р‘РµР»С‹Р№ РґР»СЏ РєРѕРЅС‚СЂР°СЃС‚Р°
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Р’С‹РїСѓСЃРє: ${selectedAlbum!.year} РіРѕРґ',
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
                          const Divider(height: 20),
                          // РЎРїРёСЃРѕРє С‚СЂРµРєРѕРІ Р°Р»СЊР±РѕРјР°
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
                  child: const Text('Р—Р°РєСЂС‹С‚СЊ'),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
 // Р’РёРЅРёР»РѕРІР°СЏ РїР»Р°СЃС‚РёРЅРєР°
              RotationTransition(
                turns: _vinylController,
                child: Container(
                  width: 56, // РЈРІРµР»РёС‡РёР» РѕР±С‰СѓСЋ С€РёСЂРёРЅСѓ РїР»Р°СЃС‚РёРЅРєРё (Р±С‹Р»Рѕ 50)
                  height: 56, // РЈРІРµР»РёС‡РёР» РѕР±С‰СѓСЋ РІС‹СЃРѕС‚Сѓ (Р±С‹Р»Рѕ 50)
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
                    // РЈРјРµРЅСЊС€РёР» РѕС‚СЃС‚СѓРї, С‡С‚РѕР±С‹ РєР°СЂС‚РёРЅРєР° Р·Р°РЅСЏР»Р° Р±РѕР»СЊС€Рµ РјРµСЃС‚Р° (Р±С‹Р»Рѕ 8.0)
                    padding: const EdgeInsets.all(3.0),
                    child: ClipOval(
                      child: Image.asset(track.coverAsset, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // РќР°Р·РІР°РЅРёРµ С‚СЂРµРєР° (Р‘РµРіСѓС‰Р°СЏ СЃС‚СЂРѕРєР°)
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
                      
                      // --- Р­С„С„РµРєС‚ РЅР°С‚РёРІРЅРѕРіРѕ РёРЅС‚РµСЂС„РµР№СЃР° (СЂР°СЃС‚РІРѕСЂРµРЅРёРµ РєСЂР°РµРІ) ---
                      fadedBorder: true, 
                      fadedBorderWidth: 0.1, // 10% С€РёСЂРёРЅС‹ РІРёРґР¶РµС‚Р° Р±СѓРґРµС‚ СѓС…РѕРґРёС‚СЊ РІ РїР»Р°РІРЅС‹Р№ РіСЂР°РґРёРµРЅС‚
                      // --------------------------------------------------------

                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Р’РѕСЃРїСЂРѕРёР·РІРµРґРµРЅРёРµ',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // РљРЅРѕРїРєР° РїР»РµР№Р»РёСЃС‚Р°/Р°Р»СЊР±РѕРјРѕРІ
              IconButton(
                icon: Icon(
                  Icons.queue_music_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                tooltip: 'РђР»СЊР±РѕРјС‹',
                onPressed: _showPlaylist,
              ),
            ],
          ),

// РџСЂРѕРіСЂРµСЃСЃ-Р±Р°СЂ РґР»РёС‚РµР»СЊРЅРѕСЃС‚Рё
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    // --- РџРћР”РљР›Р®Р§РђР•Рњ РќРђРЁ РљРђРЎРўРћРњРќР«Р™ РљР›РђРЎРЎ Р’РћР›РќР« ---
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
                  // --- Р’Р•Р РќРЈР›Р РЎРўРђРќР”РђР РўРќР«Р™ SLIDER ---
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



          // Р­Р»РµРјРµРЅС‚С‹ СѓРїСЂР°РІР»РµРЅРёСЏ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded),
                color: Theme.of(context).textTheme.bodyMedium?.color,
                onPressed: prevTrack,
              ),
              Container(
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
              IconButton(
                icon: const Icon(Icons.skip_next_rounded),
                color: Theme.of(context).textTheme.bodyMedium?.color,
                onPressed: nextTrack,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

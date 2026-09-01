// --- Модели данных ---
class AudioTrack {
  final String title;
  final String fileName;
  final String coverAsset;
  final String durationStr;

  AudioTrack({
    required this.title,
    required this.fileName,
    required this.coverAsset,
    required this.durationStr,
  });
}

class Album {
  final String title;
  final String coverAsset;
  final String year;
  final List<AudioTrack> tracks;

  Album({
    required this.title,
    required this.coverAsset,
    required this.year,
    required this.tracks,
  });
}

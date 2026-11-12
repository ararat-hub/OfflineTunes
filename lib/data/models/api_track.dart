class ApiTrack {
  final String id;
  final String title;
  final String artist;
  final String albumCover;
  final String audioUrl;
  final int duration;

  ApiTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.albumCover,
    required this.audioUrl,
    required this.duration,
  });

  factory ApiTrack.fromDeezerJson(Map<String, dynamic> json) {
    return ApiTrack(
      id: json['id'].toString(),
      title: json['title'] ?? 'Без названия',
      artist: json['artist']?['name'] ?? 'Неизвестный исполнитель',
      albumCover: json['album']?['cover_medium'] ?? '',
      audioUrl: json['preview'] ?? '', // Прямая ссылка на MP3 превью
      duration: json['duration'] ?? 0,
    );
  }
}

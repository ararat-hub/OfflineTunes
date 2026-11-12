class SearchTrack {
  final String id;
  final String title;
  final String artist;
  final String audioUrl;
  final String? coverUrl;
  final Duration? duration;

  SearchTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    this.coverUrl,
    this.duration,
  });

  factory SearchTrack.fromJson(Map<String, dynamic> json) {
    return SearchTrack(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Неизвестный трек',
      artist: json['artist'] ?? 'Неизвестный исполнитель',
      audioUrl: json['audioUrl'] ?? json['url'] ?? '',
      coverUrl: json['coverUrl'] ?? json['artworkUrl'],
      duration: json['duration'] != null
          ? Duration(milliseconds: json['duration'])
          : null,
    );
  }
}

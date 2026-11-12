import 'package:path/path.dart' as p;
import '../db/app_database.dart';

class PlaybackTrack {
  final String path;
  final String title;
  final String artist;
  final String? genre;
  final String? sourcePage;
  final String? license;
  final bool youtube;

  const PlaybackTrack(
      {required this.path,
      required this.title,
      required this.artist,
      this.genre,
      this.sourcePage,
      this.license,
      this.youtube = false});

  factory PlaybackTrack.fromTrack(Track track) {
    final local = track.localPath;
    final remote = track.remoteUrl;
    // Older imports stored the file path in the primary key.
    final legacy =
        p.isAbsolute(track.id) || track.id.startsWith('file:') ? track.id : '';
    return PlaybackTrack(
      path: local != null && local.isNotEmpty
          ? local
          : remote != null && remote.isNotEmpty
              ? remote
              : legacy,
      title: track.title,
      artist: track.artist,
      genre: track.genre,
    );
  }

  Map<String, Object?> toJson() => {
        'path': path,
        'title': title,
        'artist': artist,
        'genre': genre,
        'sourcePage': sourcePage,
        'license': license,
        'youtube': youtube,
      };

  factory PlaybackTrack.fromJson(Map<String, dynamic> json) => PlaybackTrack(
        path: json['path'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String,
        genre: json['genre'] as String?,
        sourcePage: json['sourcePage'] as String?,
        license: json['license'] as String?,
        youtube: json['youtube'] == true,
      );
}

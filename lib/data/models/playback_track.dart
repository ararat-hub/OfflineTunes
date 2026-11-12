import 'package:path/path.dart' as p;
import '../db/app_database.dart';

class PlaybackTrack {
  final String path;
  final String title;
  final String artist;

  const PlaybackTrack(
      {required this.path, required this.title, required this.artist});

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
    );
  }
}

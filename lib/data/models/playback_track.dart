import 'package:path/path.dart' as p;
import '../db/app_database.dart';

class PlaybackTrack {
  final String path;
  final String title;
  final String artist;
  final String? genre;
  final String? sourcePage;
  final String? externalProvider;
  final String? license;
  final String? artwork;
  final List<String> artworkAlternatives;
  final String? downloadUrl;
  final bool youtube;
  final String? libraryId;
  final String? originalPath;

  const PlaybackTrack(
      {required this.path,
      required this.title,
      required this.artist,
      this.genre,
      this.sourcePage,
      this.externalProvider,
      this.license,
      this.artwork,
      this.artworkAlternatives = const [],
      this.downloadUrl,
      this.libraryId,
      this.originalPath,
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
      libraryId: track.id,
    );
  }

  Map<String, Object?> toJson() => {
        'path': path,
        'title': title,
        'artist': artist,
        'genre': genre,
        'sourcePage': sourcePage,
        if (externalProvider != null) 'externalProvider': externalProvider,
        'license': license,
        'artwork': artwork,
        if (artworkAlternatives.isNotEmpty)
          'artworkAlternatives': artworkAlternatives,
        'downloadUrl': downloadUrl,
        'libraryId': libraryId,
        'originalPath': originalPath,
        'youtube': youtube,
      };

  factory PlaybackTrack.fromJson(Map<String, dynamic> json) => PlaybackTrack(
        path: json['path'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String,
        genre: json['genre'] as String?,
        sourcePage: json['sourcePage'] as String?,
        externalProvider: json['externalProvider'] as String?,
        license: json['license'] as String?,
        artwork: json['artwork'] as String?,
        artworkAlternatives: (json['artworkAlternatives'] as List?)
                ?.whereType<String>()
                .toList() ??
            const [],
        downloadUrl: json['downloadUrl'] as String?,
        libraryId: json['libraryId'] as String?,
        originalPath: json['originalPath'] as String?,
        youtube: json['youtube'] == true,
      );

  String get identity => originalPath ?? path;

  PlaybackTrack withArtwork(String value) =>
      PlaybackTrack.fromJson({...toJson(), 'artwork': value});

  PlaybackTrack withPath(String value) => PlaybackTrack(
        path: value,
        title: title,
        artist: artist,
        genre: genre,
        sourcePage: sourcePage,
        externalProvider: externalProvider,
        license: license,
        artwork: artwork,
        artworkAlternatives: artworkAlternatives,
        downloadUrl: downloadUrl,
        youtube: youtube,
        libraryId: libraryId,
        originalPath: identity,
      );
}

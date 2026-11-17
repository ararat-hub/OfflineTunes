import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/media_link.dart';
import '../models/music_query.dart';
import '../models/playback_track.dart';
import 'audio_player_service.dart';
import 'music_catalog.dart';

enum CatalogPlaybackResult { started, unavailable, cancelled }

/// Opens the recording itself, using catalogue pages only for attribution.
class CatalogPlayback extends ChangeNotifier {
  CatalogPlayback(this._audio, this._loadLibrary, {http.Client? client})
      : _client = client ?? http.Client();

  final AudioPlayerService _audio;
  final Future<List<PlaybackTrack>> Function() _loadLibrary;
  final http.Client _client;
  late final _catalog = MusicCatalog(_client);
  int _selection = 0;
  bool _disposed = false;
  String? pending;

  static bool needsAudioLookup(PlaybackTrack track) {
    if (track.externalProvider != null) return true;
    if (!track.youtube || track.originalPath == null) return false;
    // Earlier versions saved some catalogue results as YouTube history items.
    final host = Uri.tryParse(track.originalPath!)?.host;
    return const {'deezer.com', 'www.deezer.com', 'music.apple.com'}
        .contains(host);
  }

  Future<CatalogPlaybackResult> play(PlaybackTrack track) async {
    if (pending == track.identity) return CatalogPlaybackResult.cancelled;
    final selection = ++_selection;
    pending = track.identity;
    notifyListeners();
    try {
      var full = await _findLocal(track);
      if (_disposed || selection != _selection) {
        return CatalogPlaybackResult.cancelled;
      }
      full ??= await _findAudiusRecording(track);
      if (_disposed || selection != _selection) {
        return CatalogPlaybackResult.cancelled;
      }
      if (full == null) return CatalogPlaybackResult.unavailable;
      await _audio.playQueue([full]);
      return CatalogPlaybackResult.started;
    } finally {
      if (!_disposed && _selection == selection) {
        pending = null;
        notifyListeners();
      }
    }
  }

  Future<PlaybackTrack?> _findLocal(PlaybackTrack track) async {
    try {
      for (final local in await _loadLibrary()) {
        if (local.path.isEmpty ||
            local.youtube ||
            local.externalProvider != null) {
          continue;
        }
        final uri = Uri.tryParse(local.path);
        if (uri?.isScheme('http') == true || uri?.isScheme('https') == true) {
          continue;
        }
        final title = MediaLink.isDirectAudioFile(Uri(path: local.title))
            ? p.basenameWithoutExtension(local.title)
            : local.title;
        if (!_sameRecording(track, local.artist, title)) {
          continue;
        }
        final file = uri?.isScheme('file') == true
            ? File.fromUri(uri!)
            : File(local.path);
        if (await file.exists()) return local;
      }
    } on Exception catch (error) {
      debugPrint('Find local recording: $error');
    }
    return null;
  }

  bool _sameRecording(PlaybackTrack track, String artist, String title) {
    final wantedArtist = MusicQuery.recordingArtist(track.artist);
    final wantedTitle = MusicQuery.normalize(track.title);
    final actualTitle = MusicQuery.normalize(title);
    return actualTitle ==
            MusicQuery.normalize('${track.artist} ${track.title}') ||
        (actualTitle == wantedTitle &&
            MusicQuery.recordingArtist(artist) == wantedArtist);
  }

  Future<PlaybackTrack?> _findAudiusRecording(PlaybackTrack track) async {
    try {
      final page = await _catalog
          .search('${track.artist} ${track.title}',
              source: CatalogSource.audius)
          .timeout(const Duration(seconds: 4));
      final matching = page.tracks
          .map((entry) => entry.track)
          .where((stream) => _sameRecording(track, stream.artist, stream.title))
          .firstOrNull;
      if (matching == null) return null;
      return PlaybackTrack(
          path: matching.path,
          title: track.title,
          artist: track.artist,
          artwork: track.artwork ?? matching.artwork,
          artworkAlternatives: [
            ...track.artworkAlternatives,
            ...matching.artworkAlternatives
          ],
          sourcePage: matching.sourcePage,
          downloadUrl: matching.downloadUrl,
          originalPath: track.identity);
    } on Exception {
      return null;
    }
  }

  void cancel() {
    _selection++;
    if (pending == null) return;
    pending = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _client.close();
    super.dispose();
  }
}

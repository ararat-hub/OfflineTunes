import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/media_link.dart';
import '../models/music_query.dart';
import '../models/playback_track.dart';
import 'audio_player_service.dart';
import 'music_catalog.dart';
import 'youtube_player_service.dart';

/// Opens the recording itself, using catalogue pages only for attribution.
class CatalogPlayback extends ChangeNotifier {
  CatalogPlayback(this._audio, this._youtube, {http.Client? client})
      : _client = client ?? http.Client();

  static const _officialVideos = <(String, String), String>{
    ('cupsize', 'юра юра'): 'jcrA-YE65fE',
    ('cupsize', 'семнадцать ножевых'): 'Oud0Cy-WNDo',
    ('cupsize', 'будка'): 'tykCBDNLrJY',
    ('кино', 'пачка сигарет'): 'w7GTLIhNO1g',
    ('кино', 'звезда по имени солнце'): 'sME4iAUFYts',
    ('zemfira', 'искала'): 'eN_YiZ4uBe8',
    ('zemfira', 'хочешь'): 'iz6S2a94Gy4',
  };

  final AudioPlayerService _audio;
  final YoutubePlayerService _youtube;
  final http.Client _client;
  late final _catalog = MusicCatalog(_client);
  int _selection = 0;
  bool _disposed = false;
  String? pending;

  static String? officialVideo(PlaybackTrack track) => _officialVideos[(
        MusicQuery.recordingArtist(track.artist),
        MusicQuery.normalize(track.title)
      )];

  Future<void> play(PlaybackTrack track) async {
    final selection = ++_selection;
    pending = track.identity;
    notifyListeners();
    try {
      final known = officialVideo(track);
      if (known != null) {
        await _youtube.open(
          MediaLink.parse('https://www.youtube.com/watch?v=$known'),
          recording: track,
        );
        return;
      }
      final stream = await _findAudiusRecording(track);
      if (_disposed || selection != _selection) return;
      if (stream != null) {
        await _youtube.close();
        if (!_disposed && selection == _selection) {
          await _audio.playQueue([stream]);
        }
      } else {
        await _youtube.searchForRecording(track);
      }
    } finally {
      if (!_disposed && _selection == selection) {
        pending = null;
        notifyListeners();
      }
    }
  }

  Future<PlaybackTrack?> _findAudiusRecording(PlaybackTrack track) async {
    try {
      final page = await _catalog
          .search('${track.artist} ${track.title}',
              source: CatalogSource.audius)
          .timeout(const Duration(seconds: 4));
      final title = MusicQuery.normalize(track.title);
      final artist = MusicQuery.recordingArtist(track.artist);
      final artistAndTitle =
          MusicQuery.normalize('${track.artist} ${track.title}');
      final matching = page.tracks.map((entry) => entry.track).where((stream) {
        final remoteTitle = MusicQuery.normalize(stream.title);
        return remoteTitle == artistAndTitle ||
            (remoteTitle == title &&
                MusicQuery.recordingArtist(stream.artist) == artist);
      }).firstOrNull;
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

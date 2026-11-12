import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';
import '../models/playback_track.dart';

class ListeningHistory extends ChangeNotifier {
  ListeningHistory(this._prefs) {
    final entries = _prefs.getStringList(_key) ?? const [];
    for (final raw in entries.take(100)) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final track = PlaybackTrack.fromJson(json);
        final count = json['count'] as int;
        if (track.path.isNotEmpty && count > 0) {
          _entries.add((track: track, count: count));
        }
      } catch (_) {
        // An invalid entry should not prevent loading the remaining history.
      }
    }
  }

  static const _key = 'listening_history_v1';
  final SharedPreferences _prefs;
  final _entries = <({PlaybackTrack track, int count})>[];
  Future<void> _saving = Future.value();

  List<PlaybackTrack> get recent =>
      _entries.map((entry) => entry.track).toList(growable: false);

  void record(PlaybackTrack track) {
    if (track.path.isEmpty) return;
    final index =
        _entries.indexWhere((entry) => entry.track.path == track.path);
    final previous = index < 0 ? null : _entries.removeAt(index);
    final updated =
        track.sourcePage == null && previous?.track.sourcePage != null
            ? previous!.track
            : track;
    _entries.insert(0, (track: updated, count: (previous?.count ?? 0) + 1));
    if (_entries.length > 100) _entries.removeLast();
    final snapshot = _entries
        .map((entry) =>
            jsonEncode({...entry.track.toJson(), 'count': entry.count}))
        .toList();
    _saving = _saving.then((_) async {
      try {
        await _prefs.setStringList(_key, snapshot);
      } catch (error) {
        debugPrint('Save listening history: $error');
      }
    });
    notifyListeners();
  }

  @visibleForTesting
  Future<void> get saved => _saving;

  List<PlaybackTrack> recommend(List<Track> library) {
    final artists = <String, int>{};
    final genres = <String, int>{};
    void weigh(PlaybackTrack track, int weight) {
      final artist = track.artist.trim().toLowerCase();
      final genre = track.genre?.trim().toLowerCase() ?? '';
      if (artist.isNotEmpty && artist != 'неизвестный исполнитель') {
        artists.update(artist, (value) => value + weight,
            ifAbsent: () => weight);
      }
      if (genre.isNotEmpty) {
        genres.update(genre, (value) => value + weight, ifAbsent: () => weight);
      }
    }

    for (final entry in _entries.take(30)) {
      weigh(entry.track, entry.count.clamp(1, 8));
    }
    for (final track in library.where((item) => item.isFavorite == 1)) {
      weigh(PlaybackTrack.fromTrack(track), 5);
    }
    final played = _entries.map((entry) => entry.track.path).toSet();
    final ranked = <({PlaybackTrack track, int score, DateTime addedAt})>[];
    for (final item in library) {
      final track = PlaybackTrack.fromTrack(item);
      if (track.path.isEmpty || played.contains(track.path)) continue;
      final score = 3 * (artists[track.artist.trim().toLowerCase()] ?? 0) +
          2 * (genres[track.genre?.trim().toLowerCase()] ?? 0);
      if (score > 0) {
        ranked.add((track: track, score: score, addedAt: item.addedAt));
      }
    }
    ranked.sort((a, b) => b.score.compareTo(a.score) != 0
        ? b.score.compareTo(a.score)
        : b.addedAt.compareTo(a.addedAt));
    return ranked.take(30).map((item) => item.track).toList();
  }
}

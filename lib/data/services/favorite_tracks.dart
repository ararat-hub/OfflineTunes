import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';
import '../models/playback_track.dart';

class FavoriteTracks extends ChangeNotifier {
  FavoriteTracks(this._db, this._prefs) {
    for (final entry in _prefs.getStringList(_key) ?? const <String>[]) {
      try {
        final track =
            PlaybackTrack.fromJson(jsonDecode(entry) as Map<String, dynamic>);
        _remote[track.identity] = track;
      } catch (error) {
        debugPrint('Read favorite: $error');
      }
    }
    _subscription = _db.watchFavoriteTracks().listen((rows) {
      _local = rows
          .map(PlaybackTrack.fromTrack)
          .where((track) => track.path.isNotEmpty)
          .toList();
      if (!_disposed) notifyListeners();
    });
  }

  static const _key = 'online_favorites';
  final AppDatabase _db;
  final SharedPreferences _prefs;
  final _remote = <String, PlaybackTrack>{};
  List<PlaybackTrack> _local = [];
  late final StreamSubscription<List<Track>> _subscription;
  bool _disposed = false;
  Future<void> _writes = Future.value();

  List<PlaybackTrack> get tracks =>
      [..._remote.values.toList().reversed, ..._local];
  bool contains(PlaybackTrack track) =>
      _remote.containsKey(track.identity) ||
      _local.any((favorite) => favorite.identity == track.identity);

  Future<void> toggle(PlaybackTrack track) {
    final operation = _writes.then((_) async {
      if (track.libraryId != null) {
        final row = await _db.getTrackById(track.libraryId!);
        if (row != null) await _db.setFavorite(row.id, row.isFavorite != 1);
        return;
      }
      final previous = Map.of(_remote);
      if (_remote.remove(track.identity) == null) {
        _remote[track.identity] =
            track.originalPath == null ? track : track.withPath(track.identity);
      }
      try {
        if (!await _prefs.setStringList(
            _key, _remote.values.map((v) => jsonEncode(v.toJson())).toList())) {
          throw StateError('Could not save favorites');
        }
      } catch (_) {
        _remote
          ..clear()
          ..addAll(previous);
        rethrow;
      }
      if (!_disposed) notifyListeners();
    });
    _writes =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

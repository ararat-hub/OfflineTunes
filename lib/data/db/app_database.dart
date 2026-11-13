import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
    tables: [Tracks, Playlists, PlaylistTracks, Favorites, SmartRules])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Stream<List<Track>> watchAllTracks() => select(tracks).watch();
  Stream<List<Track>> watchFavoriteTracks() {
    final query = select(tracks)..where((t) => t.isFavorite.equals(1));
    return query.watch();
  }

  Stream<List<Playlist>> watchAllPlaylists() => select(playlists).watch();

  Future<int> insertTrack(TracksCompanion track) =>
      into(tracks).insertOnConflictUpdate(track);
  Future<List<Track>> getAllTracks() => select(tracks).get();
  Future<Track?> getTrackById(String id) =>
      (select(tracks)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<int> deleteTrackById(String id) =>
      (delete(tracks)..where((t) => t.id.equals(id))).go();

  Future<int> setFavorite(String id, bool favorite) =>
      (update(tracks)..where((row) => row.id.equals(id)))
          .write(TracksCompanion(isFavorite: Value(favorite ? 1 : 0)));

  Future<List<Track>> searchTracks(String query) async {
    final words = query.toLowerCase().trim().split(RegExp(r'\s+'));
    final local = await getAllTracks();
    return local
        .where((track) {
          final searchable =
              '${track.title} ${track.artist} ${track.album ?? ''} ${track.genre ?? ''}'
                  .toLowerCase();
          return words.every(searchable.contains);
        })
        .take(150)
        .toList();
  }

  @override
  Future<void> close() async {
    await super.close();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'offlinetunes.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

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

  Future<List<Track>> searchTracks(String query) {
    final search = '%${query.toLowerCase()}%';
    return (select(tracks)
          ..where((t) =>
              t.title.lower().like(search) | t.artist.lower().like(search)))
        .get();
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

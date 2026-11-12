import 'package:drift/drift.dart';

class Tracks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get album => text().nullable()();
  TextColumn get genre => text().nullable()();
  IntColumn get year => integer().nullable()();
  IntColumn get trackNumber => integer().nullable()();
  IntColumn get bitRate => integer().nullable()();
  IntColumn get sampleRate => integer().nullable()();
  TextColumn get format => text().nullable()();
  IntColumn get fileSize => integer().nullable()();
  TextColumn get source => text().nullable()();
  IntColumn get duration => integer().withDefault(const Constant(0))();
  TextColumn get localPath => text().nullable()();
  TextColumn get remoteUrl => text().nullable()();
  IntColumn get isFavorite => integer().withDefault(const Constant(0))();
  IntColumn get isDownloaded => integer().withDefault(const Constant(0))();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Playlists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class PlaylistTracks extends Table {
  TextColumn get playlistId => text()();
  TextColumn get trackId => text()();

  @override
  Set<Column> get primaryKey => {playlistId, trackId};
}

class Favorites extends Table {
  TextColumn get trackId => text()();

  @override
  Set<Column> get primaryKey => {trackId};
}

class SmartRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get conditionJson => text()();
}

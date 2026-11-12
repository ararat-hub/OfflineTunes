import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:uuid/uuid.dart';
import '../db/app_database.dart';

class AudioScannerService {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();

  AudioScannerService(this.db);

  Future<void> scanDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return;

    final List<FileSystemEntity> files = dir.listSync(recursive: true);

    for (final file in files) {
      if (file is File && _isAudioFile(file.path)) {
        await _processFile(file);
      }
    }
  }

  bool _isAudioFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp3', 'm4a', 'flac', 'wav', 'aac', 'ogg'].contains(ext);
  }

  Future<void> _processFile(File file) async {
    try {
      final metadata = await MetadataRetriever.fromFile(file);
      final fileSize = await file.length();
      final ext = file.path.split('.').last.toLowerCase();

      final trackCompanion = TracksCompanion(
        id: Value(_uuid.v4()),
        title: Value(
            metadata.trackName ?? file.path.split(Platform.pathSeparator).last),
        artist:
            Value(metadata.trackArtistNames?.join(', ') ?? 'Unknown Artist'),
        album: Value(metadata.albumName),
        genre: Value(metadata.genre),
        year: Value(metadata.year),
        trackNumber: Value(metadata.trackNumber),
        bitRate: Value(metadata.bitrate),
        format: Value(ext),
        fileSize: Value(fileSize),
        source: const Value('local'),
        duration: Value(metadata.trackDuration ?? 0),
        localPath: Value(file.path),
        isDownloaded: const Value(1),
      );

      await db.insertTrack(trackCompanion);
    } catch (e) {
      // Игнорируем поврежденные файлы
    }
  }
}

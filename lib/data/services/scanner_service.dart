import 'dart:io';
import 'package:audiotags/audiotags.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../db/app_database.dart';
import '../models/playback_track.dart';
import 'track_artwork_store.dart';

class ScannerService {
  final AppDatabase db;

  ScannerService(this.db);

  static const audioExtensions = [
    'mp3',
    'flac',
    'm4a',
    'wav',
    'ogg',
    'opus',
    'aac'
  ];
  static const audioFileTypes = [
    XTypeGroup(extensions: audioExtensions, mimeTypes: ['audio/*'])
  ];

  Future<String?> importPickedAudio(XFile file,
      {PlaybackTrack? recording}) async {
    final extension = p.extension(file.name).toLowerCase();
    if (!audioExtensions.contains(extension.replaceFirst('.', ''))) return null;
    final folder = Directory(p.join(
        (await getApplicationSupportDirectory()).path, 'imported_music'));
    await folder.create(recursive: true);
    final destination =
        File(p.join(folder.path, '${const Uuid().v4()}$extension'));
    try {
      await file.saveTo(destination.path);
      if (await importAudioFile(destination.path,
          originalName: file.name, recording: recording)) {
        if (recording != null) {
          await TrackArtworkStore.saveForAudio(recording, destination.path);
        }
        return destination.path;
      }
    } catch (error) {
      debugPrint('Copy audio file: $error');
    }
    if (await destination.exists()) await destination.delete();
    return null;
  }

  Future<int> scanDirectory(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return 0;

    int addedCount = 0;
    await for (final file in dir.list(recursive: true, followLinks: false)) {
      if (file is File) {
        final ext = file.path.split('.').last.toLowerCase();
        if (['mp3', 'flac', 'm4a', 'wav', 'ogg'].contains(ext)) {
          final isAdded = await importAudioFile(file.path);
          if (isAdded) addedCount++;
        }
      }
    }

    return addedCount;
  }

  Future<bool> importAudioFile(String filePath,
      {String? originalName, PlaybackTrack? recording}) async {
    try {
      Tag? tag;
      try {
        tag = await AudioTags.read(filePath);
      } catch (e) {
        debugPrint('Не удалось прочитать теги $filePath: $e');
      }

      final title = (tag?.title != null && tag!.title!.isNotEmpty)
          ? tag.title!
          : originalName ?? filePath.split('\\').last.split('/').last;

      final artist = (tag?.trackArtist != null && tag!.trackArtist!.isNotEmpty)
          ? tag.trackArtist!
          : 'Неизвестный исполнитель';

      final album = tag?.album ?? 'Неизвестный альбом';
      final duration = tag?.duration ?? 0;

      await db.into(db.tracks).insertOnConflictUpdate(
            TracksCompanion.insert(
              id: filePath,
              title: recording?.title ?? title,
              artist: recording?.artist ?? artist,
              album: Value(album),
              duration: Value(duration),
              localPath: Value(filePath),
              source: const Value('local'),
              isDownloaded: const Value(1),
            ),
          );

      return true;
    } catch (e) {
      debugPrint('Ошибка при сканировании файла $filePath: $e');
      return false;
    }
  }
}

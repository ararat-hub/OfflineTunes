import 'dart:io';
import 'package:audiotags/audiotags.dart';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../db/app_database.dart';

class ScannerService {
  final AppDatabase db;

  ScannerService(this.db);

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

  Future<bool> importAudioFile(String filePath, {String? originalName}) async {
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
              title: title,
              artist: artist, // Передаем обычную строку
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

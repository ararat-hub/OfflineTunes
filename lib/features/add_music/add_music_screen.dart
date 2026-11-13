import '../../core/localization.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../data/db/app_database.dart';
import '../../data/services/scanner_service.dart';
import '../../widgets/open_link_card.dart';

class AddMusicScreen extends StatefulWidget {
  const AddMusicScreen({super.key});

  @override
  State<AddMusicScreen> createState() => _AddMusicScreenState();
}

class _AddMusicScreenState extends State<AddMusicScreen> {
  bool _isScanning = false;
  String _statusMessage = 'Выберите папку на ПК для сканирования аудиофайлов';
  int? _addedCount;

  Future<void> _selectAndScanDirectory(BuildContext context) async {
    final String? directoryPath = await getDirectoryPath();

    if (directoryPath == null || !context.mounted || !mounted) return;

    setState(() {
      _isScanning = true;
      _addedCount = null;
      _statusMessage = 'Сканируем папку…';
    });

    final db = Provider.of<AppDatabase>(context, listen: false);
    final scanner = ScannerService(db);

    try {
      final addedCount = await scanner.scanDirectory(directoryPath);
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Обработано треков: {count}';
        _addedCount = addedCount;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Scan folder: $e');
      setState(() => _statusMessage = 'Не удалось отсканировать папку.');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _importFiles() async {
    final scanner = ScannerService(context.read<AppDatabase>());
    setState(() {
      _isScanning = true;
      _addedCount = null;
    });
    try {
      const extensions = ['mp3', 'flac', 'm4a', 'wav', 'ogg', 'opus', 'aac'];
      final files = await openFiles(acceptedTypeGroups: const [
        XTypeGroup(extensions: extensions, mimeTypes: ['audio/*'])
      ]);
      if (files.isEmpty || !mounted) return;
      final folder = Directory(p.join(
          (await getApplicationSupportDirectory()).path, 'imported_music'));
      await folder.create(recursive: true);
      var added = 0;
      for (final file in files) {
        final extension = p.extension(file.name).toLowerCase();
        if (!extensions.contains(extension.replaceFirst('.', ''))) continue;
        final destination =
            File(p.join(folder.path, '${const Uuid().v4()}$extension'));
        try {
          await file.saveTo(destination.path);
          if (await scanner.importAudioFile(destination.path,
              originalName: file.name)) {
            added++;
          } else {
            await destination.delete();
          }
        } catch (_) {
          if (await destination.exists()) await destination.delete();
        }
      }
      if (mounted) {
        setState(() {
          _addedCount = added;
          _statusMessage = 'Обработано треков: {count}';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _statusMessage = 'Не удалось открыть файл оформления.');
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: ListView(
          children: [
            const OpenLinkCard(),
            const SizedBox(height: 28),
            const Divider(color: Colors.white12),
            const SizedBox(height: 24),
            Text(
              context.tr('Добавить с устройства'),
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                  Platform.isAndroid &&
                          _addedCount == null &&
                          !_isScanning &&
                          _statusMessage ==
                              'Выберите папку на ПК для сканирования аудиофайлов'
                      ? 'Выбрать аудиофайлы'
                      : _statusMessage,
                  {
                    if (_addedCount != null) 'count': _addedCount!,
                  }),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isScanning
                  ? null
                  : Platform.isAndroid
                      ? _importFiles
                      : () => _selectAndScanDirectory(context),
              icon: _isScanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.folder_open),
              label: Text(_isScanning
                  ? context.tr('Сканирование...')
                  : context.tr(Platform.isAndroid
                      ? 'Выбрать аудиофайлы'
                      : 'Выбрать папку')),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

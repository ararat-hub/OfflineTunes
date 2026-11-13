import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/playback_track.dart';
import 'music_catalog.dart';

class OfflineTracks extends ChangeNotifier {
  OfflineTracks({http.Client? client, Future<Directory> Function()? directory})
      : _client = client ?? http.Client(),
        _directory = directory ?? getApplicationSupportDirectory {
    ready = _load().catchError((Object error) {
      _initializationError = error;
      debugPrint('Open downloads: $error');
      _changed();
    });
  }

  final http.Client _client;
  final Future<Directory> Function() _directory;
  late final Future<void> ready;
  late final Directory _root;
  final _downloads = <String, ({PlaybackTrack track, File metadata})>{};
  final _active = <String, double?>{};
  bool _disposed = false;
  Object? _initializationError;
  static const _maxBytes = 256 * 1024 * 1024;

  List<PlaybackTrack> get tracks =>
      _downloads.values.map((v) => v.track).toList().reversed.toList();
  bool contains(String path) => _downloads.containsKey(path);
  bool isLoading(String path) => _active.containsKey(path);
  double? progress(String path) => _active[path];
  PlaybackTrack localOrOriginal(PlaybackTrack track) =>
      _downloads[track.identity]?.track ?? track;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _load() async {
    _root = Directory(p.join((await _directory()).path, 'downloads'));
    await _root.create(recursive: true);
    final files = await _root
        .list()
        .where((entry) => entry is File && entry.path.endsWith('.json'))
        .cast<File>()
        .toList();
    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
    for (final file in files) {
      try {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final name = json['file'] as String;
        if (p.basename(name) != name) continue;
        final audio = File(p.join(_root.path, name));
        if (await audio.exists()) {
          final track = PlaybackTrack.fromJson(json);
          _downloads[track.path] =
              (track: track.withPath(audio.path), metadata: file);
        }
      } catch (error) {
        debugPrint('Load download metadata: $error');
      }
    }
    _changed();
  }

  Future<void> download(PlaybackTrack track) async {
    await ready;
    if (_initializationError != null) {
      throw StateError('Download storage is unavailable');
    }
    final uri = Uri.tryParse(track.downloadUrl ?? '');
    if (track.youtube ||
        uri == null ||
        uri.scheme != 'https' ||
        !const {'api.audius.co', 'upload.wikimedia.org'}.contains(uri.host) ||
        contains(track.path) ||
        isLoading(track.path)) {
      return;
    }
    _active[track.path] = null;
    _changed();
    final id = const Uuid().v4();
    final pending = File(p.join(_root.path, '$id.part'));
    final manifest = File(p.join(_root.path, '$id.pending'));
    File? audio;
    var committed = false;
    try {
      final request = http.Request('GET', uri)
        ..headers['User-Agent'] = MusicCatalog.userAgent;
      final response =
          await _client.send(request).timeout(const Duration(seconds: 25));
      final mime =
          response.headers['content-type']?.split(';').first.trim() ?? '';
      if (response.statusCode != 200 ||
          !(mime.startsWith('audio/') ||
              mime == 'application/ogg' ||
              mime == 'application/octet-stream')) {
        final subscription = response.stream.listen((_) {});
        await subscription.cancel();
        throw const FormatException('The catalog did not return an audio file');
      }
      final length = response.contentLength;
      final extension = uri.host == 'api.audius.co'
          ? '.mp3'
          : p.extension(uri.path).toLowerCase();
      final name =
          '$id${RegExp(r'^\.[a-z0-9]{1,6}$').hasMatch(extension) ? extension : '.audio'}';
      var received = 0;
      var lastPercent = -1;
      final sink = pending.openWrite();
      try {
        await sink.addStream(
            response.stream.timeout(const Duration(seconds: 30)).map((chunk) {
          received += chunk.length;
          if (received > _maxBytes) {
            throw const FormatException('Track exceeds the download limit');
          }
          if (length != null && length > 0) {
            final percent = (received * 100 ~/ length).clamp(0, 100);
            if (percent != lastPercent) {
              lastPercent = percent;
              _active[track.path] = percent / 100;
              _changed();
            }
          }
          return chunk;
        }));
      } finally {
        await sink.close();
      }
      if (received == 0 || (length != null && received != length)) {
        throw const FormatException('Incomplete download');
      }
      audio = await pending.rename(p.join(_root.path, name));
      await manifest.writeAsString(
          jsonEncode({...track.toJson(), 'file': name}),
          flush: true);
      final metadata = await manifest.rename(p.join(_root.path, '$id.json'));
      _downloads[track.path] =
          (track: track.withPath(audio.path), metadata: metadata);
      committed = true;
    } finally {
      _active.remove(track.path);
      _changed();
      if (!committed) {
        for (final file in [pending, manifest, if (audio != null) audio]) {
          try {
            if (await file.exists()) await file.delete();
          } on FileSystemException {/* Temporary file can be removed later. */}
        }
      }
    }
  }

  Future<void> remove(PlaybackTrack track) async {
    await ready;
    if (_initializationError != null) {
      throw StateError('Download storage is unavailable');
    }
    for (final entry in _downloads.entries.toList()) {
      if (entry.value.track.path != track.path) continue;
      final audio = File(track.path);
      if (await audio.exists()) await audio.delete();
      if (await entry.value.metadata.exists()) {
        await entry.value.metadata.delete();
      }
      _downloads.remove(entry.key);
      _changed();
      break;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _client.close();
    super.dispose();
  }
}

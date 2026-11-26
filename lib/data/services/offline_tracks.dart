import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/playback_track.dart';
import '../models/media_link.dart';
import 'music_catalog.dart';
import 'track_artwork_store.dart';
import 'zaycev_streams.dart';

class OfflineTracks extends ChangeNotifier {
  OfflineTracks(
      {http.Client? client,
      Future<Directory> Function()? directory,
      Future<File?> Function(PlaybackTrack)? artwork})
      : _client = client ?? http.Client(),
        _directory = directory ?? getApplicationSupportDirectory,
        _artwork = artwork ?? ((track) => TrackArtworkStore.resolve(track)) {
    ready = _load().catchError((Object error) {
      _initializationError = error;
      debugPrint('Open downloads: $error');
    }).whenComplete(() {
      _restoring = false;
      _changed();
    });
  }

  final http.Client _client;
  late final _zaycev = ZaycevStreams(_client);
  final Future<Directory> Function() _directory;
  final Future<File?> Function(PlaybackTrack) _artwork;
  late final Future<void> ready;
  late final Directory _root;
  final _downloads = <String, ({PlaybackTrack track, File metadata})>{};
  final _active = <String, double?>{};
  bool _disposed = false;
  bool _restoring = true;
  bool get restoring => _restoring;
  bool get storageUnavailable => _initializationError != null;
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
          var track = PlaybackTrack.fromJson(json);
          final cover = _cover(file);
          if (await cover.exists()) track = track.withArtwork(cover.path);
          _downloads[track.identity] =
              (track: track.withPath(audio.path), metadata: file);
        }
      } catch (error) {
        debugPrint('Load download metadata: $error');
      }
    }
    _changed();
    unawaited(_restoreArtwork());
  }

  File _cover(File metadata) => File(p.join(
      _root.path, '${p.basenameWithoutExtension(metadata.path)}.art.png'));

  Future<void> _restoreArtwork() async {
    for (final entry in _downloads.entries.toList()) {
      if (_disposed) return;
      final previous = entry.value;
      if (await _cover(previous.metadata).exists()) continue;
      final track = await _saveArtwork(previous.track, previous.metadata);
      if (_downloads[entry.key] == previous && !_disposed) {
        _downloads[entry.key] = (track: track, metadata: previous.metadata);
        _changed();
      } else if (!_downloads.containsKey(entry.key)) {
        final cover = _cover(previous.metadata);
        if (await cover.exists()) await cover.delete();
      }
    }
  }

  Future<PlaybackTrack> _saveArtwork(PlaybackTrack track, File metadata) async {
    try {
      final image = await _artwork(track);
      if (image == null || !await image.exists()) return track;
      final cover = _cover(metadata);
      final temporary = File('${cover.path}.pending');
      await image.copy(temporary.path);
      await temporary.rename(cover.path);
      return track.withArtwork(cover.path);
    } on Exception {
      return track;
    }
  }

  Future<void> download(PlaybackTrack track) async {
    await ready;
    if (_initializationError != null) {
      throw StateError('Download storage is unavailable');
    }
    var uri = Uri.tryParse(track.downloadUrl ?? '');
    final fromZaycev = MediaLink.zaycevTrackId(track.downloadUrl ?? '') != null;
    final catalog = uri != null &&
        const {'api.audius.co', 'upload.wikimedia.org'}.contains(uri.host);
    if (track.youtube ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        (!catalog && !fromZaycev && !MediaLink.isDirectAudioFile(uri)) ||
        MediaLink.isStorePreview(uri)) {
      throw const FormatException(
          'The link does not provide a downloadable audio file');
    }
    final identity = track.identity;
    if (contains(identity) || isLoading(identity)) return;
    _active[identity] = null;
    _changed();
    final id = const Uuid().v4();
    final pending = File(p.join(_root.path, '$id.part'));
    final manifest = File(p.join(_root.path, '$id.pending'));
    File? audio;
    var committed = false;
    try {
      if (fromZaycev) {
        final resolved = await _zaycev.resolveDownload(uri.toString());
        if (resolved == null) {
          throw const FormatException('The source did not permit a download');
        }
        uri = Uri.parse(resolved);
      }
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
              _active[identity] = percent / 100;
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
      final extension = await _extension(pending, uri);
      final name = '$id$extension';
      audio = await pending.rename(p.join(_root.path, name));
      await manifest.writeAsString(
          jsonEncode({...track.toJson(), 'file': name}),
          flush: true);
      final metadata = await manifest.rename(p.join(_root.path, '$id.json'));
      final local = await _saveArtwork(track.withPath(audio.path), metadata);
      _downloads[identity] = (track: local, metadata: metadata);
      committed = true;
    } finally {
      _active.remove(identity);
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

  Future<String> _extension(File file, Uri uri) async {
    final source = await file.open();
    try {
      final header = await source.read(12);
      final signature = String.fromCharCodes(header);
      if (signature.startsWith('fLaC')) return '.flac';
      if (signature.startsWith('OggS')) return '.ogg';
      if (signature.startsWith('RIFF') && signature.endsWith('WAVE')) {
        return '.wav';
      }
      if (header.length > 8 && signature.substring(4, 8) == 'ftyp') {
        return '.m4a';
      }
      if (signature.startsWith('ID3') ||
          (header.length >= 2 &&
              header[0] == 0xff &&
              (header[1] & 0xe0) == 0xe0)) {
        return '.mp3';
      }
      final extension = p.extension(uri.path).toLowerCase();
      return MediaLink.isDirectAudioFile(uri) ? extension : '.audio';
    } finally {
      await source.close();
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
      final cover = _cover(entry.value.metadata);
      if (await cover.exists()) await cover.delete();
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

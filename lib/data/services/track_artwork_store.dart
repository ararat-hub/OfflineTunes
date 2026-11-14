import 'dart:async';
import 'dart:io' hide BytesBuilder;
import 'dart:typed_data' show BytesBuilder, Uint8List;
import 'dart:ui' as ui;

import 'package:audiotags/audiotags.dart';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../theme/theme_provider.dart';
import '../models/playback_track.dart';

class TrackArtworkStore {
  static const _maxBytes = 8 * 1024 * 1024;
  static final _requests = <String, Future<File?>>{};
  static final _client = http.Client();
  static const _thumbnails = MethodChannel('otune/background_thumbnail');

  static bool _local(String path) {
    final uri = Uri.tryParse(path);
    return path.isNotEmpty && (p.isAbsolute(path) || uri?.scheme == 'file');
  }

  static Future<File?> resolve(PlaybackTrack track, {String? background}) {
    final images = {
      if (track.artwork != null) track.artwork!,
      ...track.artworkAlternatives
    };
    final local = _local(track.path) ? track.path : '';
    if (images.isEmpty && local.isEmpty && background == null) {
      return Future.value();
    }
    final key = [background, ...images, local].join('\n');
    if (_requests.length >= 128 && !_requests.containsKey(key)) {
      _requests.remove(_requests.keys.first);
    }
    return _requests.putIfAbsent(key, () async {
      File? file;
      try {
        final root = Directory(
            p.join((await getTemporaryDirectory()).path, 'track_artwork'));
        final saved = File(p.join(
            root.path, '${const Uuid().v5(Namespace.url.value, key)}.png'));
        if (await saved.exists()) {
          file = saved;
        } else if (background != null) {
          file = await _candidate(saved, () => _background(background)) ??
              await resolve(track);
        } else {
          file = await _resolve(images, local, saved);
        }
      } catch (_) {
        // The fallback icon remains available when the cache directory fails.
      }
      // Keep a small in-flight map. The image is read from disk on later calls.
      _requests.remove(key);
      return file;
    });
  }

  static Future<File?> _resolve(
      Set<String> images, String local, File saved) async {
    for (final url in images) {
      final image = await _candidate(saved, () => _download(url));
      if (image != null) return image;
    }
    if (local.isEmpty) return null;
    return _candidate(saved, () async {
      final path =
          local.startsWith('file:') ? Uri.parse(local).toFilePath() : local;
      final pictures = (await AudioTags.read(path))?.pictures ?? [];
      final picture = pictures
              .where((p) => p.pictureType == PictureType.coverFront)
              .firstOrNull ??
          pictures.firstOrNull;
      return picture?.bytes;
    });
  }

  static Future<Uint8List?> _background(String path) async {
    if (path.startsWith('asset:///')) {
      final frame =
          await rootBundle.load('assets/backgrounds/aurora-preview.jpg');
      return frame.buffer.asUint8List(frame.offsetInBytes, frame.lengthInBytes);
    }
    if (ThemeProvider.videoExtensions
        .contains(p.extension(path).toLowerCase().replaceFirst('.', ''))) {
      return _thumbnails.invokeMethod<Uint8List>('frame', path);
    }
    final file = File(path);
    return await file.length() <= _maxBytes ? file.readAsBytes() : null;
  }

  static Future<Uint8List?> _download(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    final response = await _client
        .send(http.Request('GET', uri))
        .timeout(const Duration(seconds: 4));
    if (response.statusCode != 200 ||
        (response.contentLength ?? 0) > _maxBytes) {
      await response.stream.listen((_) {}).cancel();
      return null;
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk
        in response.stream.timeout(const Duration(seconds: 4))) {
      bytes.add(chunk);
      if (bytes.length > _maxBytes) return null;
    }
    return bytes.takeBytes();
  }

  static Future<File?> _candidate(
      File saved, Future<Uint8List?> Function() load) async {
    try {
      final bytes = await load();
      if (bytes == null || bytes.isEmpty || bytes.length > _maxBytes) {
        return null;
      }
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 384);
      try {
        final image = (await codec.getNextFrame()).image;
        try {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          if (png == null) return null;
          final root = saved.parent;
          await root.create(recursive: true);
          final files = await root
              .list()
              .where((entry) => entry is File)
              .cast<File>()
              .toList();
          if (files.length >= 192) {
            files.sort(
                (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
            for (final stale in files.take(32)) {
              try {
                await stale.delete();
              } on FileSystemException {
                // A cover can still be in use by the system player.
              }
            }
          }
          final temp = File('${saved.path}.tmp');
          await temp.writeAsBytes(png.buffer.asUint8List());
          return await temp.rename(saved.path);
        } finally {
          image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (_) {
      return null;
    }
  }
}

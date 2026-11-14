import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../theme/theme_provider.dart';

class BackgroundThumbnail extends StatelessWidget {
  const BackgroundThumbnail({super.key, required this.path, this.width = 88});

  final String path;
  final double width;
  static final _frames = <String, Future<Uint8List?>>{};
  static Future<void> _queue = Future.value();
  static const _channel = MethodChannel('otune/background_thumbnail');

  static bool isVideo(String path) => ThemeProvider.videoExtensions
      .contains(p.extension(path).toLowerCase().replaceFirst('.', ''));

  static Future<Uint8List?> _loadFrame(String path) {
    if (_frames.length >= 64 && !_frames.containsKey(path)) {
      _frames.remove(_frames.keys.first);
    }
    return _frames.putIfAbsent(path, () {
      final frame = _queue.then((_) async {
        try {
          return await _channel.invokeMethod<Uint8List>('frame', path);
        } catch (_) {
          return null;
        }
      });
      _queue = frame.then<void>((_) {});
      return frame;
    });
  }

  @override
  Widget build(BuildContext context) {
    final video = isVideo(path);
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
          child: Icon(
              video ? Icons.videocam_outlined : Icons.broken_image_outlined)),
    );
    final Widget preview;
    if (path.startsWith('asset:///')) {
      preview = Image.asset('assets/backgrounds/aurora-preview.jpg',
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
    } else if (video) {
      preview = FutureBuilder<Uint8List?>(
          future: _loadFrame(path),
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            return bytes == null
                ? fallback
                : Image.memory(bytes,
                    fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
          });
    } else {
      preview = Image.file(File(path),
          fit: BoxFit.cover,
          cacheWidth: 256,
          errorBuilder: (_, __, ___) => fallback);
    }
    return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: width,
          height: width * .60,
          child: Stack(fit: StackFit.expand, children: [
            preview,
            if (video)
              const Positioned(
                  right: 4,
                  bottom: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child: Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(Icons.play_arrow,
                            size: 12, color: Colors.white)),
                  )),
          ]),
        ));
  }
}

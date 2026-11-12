import '../core/localization.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/theme_provider.dart';

class AppBackdrop extends StatefulWidget {
  final ThemeProvider theme;
  final bool compact;
  const AppBackdrop({super.key, required this.theme, this.compact = false});
  @override
  State<AppBackdrop> createState() => _AppBackdropState();
}

class _AppBackdropState extends State<AppBackdrop> with WindowListener {
  static const _ambientPeriod = Duration(seconds: 28);
  final _ambientTime = Stopwatch();
  final _ambientPhase = ValueNotifier(0.0);
  Timer? _ambientTimer;
  Player? _player;
  VideoController? _video;
  StreamSubscription<String>? _errors;
  StreamSubscription<Duration>? _durations;
  String? _error;
  String? _path;
  VideoLoop? _loadedLoop;
  (String?, bool, VideoLoop?) _requestedVideo = (null, false, null);
  Future<void> _operations = Future.value();
  bool _minimized = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) windowManager.addListener(this);
    _sync();
  }

  @override
  void didUpdateWidget(covariant AppBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final theme = widget.theme;
    final backgroundType = theme.backgroundType(compact: widget.compact);
    final animate = theme.motion && !_minimized;
    if (animate && backgroundType == BackgroundType.ambient) {
      _ambientTime.start();
      _ambientTimer ??= Timer.periodic(const Duration(milliseconds: 33), (_) {
        final period = _ambientPeriod.inMilliseconds;
        _ambientPhase.value =
            (_ambientTime.elapsedMilliseconds % period) / period;
      });
    } else {
      _ambientTimer?.cancel();
      _ambientTimer = null;
      _ambientTime.stop();
    }
    final path = backgroundType == BackgroundType.video
        ? theme.mediaPath(compact: widget.compact)
        : null;
    final loop = path == null ? null : theme.videoLoop(compact: widget.compact);
    final request = (path, path != null && animate, loop);
    if (_requestedVideo == request) return;
    _requestedVideo = request;
    _operations = _operations.then((_) async {
      if (!mounted || request != _requestedVideo) return;
      try {
        if (path == null) {
          await _releaseVideo();
          return;
        }
        if (_path != path || _loadedLoop != loop) {
          if (!path.startsWith('asset:///') && !await File(path).exists()) {
            throw const FileSystemException('Видеофайл перемещён или удалён');
          }
          if (!mounted || request != _requestedVideo) return;
          _player ??= Player(
              configuration:
                  const PlayerConfiguration(title: 'oTune Background'));
          _video ??= VideoController(_player!,
              configuration: const VideoControllerConfiguration(
                  enableHardwareAcceleration: true));
          _errors ??= _player!.stream.error.listen((message) {
            if (mounted && _requestedVideo.$1 != null) {
              debugPrint('Video background: $message');
              setState(() =>
                  _error = 'Видеофон недоступен. Выберите файл в оформлении.');
            }
          });
          _durations ??= _player!.stream.duration.listen((duration) {
            final source = _requestedVideo.$1;
            final playlist = _player?.state.playlist.medias;
            if (mounted &&
                source != null &&
                playlist?.length == 1 &&
                playlist!.first.uri == Media(source).uri) {
              widget.theme.noteBackgroundDuration(source, duration);
            }
          });
          setState(() => _error = null);
          await _player!.setVolume(0);
          await _player!.setPlaylistMode(PlaylistMode.single);
          await _player!.open(
            Media(
              path,
              start: loop!.from > 0 ? Duration(seconds: loop.from) : null,
              end: loop.to == null ? null : Duration(seconds: loop.to!),
            ),
            play: _requestedVideo.$2,
          );
          _path = path;
          _loadedLoop = loop;
        } else if (animate) {
          await _player!.play();
        } else {
          await _player!.pause();
        }
      } catch (e) {
        await _releaseVideo();
        if (mounted && _requestedVideo.$1 == path) {
          debugPrint('Open video background: $e');
          setState(() =>
              _error = 'Видеофон недоступен. Выберите файл в оформлении.');
        }
      }
    });
  }

  Future<void> _releaseVideo() async {
    final player = _player;
    final errors = _errors;
    final durations = _durations;
    _player = null;
    _errors = null;
    _durations = null;
    _path = null;
    _loadedLoop = null;
    _video = null;
    _error = null;
    if (mounted && player != null) setState(() {});
    try {
      await errors?.cancel();
      await durations?.cancel();
      await player?.dispose();
    } catch (e) {
      debugPrint('Не удалось освободить видеофон: $e');
    }
  }

  @override
  void onWindowMinimize() {
    _minimized = true;
    _sync();
  }

  @override
  void onWindowRestore() {
    _minimized = false;
    _sync();
  }

  @override
  void dispose() {
    if (Platform.isWindows) windowManager.removeListener(this);
    _ambientTimer?.cancel();
    _ambientPhase.dispose();
    unawaited(_operations.then((_) => _releaseVideo()));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final mediaPath = theme.mediaPath(compact: widget.compact);
    final backgroundType = theme.backgroundType(compact: widget.compact);
    Widget background = CustomPaint(
        painter: _AmbientPainter(theme.preset.colors, _ambientPhase),
        size: Size.infinite);
    if (backgroundType == BackgroundType.color) {
      background = ColoredBox(color: theme.backgroundColor);
    }
    if (backgroundType == BackgroundType.image && mediaPath != null) {
      background = Image.file(File(mediaPath),
          fit: theme.backgroundFit,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => ColoredBox(
              color: theme.backgroundColor,
              child: Center(
                  child: Text(context.tr(
                      'Фоновое изображение недоступно. Выберите файл в оформлении.')))));
    }
    if (backgroundType == BackgroundType.video &&
        _video != null &&
        _error == null) {
      background = Video(
          controller: _video!,
          fit: theme.backgroundFit,
          controls: NoVideoControls,
          filterQuality: FilterQuality.high,
          wakelock: false,
          pauseUponEnteringBackgroundMode: false,
          resumeUponEnteringForegroundMode: false);
    }
    if (theme.blur > 0) {
      background = ImageFiltered(
          imageFilter:
              ui.ImageFilter.blur(sigmaX: theme.blur, sigmaY: theme.blur),
          child: background);
    }
    return Stack(fit: StackFit.expand, children: [
      ColoredBox(color: theme.backgroundColor),
      RepaintBoundary(child: background),
      ColoredBox(
          color: Colors.black
              .withValues(alpha: widget.compact ? theme.widgetDim : theme.dim)),
      if (_error != null && backgroundType == BackgroundType.video)
        Positioned(
            left: 16,
            right: 16,
            bottom: 8,
            child: Text(context.tr(_error!),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.white70))),
    ]);
  }
}

class _AmbientPainter extends CustomPainter {
  final List<Color> colors;
  final ValueListenable<double> phase;
  _AmbientPainter(this.colors, this.phase) : super(repaint: phase);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors)
              .createShader(rect));
    final angle = phase.value * math.pi * 2;
    for (var i = 0; i < 3; i++) {
      final t = angle + i * 2.1;
      final center = Offset(size.width * (.5 + .42 * math.sin(t)),
          size.height * (.5 + .35 * math.cos(angle + i * 1.68)));
      final radius = size.longestSide * .66;
      final shader = RadialGradient(colors: [
        colors[(i + 1) % colors.length].withValues(alpha: .7),
        colors[i].withValues(alpha: 0)
      ]).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, Paint()..shader = shader);
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter old) => old.colors != colors;
}

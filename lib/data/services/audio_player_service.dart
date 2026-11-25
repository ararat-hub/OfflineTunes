import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playback_track.dart';
import '../models/media_link.dart';
import '../models/equalizer.dart';
import 'audius_streams.dart';
import 'music_catalog.dart';

class AudioPlayerService extends ChangeNotifier {
  final Player _player;
  final AudiusStreams? audiusStreams;
  final _resolvedMedia = <String, String>{};
  final _retriedMedia = <String>{};
  Completer<bool>? _mediaLoaded;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  late final Future<void> _ready;
  Future<void> _operations = Future.value();
  SharedPreferences? _prefs;
  List<PlaybackTrack> _queue = [];
  PlaybackTrack? _current;
  bool _opened = false;
  bool _disposed = false;
  bool _isLoading = false;
  bool _isPlaying = false;
  bool _completed = false;
  bool _shuffle = false;
  PlaylistMode _repeat = PlaylistMode.none;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1;
  Equalizer _equalizer = flatEqualizer;
  String? _error;
  Timer? _saveTimer;
  final ValueChanged<PlaybackTrack>? onListened;
  String? _recordedPath;

  AudioPlayerService(
      {Player? player,
      this.onListened,
      this.requestAudioFocus,
      this.audiusStreams})
      : _player = player ?? Player() {
    _subscriptions.addAll([
      _player.stream.playing.listen((value) {
        _isPlaying = value;
        _notify();
      }),
      _player.stream.position.listen((value) {
        if (value > Duration.zero && _mediaLoaded?.isCompleted == false) {
          _mediaLoaded!.complete(true);
        }
        // Native players can publish an initial zero before a file is opened.
        // Keep the restored position until _open has loaded and sought the file.
        if (!_opened) return;
        _position = value;
        final current = _current;
        if (current != null &&
            _isPlaying &&
            value >= const Duration(seconds: 1) &&
            _recordedPath != current.path) {
          _recordedPath = current.path;
          onListened?.call(current);
        }
        _notify();
        _saveTimer ??= Timer(const Duration(seconds: 2), () {
          _saveTimer = null;
          unawaited(_saveState());
        });
      }),
      _player.stream.duration.listen((value) {
        _duration = value;
        if (value > Duration.zero && _mediaLoaded?.isCompleted == false) {
          _mediaLoaded!.complete(true);
        }
        _notify();
      }),
      _player.stream.completed.listen((value) {
        _completed = value;
        if (value) {
          _isPlaying = false;
          unawaited(_saveState());
        }
        _notify();
      }),
      _player.stream.playlist.listen((playlist) {
        if (playlist.index < 0 || playlist.index >= playlist.medias.length) {
          return;
        }
        final uri = playlist.medias[playlist.index].uri;
        for (final track in _queue) {
          if (Media(_resolvedMedia[track.path] ?? track.path).uri == uri &&
              _current != track) {
            _current = track;
            _recordedPath = null;
            _position = Duration.zero;
            // Metadata can arrive before the playlist event. The duration
            // stream is distinct, so an equal-length next track won't re-emit it.
            _duration = _player.state.duration;
            _completed = false;
            unawaited(_saveState());
            _notify();
            break;
          }
        }
      }),
      _player.stream.error.listen((message) {
        debugPrint('Audio playback failed.');
        if (_mediaLoaded?.isCompleted == false) _mediaLoaded!.complete(false);
        final path = currentPath;
        final recovery = _opened &&
            audiusStreams != null &&
            AudiusStreams.trackId(path) != null &&
            _retriedMedia.add(path);
        _error = 'Не удалось воспроизвести трек.';
        _isLoading = false;
        _isPlaying = false;
        _opened = false;
        if (recovery) {
          unawaited(_run(() async {
            if (path == currentPath && !_opened) await _open();
          }));
        }
        _notify();
      }),
    ]);
    _ready = _loadState();
  }

  bool get isPlaying => _isPlaying;
  bool get isCompleted => _completed;
  Future<bool> Function()? requestAudioFocus;
  bool get isLoading => _isLoading;
  bool get hasTrack => _current != null;
  bool get hasQueue => _queue.length > 1;
  bool get shuffle => _shuffle;
  PlaylistMode get repeat => _repeat;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  Equalizer get equalizer => _equalizer;
  bool get supportsEqualizer => _player.platform is NativePlayer;
  String get currentTitle => _current?.title ?? '';
  String get currentArtist => _current?.artist ?? '';
  String get currentPath => _current?.path ?? '';
  PlaybackTrack? get currentTrack => _current;
  String? get error => _error;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _loadState() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      _volume =
          ((_prefs!.getDouble('player_volume') ?? 100) / 100).clamp(0.0, 1.0);
      await _player.setVolume(_volume * 100);
      final path = _prefs!.getString('player_last_path') ?? '';
      final uri = Uri.tryParse(path);
      if (path.isNotEmpty && (uri == null || !MediaLink.isStorePreview(uri))) {
        final saved = _prefs!.getString('player_last_track');
        if (saved != null) {
          try {
            final track = PlaybackTrack.fromJson(
                jsonDecode(saved) as Map<String, dynamic>);
            if (track.path == path) _current = track;
          } catch (_) {/* Fall back to the fields from older releases. */}
        }
        _current ??= PlaybackTrack(
            path: path,
            title: _prefs!.getString('player_last_title') ?? 'Без названия',
            artist: _prefs!.getString('player_last_artist') ?? '');
        _queue = [_current!];
        final ms = _prefs!.getInt('player_last_position_ms') ?? 0;
        _position = Duration(milliseconds: ms < 0 ? 0 : ms);
      }
      final tone = (
        bass: (_prefs!.getInt('audio_eq_bass') ?? 0).clamp(-6, 6),
        mid: (_prefs!.getInt('audio_eq_mid') ?? 0).clamp(-6, 6),
        treble: (_prefs!.getInt('audio_eq_treble') ?? 0).clamp(-6, 6),
      );
      if (tone != flatEqualizer) await _applyEqualizer(tone);
    } catch (e) {
      debugPrint('Restore playback state: $e');
      _error = 'Не удалось восстановить настройки плеера.';
    }
    _notify();
  }

  // Serialize commands so a slow open cannot overwrite a later selection.
  Future<void> _run(Future<void> Function() action) {
    _operations = _operations.then((_) async {
      await _ready;
      if (_disposed) return;
      try {
        await action();
      } catch (e) {
        debugPrint('Audio action: $e');
        _error = e is FileSystemException
            ? e.message
            : 'Не удалось выполнить действие плеера.';
      } finally {
        _isLoading = false;
        _notify();
      }
    });
    return _operations;
  }

  Future<void> playUrl(String url, {String? title, String? artist}) =>
      playQueue([
        PlaybackTrack(
            path: url,
            title: title ?? 'Без названия',
            artist: artist ?? 'Неизвестный исполнитель'),
      ]);

  Future<void> playFile(String path, {String? title, String? artist}) =>
      playUrl(path,
          title: title ?? path.split(RegExp(r'[/\\]')).last, artist: artist);

  Future<void> playQueue(List<PlaybackTrack> tracks, {int index = 0}) =>
      _run(() async {
        if (tracks.isEmpty || index < 0 || index >= tracks.length) return;
        await _validate(tracks[index].path);
        _queue = List.of(tracks.where((track) => track.path.isNotEmpty));
        _resolvedMedia.clear();
        _retriedMedia.clear();
        _current = tracks[index];
        _position = Duration.zero;
        _duration = Duration.zero;
        await _open();
      });

  Future<void> _validate(String path) async {
    if (path.isEmpty) throw const FileSystemException('Путь к треку не указан');
    final uri = Uri.tryParse(path);
    if (uri?.scheme == 'https' || uri?.scheme == 'http') return;
    final file = uri?.scheme == 'file' ? File.fromUri(uri!) : File(path);
    if (!await file.exists()) {
      throw FileSystemException('Файл не найден. Добавьте музыку заново', path);
    }
  }

  Future<void> _open() async {
    if (requestAudioFocus != null && !await requestAudioFocus!()) {
      _error = 'Не удалось воспроизвести трек.';
      return;
    }
    _isLoading = true;
    _opened = false;
    _completed = false;
    _recordedPath = null;
    _error = null;
    _saveTimer?.cancel();
    _saveTimer = null;
    _notify();
    final savedPosition = _position;
    await _validate(currentPath);
    final streams = audiusStreams;
    final path = currentPath;
    if (streams != null && AudiusStreams.trackId(path) != null) {
      await _player.pause();
      final resolved = await streams.resolve(path);
      if (_disposed) return;
      if (resolved == null) {
        _error = 'Не удалось открыть полный поток Audius. Попробуйте ещё раз.';
        return;
      }
      _resolvedMedia[path] = resolved;
    }
    final loaded = _mediaLoaded = Completer<bool>();
    try {
      await _player.open(
          Playlist(
              _queue
                  .map((track) => Media(
                        _resolvedMedia[track.path] ?? track.path,
                        httpHeaders: Uri.tryParse(track.path)?.host ==
                                    'upload.wikimedia.org' ||
                                AudiusStreams.trackId(track.path) != null
                            ? const {'User-Agent': MusicCatalog.userAgent}
                            : null,
                      ))
                  .toList(),
              index: _queue.indexOf(_current!)),
          play: false);
      final duration = _player.state.duration;
      if (duration > Duration.zero && !loaded.isCompleted) {
        _duration = duration;
        loaded.complete(true);
      }
      await _player.play();
      final ready = await loaded.future
          .timeout(const Duration(seconds: 25), onTimeout: () => false);
      if (!ready || _disposed) {
        _error ??= 'Не удалось загрузить аудиопоток. Повторите попытку.';
        await _player.pause();
        return;
      }
    } finally {
      if (_mediaLoaded == loaded) _mediaLoaded = null;
    }
    await _player.setPlaylistMode(_repeat);
    await _player.setShuffle(_shuffle);
    if (savedPosition > Duration.zero) {
      // open() queues the native load; seeking before metadata arrives is lost.
      var loadedDuration = _player.state.duration;
      if (loadedDuration == Duration.zero) {
        loadedDuration = await _player.stream.duration
            .firstWhere((value) => value > Duration.zero)
            .timeout(const Duration(seconds: 15));
      }
      await _player.seek(Duration(
        milliseconds: savedPosition.inMilliseconds
            .clamp(0, loadedDuration.inMilliseconds),
      ));
    }
    _position = savedPosition;
    _opened = true;
    await _saveState();
  }

  Future<void> togglePlayPause() => _run(() async {
        if (!hasTrack) return;
        if (!_opened) {
          await _open();
        } else if (_isPlaying) {
          await _player.pause();
          await _saveState();
        } else {
          if (requestAudioFocus != null && !await requestAudioFocus!()) return;
          if (_completed) await _player.seek(Duration.zero);
          await _player.play();
        }
      });

  Future<void> pause() => _run(() async {
        if (_opened) await _player.pause();
        await _saveState();
      });

  Future<void> stop() => _run(() async {
        await _player.stop();
        _opened = false;
        _isPlaying = false;
        _position = Duration.zero;
        await _saveState();
      });

  Future<void> seek(Duration value) => _run(() async {
        if (!_opened || _duration == Duration.zero) return;
        _position = Duration(
            milliseconds:
                value.inMilliseconds.clamp(0, _duration.inMilliseconds));
        await _player.seek(_position);
        await _saveState();
      });

  Future<void> next() => _run(() async {
        if (_opened && hasQueue) await _player.next();
      });

  Future<void> previous() => _run(() async {
        if (!_opened) return;
        if (_position > const Duration(seconds: 3) || !hasQueue) {
          await _player.seek(Duration.zero);
        } else {
          await _player.previous();
        }
      });

  Future<void> toggleShuffle() => _run(() async {
        _shuffle = !_shuffle;
        await _player.setShuffle(_shuffle);
      });

  Future<void> cycleRepeat() => _run(() async {
        _repeat = switch (_repeat) {
          PlaylistMode.none => PlaylistMode.loop,
          PlaylistMode.loop => PlaylistMode.single,
          PlaylistMode.single => PlaylistMode.none,
        };
        await _player.setPlaylistMode(_repeat);
      });

  Future<void> setVolume(double value) => _run(() async {
        _volume = value.clamp(0.0, 1.0);
        await _player.setVolume(_volume * 100 * equalizerHeadroom(_equalizer));
        await _prefs?.setDouble('player_volume', _volume * 100);
      });

  Future<void> _applyEqualizer(Equalizer value) async {
    final backend = _player.platform;
    if (backend is NativePlayer) {
      await backend.setProperty('af', equalizerFilter(value));
      await _player.setVolume(_volume * 100 * equalizerHeadroom(value));
    }
    _equalizer = value;
  }

  Future<void> setEqualizer(Equalizer value) => _run(() async {
        final adjusted = (
          bass: value.bass.clamp(-6, 6),
          mid: value.mid.clamp(-6, 6),
          treble: value.treble.clamp(-6, 6)
        );
        if (_equalizer == adjusted) return;
        await _applyEqualizer(adjusted);
        await _prefs?.setInt('audio_eq_bass', adjusted.bass);
        await _prefs?.setInt('audio_eq_mid', adjusted.mid);
        await _prefs?.setInt('audio_eq_treble', adjusted.treble);
      });

  Future<void> _saveState() async {
    final current = _current;
    final position = _completed ? Duration.zero : _position;
    if (current == null || _prefs == null) return;
    await _prefs!.setString('player_last_path', current.path);
    await _prefs!.setString('player_last_track', jsonEncode(current.toJson()));
    await _prefs!.setString('player_last_title', current.title);
    await _prefs!.setString('player_last_artist', current.artist);
    await _prefs!.setInt('player_last_position_ms', position.inMilliseconds);
  }

  @override
  void dispose() {
    if (_mediaLoaded?.isCompleted == false) _mediaLoaded!.complete(false);
    _disposed = true;
    _saveTimer?.cancel();
    unawaited(_saveState());
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    audiusStreams?.dispose();
    unawaited(_operations.then((_) => _player.dispose()));
    super.dispose();
  }
}

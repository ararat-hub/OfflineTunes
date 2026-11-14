import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:media_kit/media_kit.dart' show PlaylistMode;

import '../../theme/theme_provider.dart';
import '../models/playback_track.dart';
import 'audio_player_service.dart';
import 'track_artwork_store.dart';

class SystemMediaControls extends BaseAudioHandler with SeekHandler {
  SystemMediaControls(this._player, this._theme) {
    _player.addListener(_publish);
    _theme.addListener(_publish);
  }

  final AudioPlayerService _player;
  final ThemeProvider _theme;
  PlaybackTrack? _track;
  String? _background;
  Uri? _art;
  int _artRequest = 0;
  Duration _duration = Duration.zero;
  bool _active = false;
  bool _stopped = false;
  ({
    bool playing,
    bool loading,
    bool completed,
    bool failed,
    bool queue,
    int position
  })? _lastState;

  static Future<AudioSession> initialize(
      AudioPlayerService player, ThemeProvider theme) async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    final handler = await AudioService.init(
      builder: () => SystemMediaControls(player, theme),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.offlinetunes.playback',
        androidNotificationChannelName: 'oTune',
        androidNotificationIcon: 'drawable/ic_media_notification',
        androidStopForegroundOnPause: false,
      ),
    );
    session.becomingNoisyEventStream.listen((_) => unawaited(handler.pause()));
    session.interruptionEventStream.listen((event) {
      if (event.begin && event.type != AudioInterruptionType.duck) {
        unawaited(handler.pause());
      }
    });
    return session;
  }

  void _publish() {
    if (_player.isPlaying) {
      _active = true;
      _stopped = false;
    }
    final track = _player.currentTrack;
    if (!_active || _stopped || track == null) return;
    final background =
        _theme.systemWidgetUsesBackground ? _theme.widgetMediaPath : null;
    final artChanged = _track != track || _background != background;
    final itemChanged = artChanged || _duration != _player.duration;
    if (itemChanged) {
      _track = track;
      _background = background;
      _duration = _player.duration;
      if (artChanged) {
        _art = null;
        final request = ++_artRequest;
        unawaited(TrackArtworkStore.resolve(track, background: background)
            .then((file) {
          if (file == null || _artRequest != request) return;
          _art = file.uri;
          _setItem(track);
        }));
      }
      _setItem(track);
    }
    final state = (
      playing: _player.isPlaying,
      loading: _player.isLoading,
      completed: _player.isCompleted,
      failed: _player.error != null,
      queue: _player.hasQueue,
      position: _player.position.inSeconds,
    );
    if (!itemChanged && _lastState == state) return;
    _lastState = state;
    playbackState.add(PlaybackState(
      playing: state.playing,
      processingState: state.failed
          ? AudioProcessingState.error
          : state.loading
              ? AudioProcessingState.loading
              : state.completed
                  ? AudioProcessingState.completed
                  : AudioProcessingState.ready,
      updatePosition: _player.position,
      bufferedPosition: _player.position,
      speed: 1,
      controls: [
        if (state.queue) MediaControl.skipToPrevious,
        state.playing ? MediaControl.pause : MediaControl.play,
        if (state.queue) MediaControl.skipToNext,
        MediaControl.stop,
      ],
      androidCompactActionIndices: state.queue ? const [0, 1, 2] : const [0],
      systemActions: {if (_duration > Duration.zero) MediaAction.seek},
      repeatMode: switch (_player.repeat) {
        PlaylistMode.none => AudioServiceRepeatMode.none,
        PlaylistMode.single => AudioServiceRepeatMode.one,
        PlaylistMode.loop => AudioServiceRepeatMode.all,
      },
    ));
  }

  void _setItem(PlaybackTrack track) {
    mediaItem.add(MediaItem(
      id: track.identity,
      title: track.title,
      artist: track.artist,
      duration: _duration > Duration.zero ? _duration : null,
      artUri: _art,
    ));
  }

  @override
  Future<void> play() =>
      _player.isPlaying ? Future.value() : _player.togglePlayPause();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> skipToPrevious() => _player.previous();
  @override
  Future<void> skipToNext() => _player.next();
  @override
  Future<void> onNotificationDeleted() => stop();
  @override
  Future<void> stop() async {
    _stopped = true;
    ++_artRequest;
    await _player.stop();
    _track = null;
    _lastState = null;
    mediaItem.add(null);
    playbackState.add(PlaybackState());
  }
}

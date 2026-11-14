import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:media_kit/media_kit.dart' show PlaylistMode;

import '../models/playback_track.dart';
import 'audio_player_service.dart';

class SystemMediaControls extends BaseAudioHandler with SeekHandler {
  SystemMediaControls(this._player) {
    _player.addListener(_publish);
  }

  final AudioPlayerService _player;
  PlaybackTrack? _track;
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

  static Future<AudioSession> initialize(AudioPlayerService player) async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    final handler = await AudioService.init(
      builder: () => SystemMediaControls(player),
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
    final itemChanged = _track != track || _duration != _player.duration;
    if (itemChanged) {
      _track = track;
      _duration = _player.duration;
      mediaItem.add(MediaItem(
        id: track.identity,
        title: track.title,
        artist: track.artist,
        duration: _duration > Duration.zero ? _duration : null,
        artUri: Uri.tryParse(track.artwork ?? '')?.hasScheme == true
            ? Uri.parse(track.artwork!)
            : null,
      ));
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
    await _player.stop();
    _track = null;
    _lastState = null;
    mediaItem.add(null);
    playbackState.add(PlaybackState());
  }
}

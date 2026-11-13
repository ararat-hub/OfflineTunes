import '../core/localization.dart';
import 'package:flutter/material.dart';
import 'player_controls.dart';
import 'track_row.dart';
import 'package:media_kit/media_kit.dart';
import '../data/services/audio_player_service.dart';

class MiniPlayer extends StatelessWidget {
  final AudioPlayerService playerService;
  final bool compact;
  final bool showArtist;
  final bool showProgress;
  final double opacity;
  const MiniPlayer(
      {super.key,
      required this.playerService,
      this.compact = false,
      this.showArtist = true,
      this.showProgress = true,
      this.opacity = .4});

  String _time(Duration value) {
    final seconds = value.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playerService,
      builder: (context, _) {
        final player = playerService;
        final enabled = player.hasTrack && !player.isLoading;
        final max = player.duration.inMilliseconds.toDouble();
        final progress = Column(children: [
          PlayerSlider(
            label: context.tr('Позиция воспроизведения'),
            min: 0,
            max: max > 0 ? max : 1,
            value: player.position.inMilliseconds
                .toDouble()
                .clamp(0, max > 0 ? max : 1),
            onChanged: enabled && max > 0
                ? (value) => player.seek(Duration(milliseconds: value.round()))
                : null,
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_time(player.position), style: const TextStyle(fontSize: 11)),
            Text(_time(player.duration), style: const TextStyle(fontSize: 11)),
          ]),
        ]);
        final controls = Row(mainAxisSize: MainAxisSize.min, children: [
          PlayerControlButton(
            tooltip: context.tr('Перемешать'),
            color:
                player.shuffle ? Theme.of(context).colorScheme.primary : null,
            icon: const Icon(Icons.shuffle, size: 20),
            onPressed: enabled && player.hasQueue ? player.toggleShuffle : null,
          ),
          PlayerControlButton(
              tooltip: context.tr('Предыдущий трек'),
              icon: const Icon(Icons.skip_previous_rounded),
              onPressed: enabled ? player.previous : null),
          PlayerControlButton(
            tooltip: player.isPlaying
                ? context.tr('Пауза')
                : context.tr('Воспроизвести'),
            icon: player.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(
                    player.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    size: 32),
            onPressed: enabled ? player.togglePlayPause : null,
          ),
          PlayerControlButton(
              tooltip: context.tr('Следующий трек'),
              icon: const Icon(Icons.skip_next_rounded),
              onPressed: enabled && player.hasQueue ? player.next : null),
          PlayerControlButton(
            tooltip: switch (player.repeat) {
              PlaylistMode.none => context.tr('Повтор выключен'),
              PlaylistMode.loop => context.tr('Повтор очереди'),
              PlaylistMode.single => context.tr('Повтор трека'),
            },
            color: player.repeat != PlaylistMode.none
                ? Theme.of(context).colorScheme.primary
                : null,
            icon: Icon(
                player.repeat == PlaylistMode.single
                    ? Icons.repeat_one
                    : Icons.repeat,
                size: 20),
            onPressed: enabled ? player.cycleRepeat : null,
          ),
        ]);
        final title = Row(children: [
          TrackArtwork(track: player.currentTrack),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                Text(
                    player.currentTitle.isEmpty
                        ? context.tr('Выберите трек')
                        : player.currentTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (showArtist)
                  Text(
                      player.currentArtist.isEmpty ? '—' : player.currentArtist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12)),
              ])),
          if (player.currentTrack case final track?)
            FavoriteTrackButton(track: track),
        ]);
        return Container(
          color: Colors.black.withValues(alpha: opacity),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (player.error != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(context.tr(player.error!),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12))),
            LayoutBuilder(builder: (context, constraints) {
              if (compact || constraints.maxWidth < 650) {
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: double.infinity, child: title),
                  controls,
                  if (showProgress) progress,
                ]);
              }
              return Row(children: [
                Expanded(child: title),
                const SizedBox(width: 16),
                SizedBox(
                    width: 300,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [controls, if (showProgress) progress])),
                const SizedBox(width: 16),
                Expanded(
                    child: Row(children: [
                  const Spacer(),
                  Icon(
                      player.volume < 0.01 ? Icons.volume_off : Icons.volume_up,
                      size: 18),
                  SizedBox(
                      width: 100,
                      child: PlayerSlider(
                          value: player.volume, onChanged: player.setVolume)),
                ])),
              ]);
            }),
          ]),
        );
      },
    );
  }
}

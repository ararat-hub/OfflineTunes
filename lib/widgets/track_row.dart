import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/localization.dart';
import '../data/models/playback_track.dart';
import '../data/models/media_link.dart';
import '../data/services/audio_player_service.dart';
import '../data/services/youtube_player_service.dart';

void playHistoryTrack(
    BuildContext context, List<PlaybackTrack> tracks, PlaybackTrack selected) {
  if (selected.youtube) {
    context.read<YoutubePlayerService>().open(MediaLink.parse(selected.path));
  } else {
    final audio = tracks.where((track) => !track.youtube).toList();
    context
        .read<AudioPlayerService>()
        .playQueue(audio, index: audio.indexOf(selected));
  }
}

class TrackRow extends StatelessWidget {
  const TrackRow(
      {super.key,
      required this.track,
      required this.onPlay,
      this.duration,
      this.playCount,
      this.trailing});

  final PlaybackTrack track;
  final VoidCallback onPlay;
  final Duration? duration;
  final int? playCount;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final time = duration?.inSeconds;
    final metadata = [
      if (track.artist.isNotEmpty) track.artist,
      if (time != null)
        '${time ~/ 60}:${(time % 60).toString().padLeft(2, '0')}',
      if (track.license != null) track.license!,
      if (playCount != null)
        context.tr('Прослушиваний: {count}', {
          'count': NumberFormat.decimalPattern(
                  Localizations.localeOf(context).languageCode)
              .format(playCount),
        }),
    ];
    return ListTile(
      leading:
          Icon(track.youtube ? Icons.smart_display : Icons.play_circle_outline),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: metadata.isEmpty
          ? null
          : Text(metadata.join(' · '),
              maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: trailing ??
          (track.sourcePage == null
              ? null
              : IconButton(
                  tooltip: context.tr('Источник записи'),
                  icon: const Icon(Icons.open_in_new, size: 19),
                  onPressed: () => launchUrl(Uri.parse(track.sourcePage!),
                      mode: LaunchMode.externalApplication),
                )),
      onTap: onPlay,
    );
  }
}

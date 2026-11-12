import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/localization.dart';
import '../data/models/playback_track.dart';

class TrackRow extends StatelessWidget {
  const TrackRow(
      {super.key,
      required this.track,
      required this.onPlay,
      this.duration,
      this.trailing});

  final PlaybackTrack track;
  final VoidCallback onPlay;
  final Duration? duration;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final time = duration?.inSeconds;
    final metadata = [
      if (track.artist.isNotEmpty) track.artist,
      if (time != null)
        '${time ~/ 60}:${(time % 60).toString().padLeft(2, '0')}',
      if (track.license != null) track.license!,
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

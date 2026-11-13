import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization.dart';
import '../../data/services/offline_tracks.dart';
import '../../widgets/track_row.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<OfflineTracks>();
    final tracks = downloads.tracks;
    if (tracks.isEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                  context.tr(
                      'Скачайте доступные треки через поиск или подборки, чтобы слушать их без интернета.'),
                  textAlign: TextAlign.center)));
    }
    return ListView.builder(
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          return TrackRow(
              track: track,
              onPlay: () => playHistoryTrack(context, tracks, track),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                TrackActions(track: track),
                IconButton(
                    tooltip: context.tr('Удалить загрузку'),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialog) => AlertDialog(
                                title: Text(context.tr('Удалить загрузку')),
                                content: Text(track.title),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(dialog),
                                      child: Text(context.tr('Отмена'))),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialog, true),
                                      child: Text(context.tr('Удалить')))
                                ],
                              ));
                      if (confirmed != true) return;
                      try {
                        await downloads.remove(track);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  context.tr('Не удалось удалить загрузку.'))));
                        }
                      }
                    }),
              ]));
        });
  }
}

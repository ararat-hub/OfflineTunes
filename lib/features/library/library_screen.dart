import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization.dart';
import '../../data/db/app_database.dart';
import '../../data/models/media_link.dart';
import '../../data/models/playback_track.dart';
import '../../data/services/audio_player_service.dart';
import '../../data/services/listening_history.dart';
import '../../data/services/youtube_player_service.dart';
import '../../widgets/track_row.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _recent = true;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 6, children: [
            ChoiceChip(
              label: Text(context.tr('Недавно прослушанные')),
              selected: _recent,
              onSelected: (_) => setState(() => _recent = true),
            ),
            ChoiceChip(
              label: Text(context.tr('Все треки')),
              selected: !_recent,
              onSelected: (_) => setState(() => _recent = false),
            ),
          ]),
          const SizedBox(height: 12),
          Expanded(
              child:
                  _recent ? const _RecentlyPlayed() : const _LibraryTracks()),
        ]),
      );
}

class _RecentlyPlayed extends StatelessWidget {
  const _RecentlyPlayed();

  @override
  Widget build(BuildContext context) {
    final tracks = context.watch<ListeningHistory>().recent;
    if (tracks.isEmpty) {
      return Center(
          child: Text(context.tr('Здесь появятся прослушанные треки.')));
    }
    final audio = context.read<AudioPlayerService>();
    final youtube = context.read<YoutubePlayerService>();
    final audioTracks = tracks.where((track) => !track.youtube).toList();
    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return TrackRow(
            track: track,
            onPlay: () {
              if (track.youtube) {
                youtube.open(MediaLink.parse(track.path));
              } else {
                audio.playQueue(audioTracks, index: audioTracks.indexOf(track));
              }
            });
      },
    );
  }
}

class _LibraryTracks extends StatefulWidget {
  const _LibraryTracks();

  @override
  State<_LibraryTracks> createState() => _LibraryTracksState();
}

class _LibraryTracksState extends State<_LibraryTracks> {
  late final _db = context.read<AppDatabase>();
  late final _tracks = _db.watchAllTracks();

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Track>>(
        stream: _tracks,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final tracks = snapshot.data ?? [];
          final playable = [
            for (final item in tracks)
              if (PlaybackTrack.fromTrack(item).path.isNotEmpty) item,
          ];
          if (playable.isEmpty) {
            return Center(
              child: Text(
                context.tr(
                    'Ваша медиатека пуста.\nПерейдите в раздел "Добавить", чтобы отсканировать музыку.'),
                textAlign: TextAlign.center,
              ),
            );
          }
          final queue = playable.map(PlaybackTrack.fromTrack).toList();
          return ListView.builder(
            itemCount: queue.length,
            itemBuilder: (context, index) {
              final item = playable[index];
              final favorite = item.isFavorite == 1;
              return TrackRow(
                track: queue[index],
                onPlay: () => context
                    .read<AudioPlayerService>()
                    .playQueue(queue, index: index),
                trailing: IconButton(
                  tooltip: context
                      .tr(favorite ? 'Убрать из избранного' : 'В избранное'),
                  onPressed: () => (_db.update(_db.tracks)
                        ..where((row) => row.id.equals(item.id)))
                      .write(
                          TracksCompanion(isFavorite: Value(favorite ? 0 : 1))),
                  icon: Icon(favorite ? Icons.favorite : Icons.favorite_border,
                      color: favorite ? Colors.redAccent : null),
                ),
              );
            },
          );
        },
      );
}

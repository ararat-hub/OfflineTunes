import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization.dart';
import '../../data/db/app_database.dart';
import '../../data/models/playback_track.dart';
import '../../data/services/listening_history.dart';
import '../../widgets/track_row.dart';
import 'downloads_screen.dart';
import '../favorites/favorites_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _section = 0;
  bool _byTitle = false;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final (index, label) in [
              'Недавно прослушанные',
              'Все треки',
              if (Platform.isAndroid) ...['Избранное', 'Загрузки']
            ].indexed)
              ChoiceChip(
                  label: Text(context.tr(label)),
                  selected: _section == index,
                  onSelected: (_) => setState(() => _section = index)),
            if (_section < 2)
              DropdownButton<bool>(
                  value: _byTitle,
                  items: [
                    DropdownMenuItem(
                        value: false, child: Text(context.tr('По времени'))),
                    DropdownMenuItem(
                        value: true, child: Text(context.tr('По названию'))),
                  ],
                  onChanged: (value) => setState(() => _byTitle = value!)),
          ]),
          const SizedBox(height: 12),
          Expanded(
              child: switch (_section) {
            1 => _LibraryTracks(byTitle: _byTitle),
            2 => const FavoritesScreen(),
            3 => const DownloadsScreen(),
            _ => _RecentlyPlayed(byTitle: _byTitle),
          }),
        ]),
      );
}

class _RecentlyPlayed extends StatelessWidget {
  const _RecentlyPlayed({required this.byTitle});
  final bool byTitle;

  @override
  Widget build(BuildContext context) {
    final tracks = context.watch<ListeningHistory>().recent;
    if (byTitle) {
      tracks.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    if (tracks.isEmpty) {
      return Center(
          child: Text(context.tr('Здесь появятся прослушанные треки.')));
    }
    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return TrackRow(
            track: track,
            onPlay: () => playHistoryTrack(context, tracks, track));
      },
    );
  }
}

class _LibraryTracks extends StatefulWidget {
  const _LibraryTracks({required this.byTitle});
  final bool byTitle;

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
          playable.sort(widget.byTitle
              ? (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())
              : (a, b) => b.addedAt.compareTo(a.addedAt));
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
              return TrackRow(
                track: queue[index],
                onPlay: () => playHistoryTrack(context, queue, queue[index]),
              );
            },
          );
        },
      );
}

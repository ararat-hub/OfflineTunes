import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization.dart';
import '../../data/services/favorite_tracks.dart';
import '../../widgets/track_row.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tracks = context.watch<FavoriteTracks>().tracks;
    if (tracks.isEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.tr(
                    'Нажмите на сердечко рядом с треком, чтобы добавить его в избранное.'),
                textAlign: TextAlign.center,
              )));
    }
    return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: tracks.length,
        itemBuilder: (context, index) => TrackRow(
            track: tracks[index],
            onPlay: () => playHistoryTrack(context, tracks, tracks[index])));
  }
}

import '../../core/localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/db/app_database.dart';
import '../../data/services/audio_player_service.dart';
import '../../data/models/playback_track.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Медиатека'),
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Track>>(
                stream: db.select(db.tracks).watch(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final tracks = snapshot.data ?? [];

                  if (tracks.isEmpty) {
                    return Center(
                      child: Text(
                        context.tr(
                            'Ваша медиатека пуста.\nПерейдите в раздел "Добавить", чтобы отсканировать музыку.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      final bool isFav = track.isFavorite == 1;

                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.music_note,
                              color: Colors.white70),
                        ),
                        title: Text(track.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(track.artist,
                            style: const TextStyle(color: Colors.white54)),
                        trailing: IconButton(
                          icon: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav ? Colors.redAccent : Colors.white38,
                          ),
                          onPressed: () {
                            db.update(db.tracks).replace(
                                  track.copyWith(isFavorite: isFav ? 0 : 1),
                                );
                          },
                        ),
                        onTap: () {
                          audioService.playQueue(
                            tracks.map(PlaybackTrack.fromTrack).toList(),
                            index: index,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

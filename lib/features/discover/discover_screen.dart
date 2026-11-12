import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../core/localization.dart';
import '../../data/db/app_database.dart';
import '../../data/services/audio_player_service.dart';
import '../../data/services/listening_history.dart';
import '../../data/services/music_catalog.dart';
import '../../widgets/track_row.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  static const categories = [
    ('Для вас', ''),
    ('Классика', 'classical piano Beethoven'),
    ('Джаз', 'jazz music'),
    ('Электроника', 'electronic music'),
    ('Фолк', 'folk music'),
  ];
  int _category = 0;
  final _client = http.Client();
  late final _catalog = MusicCatalog(_client);
  late final _library = widget.db.watchAllTracks();
  Future<CatalogPage>? _online;
  final _cache = <int, CatalogPage>{};

  void _select(int index) {
    setState(() {
      _category = index;
      _online = index == 0 ? null : _load(index);
    });
  }

  Future<CatalogPage> _load(int index) async =>
      _cache[index] ??= await _catalog.search(categories[index].$2,
          source: index == 1 ? CatalogSource.commons : CatalogSource.audius);

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.read<AudioPlayerService>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (var i = 0; i < categories.length; i++)
            ChoiceChip(
              label: Text(context.tr(categories[i].$1)),
              selected: _category == i,
              onSelected: (_) => _select(i),
            ),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: _category == 0
              ? StreamBuilder<List<Track>>(
                  stream: _library,
                  builder: (context, snapshot) {
                    final queue = context
                        .watch<ListeningHistory>()
                        .recommend(snapshot.data ?? []);
                    if (queue.isEmpty) {
                      return Center(
                          child: Text(
                              context.tr(
                                'Слушайте музыку или добавляйте треки в избранное, чтобы увидеть рекомендации из медиатеки.',
                              ),
                              textAlign: TextAlign.center));
                    }
                    return ListView.builder(
                      itemCount: queue.length,
                      itemBuilder: (_, index) => TrackRow(
                        track: queue[index],
                        onPlay: () => audio.playQueue(queue, index: index),
                      ),
                    );
                  })
              : FutureBuilder<CatalogPage>(
                  future: _online,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final results = snapshot.data?.tracks ?? [];
                    if (results.isEmpty) {
                      return Center(
                          child: Text(context.tr(snapshot.hasError
                              ? 'Каталог временно недоступен.'
                              : 'Ничего не найдено')));
                    }
                    final queue = results.map((item) => item.track).toList();
                    return ListView.builder(
                      itemCount: queue.length,
                      itemBuilder: (_, index) => TrackRow(
                        track: queue[index],
                        duration: results[index].duration,
                        onPlay: () => audio.playQueue(queue, index: index),
                      ),
                    );
                  }),
        ),
      ]),
    );
  }
}

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.download_outlined, size: 36),
            const SizedBox(height: 12),
            Text(context.tr('Загрузки появятся в мобильной версии.'),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../core/localization.dart';
import '../../data/db/app_database.dart';
import '../../data/models/music_query.dart';
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
  static const _categories = [
    ('Популярное', Icons.trending_up),
    ('Часто слушаете', Icons.replay),
    ('Для вас', Icons.auto_awesome_outlined),
  ];
  int _category = 0;
  static const _genres = [
    ('Все жанры', null),
    ('Электроника', 'Electronic'),
    ('Хип-хоп', 'Hip-Hop/Rap'),
    ('Рок', 'Rock'),
    ('Поп', 'Pop'),
  ];
  final _chartSearch = TextEditingController();
  String? _genre;
  final _client = http.Client();
  late final _catalog = MusicCatalog(_client);
  late final _library = widget.db.watchAllTracks();
  late Future<({List<CatalogTrack> tracks, bool cached})> _popular =
      _catalog.popularWithCache();

  @override
  void dispose() {
    _chartSearch.dispose();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.read<AudioPlayerService>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_category != 0)
          Selector<AudioPlayerService, String>(
              selector: (_, player) => player.currentPath,
              builder: (context, path, _) {
                final current = audio.currentTrack;
                if (current == null) return const SizedBox.shrink();
                return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                      child: ListTile(
                          leading: TrackArtwork(track: current),
                          title: Text(current.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(context.tr('Сейчас играет')),
                          trailing: TrackActions(
                              track: current, duration: audio.duration)),
                    ));
              }),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Wrap(spacing: 8, children: [
            for (var i = 0; i < _categories.length; i++)
              ChoiceChip(
                avatar: Icon(_categories[i].$2, size: 17),
                label: Text(context.tr(_categories[i].$1)),
                selected: _category == i,
                onSelected: (_) => setState(() => _category = i),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: switch (_category) {
            0 => Column(children: [
                TextField(
                  controller: _chartSearch,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: context.tr('Найти в чарте'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _chartSearch.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: context.tr('Очистить поиск'),
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(_chartSearch.clear),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                    alignment: Alignment.centerLeft,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Wrap(spacing: 8, children: [
                        for (final (label, genre) in _genres)
                          ChoiceChip(
                            label: Text(context.tr(label)),
                            selected: _genre == genre,
                            onSelected: (selected) {
                              if (!selected) return;
                              setState(() {
                                _genre = genre;
                                _popular =
                                    _catalog.popularWithCache(genre: genre);
                              });
                            },
                          ),
                      ]),
                    )),
                const SizedBox(height: 8),
                Expanded(
                    child: FutureBuilder<
                            ({List<CatalogTrack> tracks, bool cached})>(
                        future: _popular,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(
                                child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                    context.tr('Каталог временно недоступен.')),
                                TextButton(
                                  onPressed: () => setState(() => _popular =
                                      _catalog.popularWithCache(genre: _genre)),
                                  child: Text(context.tr('Повторить')),
                                ),
                              ],
                            ));
                          }
                          final results = snapshot.data?.tracks ?? [];
                          if (results.isEmpty) {
                            return Center(
                                child: Text(context.tr('Ничего не найдено')));
                          }
                          final query = MusicQuery(_chartSearch.text);
                          final matches = results
                              .asMap()
                              .entries
                              .where((row) =>
                                  query.text.isEmpty ||
                                  query.matches(row.value.track.title,
                                      row.value.track.artist))
                              .toList();
                          final queue =
                              matches.map((row) => row.value.track).toList();
                          final colors = Theme.of(context).colorScheme;
                          final cached = snapshot.data?.cached == true;
                          return ListView.builder(
                            itemCount: matches.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer
                                        .withValues(alpha: .55),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(children: [
                                    TrackArtwork(
                                        track: results.first.track, size: 62),
                                    const SizedBox(width: 14),
                                    Expanded(
                                        child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(context.tr('Топ треков'),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w700)),
                                        Text(context.tr(queue.isEmpty
                                            ? 'Ничего не найдено'
                                            : cached
                                                ? 'Последняя сохранённая подборка Audius'
                                                : 'По числу прослушиваний · Audius')),
                                      ],
                                    )),
                                    if (cached)
                                      IconButton(
                                        icon: const Icon(Icons.refresh),
                                        tooltip: context.tr('Повторить'),
                                        onPressed: () => setState(() =>
                                            _popular =
                                                _catalog.popularWithCache(
                                                    genre: _genre)),
                                      ),
                                    if (queue.isNotEmpty)
                                      IconButton.filled(
                                        icon: const Icon(
                                            Icons.play_arrow_rounded),
                                        tooltip: context
                                            .tr('Воспроизвести подборку'),
                                        onPressed: () => playHistoryTrack(
                                            context, queue, queue.first),
                                      ),
                                  ]),
                                );
                              }
                              final row = matches[index - 1];
                              return TrackRow(
                                rank: row.key + 1,
                                track: row.value.track,
                                duration: row.value.duration,
                                playCount: row.value.plays,
                                onPlay: () => playHistoryTrack(
                                    context, queue, queue[index - 1]),
                              );
                            },
                          );
                        })),
              ]),
            1 => const _MostPlayed(),
            _ => StreamBuilder<List<Track>>(
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
                      onPlay: () =>
                          playHistoryTrack(context, queue, queue[index]),
                    ),
                  );
                }),
          },
        ),
      ]),
    );
  }
}

class _MostPlayed extends StatelessWidget {
  const _MostPlayed();

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<ListeningHistory>().mostPlayed;
    if (entries.isEmpty) {
      return Center(
          child: Text(
              context.tr(
                'Здесь появятся треки, которые вы слушали несколько раз.',
              ),
              textAlign: TextAlign.center));
    }
    final tracks = entries.map((entry) => entry.track).toList();
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) => TrackRow(
        track: tracks[index],
        playCount: entries[index].count,
        onPlay: () => playHistoryTrack(context, tracks, tracks[index]),
      ),
    );
  }
}

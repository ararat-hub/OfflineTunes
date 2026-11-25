import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../core/localization.dart';
import '../../data/db/app_database.dart';
import '../../data/models/music_query.dart';
import '../../data/services/listening_history.dart';
import '../../data/services/music_catalog.dart';
import '../../widgets/track_row.dart';
import '../../widgets/filter_choice.dart';

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
  ChartRegion _region = ChartRegion.global;
  Timer? _debounce;
  final _client = http.Client();
  late final _catalog = MusicCatalog(_client);
  late final _library = widget.db.watchAllTracks();
  late Future<ChartResults> _popular = _catalog.popularWithCache();
  Future<RankedSearch>? _artistResults;

  void _searchChart(String value) {
    _debounce?.cancel();
    final query = value.trim();
    setState(() => _artistResults = null);
    if (query.length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 420), () {
      setState(() => _artistResults = _catalog.searchRecordings(query));
    });
  }

  void _refresh({ChartRegion? region, String? genre}) {
    setState(() {
      _region = region ?? _region;
      _genre = genre;
      _popular = _catalog.popularWithCache(region: _region, genre: genre);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _chartSearch.dispose();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 520;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, children: [
          for (var i = 0; i < _categories.length; i++)
            FilterChoice(
              icon: compact ? null : _categories[i].$2,
              label: context.tr(_categories[i].$1),
              selected: _category == i,
              onSelected: () => setState(() => _category = i),
            ),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: switch (_category) {
            0 => Column(children: [
                TextField(
                  controller: _chartSearch,
                  onChanged: _searchChart,
                  decoration: InputDecoration(
                    hintText: context.tr('Найти в чарте'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _chartSearch.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: context.tr('Очистить поиск'),
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _chartSearch.clear();
                              _searchChart('');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Wrap(spacing: 6, children: [
                    for (final (label, region) in const [
                      ('Мир', ChartRegion.global),
                      ('Россия', ChartRegion.russia),
                    ])
                      FilterChoice(
                        label: context.tr(label),
                        selected: _region == region,
                        onSelected: () {
                          if (_region != region) _refresh(region: region);
                        },
                      ),
                  ]),
                  if (_region == ChartRegion.global) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                        height: 24,
                        child: VerticalDivider(
                            width: 10,
                            color:
                                Theme.of(context).colorScheme.outlineVariant)),
                    const SizedBox(width: 4),
                    Expanded(
                        child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(spacing: 6, children: [
                        for (final (label, genre) in _genres)
                          FilterChoice(
                            label: context.tr(label),
                            selected: _genre == genre,
                            onSelected: () {
                              if (_genre != genre) _refresh(genre: genre);
                            },
                          ),
                      ]),
                    )),
                  ],
                ]),
                const SizedBox(height: 8),
                Expanded(
                    child: FutureBuilder<ChartResults>(
                        future: _popular,
                        builder: (context, chart) => FutureBuilder<
                                RankedSearch>(
                            future: _artistResults,
                            builder: (context, lookup) {
                              final query = MusicQuery(_chartSearch.text);
                              final searching = query.text.length >= 2;
                              final found =
                                  lookup.connectionState == ConnectionState.done
                                      ? (lookup.data?.page.tracks ??
                                          const <CatalogTrack>[])
                                      : const <CatalogTrack>[];
                              final results = chart.connectionState ==
                                      ConnectionState.done
                                  ? chart.data?.tracks ?? const <CatalogTrack>[]
                                  : const <CatalogTrack>[];
                              final ranked = lookup.data?.ranked == true;
                              final matches =
                                  (found.isNotEmpty ? found : results)
                                      .asMap()
                                      .entries
                                      .where((entry) =>
                                          !searching ||
                                          query.matches(entry.value.track.title,
                                              entry.value.track.artist))
                                      .toList();
                              if (matches.isEmpty) {
                                if (chart.connectionState ==
                                        ConnectionState.waiting ||
                                    lookup.connectionState ==
                                        ConnectionState.waiting) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                                return Center(
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                      Text(
                                          context.tr(chart.hasError ||
                                                  lookup.hasError
                                              ? 'Каталог временно недоступен.'
                                              : 'Ничего не найдено'),
                                          textAlign: TextAlign.center),
                                      if (chart.hasError || lookup.hasError)
                                        TextButton(
                                            onPressed: () {
                                              if (searching) {
                                                _searchChart(query.text);
                                              }
                                              if (chart.hasError) {
                                                _refresh(genre: _genre);
                                              }
                                            },
                                            child:
                                                Text(context.tr('Повторить'))),
                                    ]));
                              }
                              final queue = matches
                                  .map((row) => row.value.track)
                                  .toList();
                              final playable = queue
                                  .where(
                                      (track) => track.externalProvider == null)
                                  .firstOrNull;
                              final colors = Theme.of(context).colorScheme;
                              final cached =
                                  found.isEmpty && chart.data?.cached == true;
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
                                            track: queue.first, size: 48),
                                        const SizedBox(width: 14),
                                        Expanded(
                                            child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                context.tr(found.isNotEmpty
                                                    ? ranked
                                                        ? 'Популярные совпадения'
                                                        : 'Найденные треки'
                                                    : _region ==
                                                            ChartRegion.russia
                                                        ? 'Топ треков в России'
                                                        : 'Топ треков'),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700)),
                                            Text(context.tr(
                                                found.isNotEmpty
                                                    ? ranked
                                                        ? 'По популярности · Deezer'
                                                        : 'Подборка · Apple Music'
                                                    : cached
                                                        ? 'Сохранённая подборка · {provider}'
                                                        : _region == ChartRegion.russia
                                                            ? 'Чарт · Apple Music'
                                                            : 'По числу прослушиваний · Audius',
                                                {
                                                  'provider':
                                                      chart.data?.source ??
                                                          'Audius'
                                                })),
                                          ],
                                        )),
                                        if (cached)
                                          IconButton(
                                            icon: const Icon(Icons.refresh),
                                            tooltip: context.tr('Повторить'),
                                            onPressed: () =>
                                                _refresh(genre: _genre),
                                          ),
                                        if (playable != null)
                                          IconButton.filled(
                                            icon: const Icon(
                                                Icons.play_arrow_rounded),
                                            tooltip: context
                                                .tr('Воспроизвести подборку'),
                                            onPressed: () => playHistoryTrack(
                                                context, queue, playable),
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
                            }))),
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

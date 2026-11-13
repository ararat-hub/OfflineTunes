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
  static const _categories = [
    ('Популярное', Icons.trending_up),
    ('Часто слушаете', Icons.replay),
    ('Для вас', Icons.auto_awesome_outlined),
  ];
  int _category = 0;
  final _client = http.Client();
  late final _catalog = MusicCatalog(_client);
  late final _library = widget.db.watchAllTracks();
  late Future<List<CatalogTrack>> _popular = _catalog.popular();

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
        LayoutBuilder(builder: (context, constraints) {
          const spacing = 8.0;
          final columns = constraints.maxWidth >= 520 ? 3 : 1;
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(spacing: spacing, runSpacing: spacing, children: [
            for (var i = 0; i < _categories.length; i++)
              SizedBox(
                width: width,
                child: _CategoryCard(
                  label: context.tr(_categories[i].$1),
                  icon: _categories[i].$2,
                  selected: _category == i,
                  onSelect: () => setState(() => _category = i),
                ),
              ),
          ]);
        }),
        const SizedBox(height: 12),
        Expanded(
          child: switch (_category) {
            0 => FutureBuilder<List<CatalogTrack>>(
                future: _popular,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(context.tr('Каталог временно недоступен.')),
                        TextButton(
                          onPressed: () =>
                              setState(() => _popular = _catalog.popular()),
                          child: Text(context.tr('Повторить')),
                        ),
                      ],
                    ));
                  }
                  final results = snapshot.data ?? [];
                  if (results.isEmpty) {
                    return Center(child: Text(context.tr('Ничего не найдено')));
                  }
                  final queue = results.map((item) => item.track).toList();
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                          child: Text(
                              context.tr('По числу прослушиваний · Audius'),
                              style: Theme.of(context).textTheme.labelMedium),
                        ),
                        Expanded(
                            child: ListView.builder(
                          itemCount: queue.length,
                          itemBuilder: (_, index) => TrackRow(
                            track: queue[index],
                            duration: results[index].duration,
                            playCount: results[index].plays,
                            onPlay: () =>
                                playHistoryTrack(context, queue, queue[index]),
                          ),
                        )),
                      ]);
                }),
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

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? colors.primaryContainer : colors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color: selected ? colors.primary : colors.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(children: [
              Icon(icon, size: 20, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
          ),
        ),
      ),
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

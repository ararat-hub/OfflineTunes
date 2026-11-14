import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../core/localization.dart';
import '../../widgets/track_row.dart';
import '../../data/db/app_database.dart';
import '../../data/models/playback_track.dart';
import '../../data/models/music_query.dart';
import '../../data/services/music_catalog.dart';
import '../../data/services/favorite_tracks.dart';
import '../../data/services/offline_tracks.dart';

enum _Scope { all, library, favorites }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  final _client = http.Client();
  late final _catalog = MusicCatalog(_client);
  List<PlaybackTrack> _local = [];
  final _online = <CatalogSource, List<CatalogTrack>>{};
  String _submitted = '';
  int _generation = 0;
  final _offsets = <CatalogSource, int>{};
  bool _loading = false;
  bool _catalogFailed = false;
  _Scope _scope = _Scope.all;
  Timer? _debounce;

  void _scheduleSearch(String value) {
    _debounce?.cancel();
    // Ignore responses for the previous query as soon as the text changes.
    _generation++;
    if (value.trim().isEmpty || _scope == _Scope.favorites) {
      unawaited(_search());
      return;
    }
    setState(() {
      _loading = true;
      _catalogFailed = false;
    });
    _debounce =
        Timer(const Duration(milliseconds: 400), () => unawaited(_search()));
  }

  Future<void> _search({bool append = false}) async {
    if (!append) _debounce?.cancel();
    final query = append ? _submitted : _query.text.trim();
    if (append && (_offsets.isEmpty || _loading)) return;
    final requests = append
        ? Map.of(_offsets)
        : {
            if (_scope == _Scope.all)
              for (final source in CatalogSource.values) source: 0
          };
    final generation = ++_generation;
    setState(() {
      if (!append) {
        _local = [];
        _online.clear();
        _offsets.clear();
      }
      _submitted = query;
      _loading = query.isNotEmpty && _scope != _Scope.favorites;
      _catalogFailed = false;
    });
    if (query.isEmpty || _scope == _Scope.favorites) return;

    final offline = context.read<OfflineTracks?>();
    Future<void> loadLocal() async {
      try {
        final items = await widget.db.searchTracks(query);
        await offline?.ready;
        if (!mounted || generation != _generation) return;
        final search = MusicQuery(query);
        final results = <String, PlaybackTrack>{
          for (final track in items.map(PlaybackTrack.fromTrack))
            if (track.path.isNotEmpty) track.identity: track,
          for (final track in offline?.tracks ?? const <PlaybackTrack>[])
            if (search.matches(track.title, track.artist))
              track.identity: track,
        };
        setState(() => _local = results.values.toList());
      } catch (error) {
        debugPrint('Library search: $error');
      }
    }

    Future<void> loadRemote(CatalogSource source, int offset) async {
      try {
        final result =
            await _catalog.search(query, offset: offset, source: source);
        if (!mounted || generation != _generation) return;
        final current = _online[source] ?? [];
        final known = current.map((item) => item.track.path).toSet();
        setState(() {
          _online[source] = [
            ...current,
            ...result.tracks.where((item) => known.add(item.track.path)),
          ];
          final next = result.nextOffset;
          if (next == null || next <= offset) {
            _offsets.remove(source);
          } else {
            _offsets[source] = next;
          }
        });
      } catch (error) {
        debugPrint('${source.name} search: $error');
        if (mounted && generation == _generation) {
          setState(() => _catalogFailed = true);
        }
      }
    }

    await Future.wait([
      if (!append) loadLocal(),
      for (final request in requests.entries)
        loadRemote(request.key, request.value),
    ]);
    if (mounted && generation == _generation) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _generation++;
    _query.dispose();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = MusicQuery(_submitted);
    final favoriteMatches = _scope == _Scope.favorites
        ? context.watch<FavoriteTracks>().tracks.where((track) {
            return _submitted.isEmpty ||
                search.matches(track.title, track.artist);
          }).toList()
        : const <PlaybackTrack>[];
    final emptyOnline = _online.values.every((items) => items.isEmpty);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
      child: Column(children: [
        TextField(
          controller: _query,
          textInputAction: TextInputAction.search,
          onChanged: _scheduleSearch,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            hintText: context.tr('Введите название трека или исполнителя...'),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: context.tr('Поиск'),
              onPressed: _search,
              icon: const Icon(Icons.arrow_forward),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
            alignment: Alignment.centerLeft,
            child: Wrap(spacing: 8, children: [
              for (final item in const [
                (_Scope.all, 'Все треки'),
                (_Scope.library, 'Медиатека'),
                (_Scope.favorites, 'Избранное')
              ])
                ChoiceChip(
                    label: Text(context.tr(item.$2)),
                    selected: _scope == item.$1,
                    onSelected: (_) {
                      _scope = item.$1;
                      _search();
                    }),
            ])),
        const SizedBox(height: 8),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: CustomScrollView(
            slivers: [
              if (_scope == _Scope.favorites && favoriteMatches.isNotEmpty)
                SliverList.builder(
                    itemCount: favoriteMatches.length,
                    itemBuilder: (_, index) => TrackRow(
                          track: favoriteMatches[index],
                          onPlay: () => playHistoryTrack(
                              context, favoriteMatches, favoriteMatches[index]),
                        )),
              if (_scope != _Scope.favorites && _local.isNotEmpty) ...[
                _label(context.tr('В вашей медиатеке')),
                SliverList.builder(
                  itemCount: _local.length,
                  itemBuilder: (_, i) => TrackRow(
                    track: _local[i],
                    onPlay: () => playHistoryTrack(context, _local, _local[i]),
                  ),
                ),
              ],
              for (final source in CatalogSource.values)
                if (_online[source]?.isNotEmpty == true)
                  _onlineSection(context, _online[source]!),
              if (_catalogFailed && emptyOnline)
                SliverToBoxAdapter(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('Каталог временно недоступен.')),
                    trailing: TextButton(
                        onPressed: _search,
                        child: Text(context.tr('Повторить'))),
                  ),
                ),
              if (!_loading &&
                  !_catalogFailed &&
                  _local.isEmpty &&
                  emptyOnline &&
                  favoriteMatches.isEmpty)
                _label(context.tr(
                    _submitted.isEmpty && _scope != _Scope.favorites
                        ? 'Введите название трека или исполнителя...'
                        : 'Ничего не найдено')),
              if (!_loading && _offsets.isNotEmpty)
                SliverToBoxAdapter(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => _search(append: true),
                      child: Text(context.tr('Ещё результаты')),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _onlineSection(BuildContext context, List<CatalogTrack> items) {
    final queue = items.map((item) => item.track).toList();
    return SliverList.builder(
      itemCount: items.length,
      itemBuilder: (_, i) => TrackRow(
        track: queue[i],
        duration: items[i].duration,
        onPlay: () => playHistoryTrack(context, queue, queue[i]),
      ),
    );
  }

  SliverToBoxAdapter _label(String text) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child:
              Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
}

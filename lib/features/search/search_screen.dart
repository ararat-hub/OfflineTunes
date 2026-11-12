import '../../core/localization.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../data/models/search_track.dart';
import '../../data/models/playback_track.dart';
import '../../data/services/audio_player_service.dart';
import '../../data/db/app_database.dart';

class SearchScreen extends StatefulWidget {
  final AppDatabase db;

  const SearchScreen({super.key, required this.db});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<SearchTrack> _searchResults = [];
  bool _isLoading = false;
  String? _error;
  bool _hasSearched = false;
  int _requestId = 0;

  @override
  void dispose() {
    _requestId++;
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    final requestId = ++_requestId;
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
        _hasSearched = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
          'https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&media=music&limit=25');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (!mounted || requestId != _requestId) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        setState(() {
          _searchResults = results
              .map((item) {
                return SearchTrack(
                  id: item['trackId'].toString(),
                  title: item['trackName'] ?? context.tr('Без названия'),
                  artist: item['artistName'] ??
                      context.tr('Неизвестный исполнитель'),
                  audioUrl: item['previewUrl'] ?? '',
                  coverUrl: item['artworkUrl100'],
                );
              })
              .where((track) => track.audioUrl.isNotEmpty)
              .toList();
        });
      } else {
        throw Exception('Сервер вернул код ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _searchResults = [];
        _error = 'Поиск недоступен. Проверьте подключение и повторите запрос.';
      });
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Поиск музыки — превью'),
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onSubmitted: (_) => _performSearch(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText:
                    context.tr('Введите название трека или исполнителя...'),
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.black26,
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  onPressed: _performSearch,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white))
                  : _searchResults.isEmpty
                      ? Center(
                          child: Text(
                            _error != null
                                ? context.tr(_error!)
                                : (_hasSearched
                                    ? context.tr('Ничего не найдено')
                                    : context.tr(
                                        'Введите запрос и нажмите Enter или стрелочку')),
                            style: const TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final track = _searchResults[index];
                            return ListTile(
                              leading: track.coverUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(track.coverUrl!,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const SizedBox(
                                                  width: 48,
                                                  height: 48,
                                                  child:
                                                      Icon(Icons.music_note))),
                                    )
                                  : Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.music_note,
                                          color: Colors.white),
                                    ),
                              title: Text(track.title,
                                  style: const TextStyle(color: Colors.white)),
                              subtitle: Text(track.artist,
                                  style:
                                      const TextStyle(color: Colors.white54)),
                              trailing: IconButton(
                                icon: const Icon(Icons.play_arrow_rounded,
                                    color: Colors.white, size: 30),
                                onPressed: () {
                                  audioService.playQueue(
                                      _searchResults
                                          .map((item) => PlaybackTrack(
                                                path: item.audioUrl,
                                                title: item.title,
                                                artist: item.artist,
                                              ))
                                          .toList(),
                                      index: index);
                                },
                              ),
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

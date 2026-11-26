import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/playback_track.dart';
import '../models/music_query.dart';
import '../models/media_link.dart';

enum CatalogSource { recordings, audius, commons, zaycev }

enum ChartRegion { global, russia }

typedef ChartResults = ({
  List<CatalogTrack> tracks,
  bool cached,
  String source
});
typedef RankedSearch = ({CatalogPage page, bool ranked});

class MusicCatalog {
  MusicCatalog(this._client);

  final http.Client _client;
  static const _host = 'commons.wikimedia.org';
  static const userAgent = 'oTune (https://github.com/ararat-hub/OfflineTunes)';
  static const _audiusHosts = [
    'api.audius.co',
    'discoveryprovider.audius.co',
    'discoveryprovider2.audius.co',
  ];
  static const _popularCacheKey = 'audius_popular_v1';
  static const _russiaCacheKey = 'audius_russian_popular_v1';

  Future<CatalogPage> search(String query,
      {int offset = 0, CatalogSource source = CatalogSource.commons}) async {
    final term = query.trim();
    if (term.isEmpty) return const CatalogPage([], null);
    if (source == CatalogSource.recordings) {
      return (await searchRecordings(term, offset: offset)).page;
    }
    if (source == CatalogSource.audius) return _searchAudius(term, offset);
    if (source == CatalogSource.zaycev) return _searchZaycev(term, offset);
    final uri = Uri.https(_host, '/w/api.php', {
      'action': 'query',
      'format': 'json',
      'formatversion': '2',
      'generator': 'search',
      'gsrnamespace': '6',
      'gsrsearch': '$term filetype:audio',
      'gsrlimit': '30',
      'gsroffset': '$offset',
      'prop': 'imageinfo',
      'iiprop': 'url|size|mime|extmetadata',
      'iiextmetadatafilter': 'Artist|LicenseShortName',
    });
    final page = parsePage(await _request(uri));
    final queryWords = MusicQuery(term);
    return CatalogPage(
        page.tracks
            .where((item) =>
                queryWords.matches(item.track.title, item.track.artist))
            .toList(),
        page.nextOffset);
  }

  Future<CatalogPage> _searchZaycev(String term, int offset) async {
    final query = MusicQuery(term);
    final primary = await _zaycevPage(term, offset);
    final cyrillic = query.cyrillicVariant;
    if (offset == 0 &&
        primary.tracks.isEmpty &&
        cyrillic != null &&
        cyrillic != term) {
      return _zaycevPage(cyrillic, offset);
    }
    return primary;
  }

  Future<CatalogPage> _zaycevPage(String term, int offset) async {
    final endpoint =
        Uri.https(MediaLink.zaycevHost, '/api/external/pages/search/tracks', {
      'q': term,
      'page': '${offset + 1}',
      'limit': '50',
    });
    try {
      final data =
          await _request(endpoint, timeout: const Duration(seconds: 5));
      if (data is! Map) throw const FormatException('Invalid Zaycev response');
      if (data['popularInSearch'] == true) return const CatalogPage([], null);
      return _parseZaycevPage(data['trackIds'], data['tracksInfo'],
          data['pagesCount'], term, offset);
    } on Exception {
      // The public search page provides the same catalogue when the API fails.
    }
    final uri = Uri.https(MediaLink.zaycevHost, '/search.html', {
      'query_search': term,
      'type': 'track',
      if (offset > 0) 'tracks-page': '${offset + 1}',
    });
    final response = await _client.get(uri,
        headers: {'User-Agent': userAgent}).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw http.ClientException('${uri.host}: ${response.statusCode}', uri);
    }
    return parseZaycevSearch(utf8.decode(response.bodyBytes), term, offset);
  }

  static CatalogPage parseZaycevSearch(String html, String term, int offset) {
    final data =
        RegExp(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', dotAll: true)
            .firstMatch(html)
            ?.group(1);
    if (data == null) throw const FormatException('Missing search data');
    final decoded = jsonDecode(data);
    final properties = decoded is Map ? decoded['props'] : null;
    final initial = properties is Map ? properties['initialReduxState'] : null;
    final state = initial is Map ? initial['playlist'] : null;
    final groups = state is Map ? state['trackIds'] : null;
    final status = state is Map ? state['status'] : null;
    if (groups is! Map) {
      throw const FormatException('Invalid search data');
    }
    final key = groups.keys
        .whereType<String>()
        .where((key) => key.startsWith('search_'))
        .firstOrNull;
    if (key == null) return const CatalogPage([], null);
    final paging = status is Map ? status[key] : null;
    return _parseZaycevPage(groups[key], state['info'],
        paging is Map ? paging['pagesCount'] : null, term, offset);
  }

  static CatalogPage _parseZaycevPage(
      Object? ids, Object? info, Object? pages, String term, int offset) {
    if (ids is! List || info is! Map) {
      throw const FormatException('Invalid track list');
    }

    final query = MusicQuery(term);
    final tracks = <CatalogTrack>[];
    final seen = <int>{};
    for (final value in ids) {
      final id = int.tryParse('$value');
      if (id == null || id <= 0 || !seen.add(id)) continue;
      final item = info['$id'];
      if (item is! Map || item['playbackEnabled'] != true) continue;
      final title = item['track'];
      final artist = item['artistName'];
      final time = item['duration'];
      if (title is! String ||
          artist is! String ||
          time is! String ||
          !query.matches(title, artist)) {
        continue;
      }
      final parts = time.split(':').map(int.tryParse).toList();
      if (parts.length != 2 || parts.any((part) => part == null)) continue;
      final duration = Duration(minutes: parts[0]!, seconds: parts[1]!);
      if (duration <= Duration.zero) continue;
      final path = MediaLink.zaycevTrackPage(id).toString();
      tracks.add(CatalogTrack(
          PlaybackTrack(
            path: path,
            title: title,
            artist: artist,
            artwork: _https(item['imageJpg']) ?? _https(item['imageWebp']),
            sourcePage: path,
            downloadUrl: item['downloadEnabled'] == true ? path : null,
          ),
          duration));
    }
    tracks.sort((a, b) => query
        .score(b.track.title, b.track.artist)
        .compareTo(query.score(a.track.title, a.track.artist)));
    return CatalogPage(
        tracks, pages is int && pages > offset + 1 ? offset + 1 : null);
  }

  Future<RankedSearch> searchRecordings(String term, {int offset = 0}) async {
    final languageQuery = MusicQuery(term);
    final cyrillic = languageQuery.cyrillicVariant;
    final deezerRequest = _searchDeezer(term, offset)
        .then<({CatalogPage? page, Object? error})>(
            (page) => (page: page, error: null),
            onError: (Object error) => (page: null, error: error));
    final apple =
        cyrillic == null ? null : await _searchApple(cyrillic, offset);
    final deezer = await deezerRequest;
    final page = deezer.page;
    if (page == null || page.tracks.isEmpty) {
      if (apple != null && apple.tracks.isNotEmpty) {
        return (page: apple, ranked: false);
      }
      if (page != null) return (page: page, ranked: false);
      if (apple != null) return (page: apple, ranked: false);
      throw deezer.error!;
    }
    if (apple == null || apple.tracks.isEmpty) {
      return (page: page, ranked: true);
    }
    // A chart ranks compositions. Display the linked storefront's complete
    // metadata so its edition and artwork always belong to the same release.
    final appleTracks = <(String, String), CatalogTrack>{};
    for (final candidate in apple.tracks) {
      if (candidate.track.artwork == null) continue;
      appleTracks.putIfAbsent(_recordingKey(candidate.track), () => candidate);
    }
    final seen = <String>{};
    final ordered = <CatalogTrack>[];
    for (final item in page.tracks) {
      final match = appleTracks[_recordingKey(item.track)];
      final preferred = match == null
          ? item
          : CatalogTrack(match.track, match.duration, rank: item.rank);
      if (seen.add(preferred.track.identity)) ordered.add(preferred);
    }
    return (page: CatalogPage(ordered, page.nextOffset), ranked: true);
  }

  static (String, String) _recordingKey(PlaybackTrack track) => (
        MusicQuery.normalize(track.title),
        MusicQuery.recordingArtist(track.artist)
      );

  Future<CatalogPage?> _searchApple(String term, int offset) async {
    if (offset != 0) return null;
    final uri = Uri.https('itunes.apple.com', '/search', {
      'term': term,
      'entity': 'song',
      'media': 'music',
      'country': 'RU',
      'limit': '40',
    });
    try {
      final payload = await _request(uri, timeout: const Duration(seconds: 5));
      final live = parseAppleResults(payload, term);
      if (live.tracks.isNotEmpty) return live;
    } on Exception {
      // A bundled index still offers official recording links when DNS fails.
    }
    final saved = await _russianRecordings;
    final fallback = parseAppleResults(saved, term);
    return fallback.tracks.isEmpty ? null : fallback;
  }

  static final _russianRecordings = rootBundle
      .loadString('assets/catalog/apple-russian-recordings.json')
      .then(jsonDecode);

  static CatalogPage parseAppleResults(Object? payload, String term) {
    final results = payload is Map ? payload['results'] : null;
    if (results is! List) {
      throw const FormatException('Invalid iTunes response');
    }
    final query = MusicQuery(term);
    final seen = <(String, String)>{};
    final tracks = <CatalogTrack>[];
    for (final entry in results.whereType<Map>()) {
      final title = entry['trackName'];
      final artist = entry['artistName'];
      final duration = entry['trackTimeMillis'];
      final url = _sourceLink(entry['trackViewUrl'], 'music.apple.com');
      if (title is! String ||
          artist is! String ||
          url == null ||
          !query.matches(title, artist)) {
        continue;
      }
      final track = PlaybackTrack(
          path: url,
          title: title,
          artist: artist,
          externalProvider: 'Apple Music',
          sourcePage: url,
          artwork: _https(entry['artworkUrl100']));
      if (!seen.add(_recordingKey(track))) continue;
      tracks.add(CatalogTrack(
          track,
          duration is int && duration > 0
              ? Duration(milliseconds: duration)
              : null));
    }
    return CatalogPage(tracks, null);
  }

  Future<CatalogPage> _searchDeezer(String term, int offset) async {
    const limit = 30;
    final query = MusicQuery(term);
    final terms = offset == 0 ? query.variants : [term];
    final responses = await Future.wait(terms.map((value) async {
      try {
        final uri = Uri.https('api.deezer.com', '/search/track', {
          'q': value,
          'index': '$offset',
          'limit': '$limit',
          'order': 'RANKING',
        });
        return (
          parseDeezerPage(await _request(uri), offset: offset, limit: limit),
          null
        );
      } on Exception catch (error) {
        return (null, error);
      }
    }));
    final pages = responses.map((item) => item.$1).nonNulls;
    if (pages.isEmpty && responses.isNotEmpty) throw responses.first.$2!;
    final seen = <String>{};
    final tracks = [
      for (final page in pages)
        for (final item in page.tracks)
          if (query.matches(item.track.title, item.track.artist) &&
              seen.add(item.track.identity))
            item,
    ]..sort((a, b) {
        final relevance = query
            .score(b.track.title, b.track.artist)
            .compareTo(query.score(a.track.title, a.track.artist));
        return relevance == 0
            ? (b.rank ?? 0).compareTo(a.rank ?? 0)
            : relevance;
      });
    return CatalogPage(tracks, responses.firstOrNull?.$1?.nextOffset);
  }

  Future<CatalogPage> _searchAudius(String term, int offset) async {
    final query = MusicQuery(term);
    final primary = await _audiusSearch(term, offset);
    bool relevant(CatalogTrack item) =>
        query.matches(item.track.title, item.track.artist);
    final tracks = primary.tracks.where(relevant).toList();
    if (offset != 0 || query.variants.length < 2) {
      return CatalogPage(tracks, primary.nextOffset);
    }
    if (tracks.length >= 6 && !query.hasArtistAlias) {
      return CatalogPage(tracks, primary.nextOffset);
    }
    final seen = tracks.map((item) => item.track.identity).toSet();
    for (final variant in query.variants.skip(1)) {
      if (variant == term) continue;
      try {
        final extra = await _audiusSearch(variant, 0);
        tracks.addAll(extra.tracks
            .where((item) => relevant(item) && seen.add(item.track.identity)));
      } on Exception {
        // The primary result remains usable if the alternate spelling fails.
      }
    }
    tracks.sort((a, b) => query
        .score(b.track.title, b.track.artist)
        .compareTo(query.score(a.track.title, a.track.artist)));
    return CatalogPage(tracks, primary.nextOffset);
  }

  Future<CatalogPage> _audiusSearch(String term, int offset) {
    const limit = 30;
    return _audiusPage(
        '/v1/tracks/search',
        {
          'query': term,
          'sort_method': 'relevant',
          'limit': '$limit',
          'offset': '$offset',
        },
        offset: offset,
        limit: limit);
  }

  Future<List<CatalogTrack>> popular({String? genre}) async {
    final page = await _audiusPage(
        '/v1/tracks/trending',
        {
          'time': 'allTime',
          'limit': '50',
          if (genre != null) 'genre': genre,
        },
        offset: 0,
        limit: 50);
    final tracks = page.tracks.where((track) => (track.plays ?? 0) > 0).toList()
      ..sort((a, b) => b.plays!.compareTo(a.plays!));
    return tracks.take(30).toList();
  }

  Future<ChartResults> popularWithCache(
      {String? genre, ChartRegion region = ChartRegion.global}) async {
    final preferences = await SharedPreferences.getInstance();
    final russia = region == ChartRegion.russia;
    const source = 'Audius';
    final key = russia
        ? _russiaCacheKey
        : genre == null
            ? _popularCacheKey
            : '${_popularCacheKey}_$genre';
    try {
      final tracks =
          russia ? await _russianChart() : await popular(genre: genre);
      if (tracks.isEmpty) throw const FormatException('Empty chart');
      await preferences.setString(
          key, jsonEncode(tracks.map((item) => item.toJson()).toList()));
      return (tracks: tracks, cached: false, source: source);
    } on Exception {
      final saved = preferences.getString(key);
      if (saved != null) {
        try {
          final records = jsonDecode(saved) as List;
          return (
            tracks: records.map((item) => CatalogTrack.fromJson(item)).toList(),
            cached: true,
            source: source
          );
        } catch (_) {
          // A stale or corrupt cache should not hide the catalog error.
        }
      }
      if (!russia) {
        final snapshot =
            await rootBundle.loadString('assets/catalog/audius-popular.json');
        final tracks =
            parseAudiusPage(jsonDecode(snapshot), offset: 0, limit: 100)
                .tracks
                .where((item) => genre == null || item.track.genre == genre)
                .take(30)
                .toList();
        if (tracks.isNotEmpty) {
          return (tracks: tracks, cached: true, source: source);
        }
      }
      rethrow;
    }
  }

  Future<List<CatalogTrack>> _russianChart() async {
    final pages = await Future.wait(
        ['russian pop', 'russian rap', 'russian rock'].map((query) async {
      try {
        return await _audiusSearch(query, 0);
      } on Exception {
        return null;
      }
    }));
    final cyrillic = RegExp(r'[а-яё]', caseSensitive: false);
    final candidates = pages.nonNulls
        .expand((page) => page.tracks)
        .where((item) =>
            (item.plays ?? 0) > 0 &&
            cyrillic.hasMatch('${item.track.artist} ${item.track.title}'))
        .toList()
      ..sort((a, b) => b.plays!.compareTo(a.plays!));
    final seen = <(String, String)>{};
    return candidates
        .where((item) => seen.add(_recordingKey(item.track)))
        .take(30)
        .toList();
  }

  static CatalogPage parseDeezerPage(Object? payload,
      {required int offset, required int limit}) {
    final data = payload is Map ? payload['data'] : null;
    if (data is! List) throw const FormatException('Invalid Deezer response');
    final items = <CatalogTrack>[];
    for (final item in data.whereType<Map>()) {
      final id = item['id'];
      final title = item['title'];
      final artist = item['artist'];
      if (id is! int ||
          id <= 0 ||
          title is! String ||
          title.isEmpty ||
          artist is! Map) {
        continue;
      }
      final album = item['album'];
      final duration = item['duration'];
      final rank = item['rank'];
      final url = Uri.https('www.deezer.com', '/track/$id').toString();
      final cover = album is Map ? _https(album['cover_medium']) : null;
      final coverUri = cover == null ? null : Uri.parse(cover);
      items.add(CatalogTrack(
          PlaybackTrack(
              path: url,
              title: title,
              artist: artist['name']?.toString() ?? '',
              sourcePage: url,
              artwork: cover,
              artworkAlternatives: [
                if (coverUri?.host == 'cdn-images.dzcdn.net')
                  coverUri!.replace(host: 'cdn-images.deezer.com').toString(),
                if (album is Map)
                  if (_https(album['cover_small']) case final String small)
                    small,
              ],
              externalProvider: 'Deezer'),
          duration is int && duration > 0 ? Duration(seconds: duration) : null,
          rank: rank is int ? rank : null));
    }
    return CatalogPage(
        items, data.length >= limit ? offset + data.length : null);
  }

  static String? _sourceLink(Object? value, String host) {
    final url = _https(value);
    return url != null && Uri.parse(url).host == host ? url : null;
  }

  Future<CatalogPage> _audiusPage(String path, Map<String, String> parameters,
      {required int offset, required int limit}) async {
    Future<CatalogPage> request(String host) async {
      final response = await _request(
          Uri.https(host, path, {...parameters, 'app_name': 'OfflineTunes'}),
          timeout: const Duration(seconds: 5));
      return parseAudiusPage(response, offset: offset, limit: limit);
    }

    try {
      return await request(_audiusHosts.first);
    } on Exception catch (error) {
      final fallbacks =
          await Future.wait(_audiusHosts.skip(1).map((host) async {
        try {
          return await request(host);
        } on Exception {
          return null;
        }
      }));
      return fallbacks.nonNulls.firstOrNull ?? (throw error);
    }
  }

  Future<Object?> _request(Uri uri,
      {Duration timeout = const Duration(seconds: 8)}) async {
    final response = await _client
        .get(uri, headers: {'User-Agent': userAgent}).timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('${uri.host}: ${response.statusCode}', uri);
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  static CatalogPage parseAudiusPage(Object? payload,
      {required int offset, required int limit}) {
    final data = payload is Map ? payload['data'] : null;
    final items = data is Map ? data['tracks'] : data;
    if (items is! List) throw const FormatException('Invalid Audius response');
    final result = <CatalogTrack>[];
    for (final item in items.whereType<Map>()) {
      final id = item['id'];
      final name = item['title'];
      final duration = item['duration'];
      final permalink = item['permalink'];
      if (item['is_streamable'] == false ||
          item['is_available'] == false ||
          item['is_stream_gated'] == true ||
          (item['stream_conditions'] is Map &&
              (item['stream_conditions'] as Map).isNotEmpty) ||
          item['is_unlisted'] == true ||
          id is! String ||
          !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(id) ||
          name is! String ||
          name.trim().isEmpty ||
          duration is! num ||
          !duration.isFinite ||
          duration <= 0 ||
          permalink is! String ||
          !permalink.startsWith('/') ||
          permalink.startsWith('//')) {
        continue;
      }
      final user = item['user'];
      final plays = item['play_count'];
      final images = item['artwork'];
      final artwork = images is Map
          ? _https(images['150x150']) ?? _https(images['480x480'])
          : null;
      final mirrors = images is Map ? images['mirrors'] : null;
      final artworkUri = artwork == null ? null : Uri.parse(artwork);
      final canDownload =
          item['is_downloadable'] == true && item['is_download_gated'] == false;
      result.add(CatalogTrack(
        PlaybackTrack(
          path: Uri.https('api.audius.co', '/v1/tracks/$id/stream',
              {'app_name': 'OfflineTunes'}).toString(),
          title: name,
          artist: user is Map ? user['name']?.toString() ?? '' : '',
          genre: item['genre']?.toString(),
          sourcePage: Uri.https('audius.co', permalink).toString(),
          artwork: artwork,
          artworkAlternatives: [
            if (artworkUri != null && mirrors is List)
              for (final node in mirrors.take(4))
                if (_https(node) case final String url)
                  Uri.parse(url).replace(path: artworkUri.path).toString(),
          ],
          downloadUrl: canDownload
              ? Uri.https('api.audius.co', '/v1/tracks/$id/download',
                  {'app_name': 'oTune', 'original': 'false'}).toString()
              : null,
        ),
        Duration(milliseconds: (duration * 1000).round()),
        plays: plays is int && plays >= 0 ? plays : null,
      ));
    }
    return CatalogPage(
        result, items.length >= limit ? offset + items.length : null);
  }

  static CatalogPage parsePage(Object? payload) {
    if (payload is! Map || payload.containsKey('error')) {
      throw const FormatException('Invalid Wikimedia Commons response');
    }
    final query = payload['query'];
    final rawPages = query is Map ? query['pages'] : null;
    final pages =
        rawPages is List ? rawPages.whereType<Map>().toList() : <Map>[];
    pages.sort((a, b) => (int.tryParse('${a['index']}') ?? 0)
        .compareTo(int.tryParse('${b['index']}') ?? 0));
    final tracks = <CatalogTrack>[];
    for (final page in pages) {
      final details = page['imageinfo'];
      if (details is! List || details.isEmpty || details.first is! Map) {
        continue;
      }
      final file = details.first as Map;
      final mime = file['mime'];
      final duration = file['duration'];
      if (mime is! String ||
          !(mime.startsWith('audio/') || mime == 'application/ogg') ||
          duration is! num ||
          !duration.isFinite ||
          duration < 45) {
        continue;
      }
      final media = Uri.tryParse(file['url']?.toString() ?? '');
      final source = Uri.tryParse(file['descriptionurl']?.toString() ?? '');
      if (media == null ||
          media.scheme != 'https' ||
          media.host != 'upload.wikimedia.org' ||
          source == null ||
          source.scheme != 'https' ||
          source.host != _host) {
        continue;
      }
      final metadata = file['extmetadata'];
      if (metadata is! Map) continue;
      final license = _metadata(metadata, 'LicenseShortName');
      if (license != 'Public domain' &&
          !RegExp(r'^CC (0|BY(?:-SA)?)(?: [\d.]+)?$').hasMatch(license) &&
          !license.startsWith('CC0 ')) {
        continue;
      }
      final title = (page['title']?.toString() ?? '')
          .replaceFirst(RegExp(r'^File:'), '')
          .replaceFirst(RegExp(r'\.[A-Za-z0-9]+$'), '')
          .trim();
      if (title.isEmpty) continue;
      tracks.add(CatalogTrack(
        PlaybackTrack(
          path: Uri(
                  scheme: 'https',
                  host: media.host,
                  pathSegments: media.pathSegments)
              .toString(),
          title: title,
          artist: _metadata(metadata, 'Artist'),
          sourcePage: source.toString(),
          license: license,
          downloadUrl: media.toString(),
        ),
        Duration(milliseconds: (duration * 1000).round()),
      ));
    }
    final continuation = payload['continue'];
    final next = continuation is Map ? continuation['gsroffset'] : null;
    return CatalogPage(tracks, next is int ? next : null);
  }

  static String _metadata(Map metadata, String key) {
    final entry = metadata[key];
    final value = entry is Map ? entry['value'] : null;
    if (value is! String) return '';
    return value
        .replaceAll(RegExp('<[^>]*>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String? _https(Object? value) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? value
        : null;
  }
}

class CatalogTrack {
  const CatalogTrack(this.track, this.duration, {this.plays, this.rank});
  final PlaybackTrack track;
  final Duration? duration;
  final int? plays;
  final int? rank;

  Map<String, Object?> toJson() => {
        'track': track.toJson(),
        'ms': duration?.inMilliseconds,
        'plays': plays,
        if (rank != null) 'rank': rank
      };

  factory CatalogTrack.fromJson(Map<String, dynamic> json) => CatalogTrack(
      PlaybackTrack.fromJson(json['track'] as Map<String, dynamic>),
      json['ms'] is int ? Duration(milliseconds: json['ms'] as int) : null,
      plays: json['plays'] as int?,
      rank: json['rank'] as int?);
}

class CatalogPage {
  const CatalogPage(this.tracks, this.nextOffset);
  final List<CatalogTrack> tracks;
  final int? nextOffset;
}

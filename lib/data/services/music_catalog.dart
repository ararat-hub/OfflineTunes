import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/playback_track.dart';

enum CatalogSource { audius, commons }

class MusicCatalog {
  MusicCatalog(this._client);

  final http.Client _client;
  static const _host = 'commons.wikimedia.org';
  static const userAgent =
      'OfflineTunes/1.4 (https://github.com/ararat-hub/OfflineTunes)';

  Future<CatalogPage> search(String query,
      {int offset = 0, CatalogSource source = CatalogSource.commons}) async {
    final term = query.trim();
    if (term.isEmpty) return const CatalogPage([], null);
    if (source == CatalogSource.audius) return _searchAudius(term, offset);
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
    return parsePage(await _request(uri));
  }

  Future<CatalogPage> _searchAudius(String term, int offset) async {
    const limit = 30;
    final uri = Uri.https('api.audius.co', '/v1/tracks/search', {
      'query': term,
      'limit': '$limit',
      'offset': '$offset',
      'app_name': 'OfflineTunes',
    });
    return parseAudiusPage(await _request(uri), offset: offset, limit: limit);
  }

  Future<List<CatalogTrack>> popular() async {
    final uri = Uri.https('api.audius.co', '/v1/tracks/trending', {
      'time': 'allTime',
      'limit': '100',
      'app_name': 'OfflineTunes',
    });
    final page = parseAudiusPage(await _request(uri), offset: 0, limit: 100);
    final tracks = page.tracks.where((track) => (track.plays ?? 0) > 0).toList()
      ..sort((a, b) => b.plays!.compareTo(a.plays!));
    return tracks.take(30).toList();
  }

  Future<Object?> _request(Uri uri) async {
    final response = await _client.get(uri, headers: {
      'User-Agent': userAgent
    }).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw http.ClientException('${uri.host}: ${response.statusCode}', uri);
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  static CatalogPage parseAudiusPage(Object? payload,
      {required int offset, required int limit}) {
    final items = payload is Map ? payload['data'] : null;
    if (items is! List) throw const FormatException('Invalid Audius response');
    final result = <CatalogTrack>[];
    for (final item in items.whereType<Map>()) {
      final id = item['id'];
      final name = item['title'];
      final duration = item['duration'];
      final permalink = item['permalink'];
      if (item['is_streamable'] != true ||
          item['is_stream_gated'] != false ||
          item['is_unlisted'] != false ||
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
      result.add(CatalogTrack(
        PlaybackTrack(
          path: Uri.https('api.audius.co', '/v1/tracks/$id/stream',
              {'app_name': 'OfflineTunes'}).toString(),
          title: name,
          artist: user is Map ? user['name']?.toString() ?? '' : '',
          genre: item['genre']?.toString(),
          sourcePage: Uri.https('audius.co', permalink).toString(),
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
    pages.sort((a, b) =>
        ((a['index'] as int?) ?? 0).compareTo((b['index'] as int?) ?? 0));
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
}

class CatalogTrack {
  const CatalogTrack(this.track, this.duration, {this.plays});
  final PlaybackTrack track;
  final Duration duration;
  final int? plays;
}

class CatalogPage {
  const CatalogPage(this.tracks, this.nextOffset);
  final List<CatalogTrack> tracks;
  final int? nextOffset;
}

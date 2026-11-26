import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/media_link.dart';
import 'music_catalog.dart';

class ZaycevStreams {
  ZaycevStreams(this._client);

  final http.Client _client;
  static const _timeout = Duration(seconds: 8);
  static final _streamKey = RegExp(r'^[a-zA-Z0-9_-]{6,80}$');

  Future<String?> resolve(String path) => _resolve(path, download: false);

  Future<String?> resolveDownload(String path) =>
      _resolve(path, download: true);

  Future<String?> _resolve(String path, {required bool download}) async {
    final id = MediaLink.zaycevTrackId(path);
    if (id == null) return null;
    try {
      final meta = await _client
          .post(
              Uri.https(MediaLink.zaycevHost, '/api/external/track/filezmeta'),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': MusicCatalog.userAgent,
              },
              body: jsonEncode({
                'trackIds': ['$id'],
                'subscription': false,
              }))
          .timeout(_timeout);
      if (meta.statusCode != 200) return null;
      final payload = jsonDecode(meta.body);
      final tracks = payload is Map ? payload['tracks'] : null;
      if (tracks is! List) return null;
      final track = tracks
          .whereType<Map>()
          .where((entry) => int.tryParse('${entry['id']}') == id)
          .firstOrNull;
      final key = track?[download ? 'download' : 'streaming'];
      if (key is! String || !_streamKey.hasMatch(key)) return null;
      final action = download ? 'download' : 'play';
      final response = await _client.get(
          Uri.https(MediaLink.zaycevHost, '/api/external/track/$action/$key'),
          headers: {'User-Agent': MusicCatalog.userAgent}).timeout(_timeout);
      if (response.statusCode != 200) return null;
      final data = download ? null : jsonDecode(response.body);
      final url =
          download ? response.body.trim() : (data is Map ? data['url'] : null);
      final uri = url is String ? Uri.tryParse(url) : null;
      if (uri == null ||
          !uri.isScheme('https') ||
          !(download
              ? const {'zaycev.cdn.zerocdn.com', 'dl.zaycev.net'}
                  .contains(uri.host)
              : uri.host == 'dl.zaycev.net') ||
          uri.userInfo.isNotEmpty) {
        return null;
      }
      return uri.toString();
    } on Exception {
      return null;
    }
  }

  void dispose() => _client.close();
}

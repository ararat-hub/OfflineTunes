import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'music_catalog.dart';

class AudiusStreams {
  AudiusStreams(this._client);

  final http.Client _client;
  static const _timeout = Duration(seconds: 5);

  static String? trackId(String path) {
    final url = Uri.tryParse(path);
    if (url == null ||
        url.scheme != 'https' ||
        url.host != 'api.audius.co' ||
        url.userInfo.isNotEmpty) {
      return null;
    }
    return RegExp(r'^/v1/tracks/([A-Za-z0-9]+)/stream$')
        .firstMatch(url.path)
        ?.group(1);
  }

  Future<String?> resolve(String path) async {
    final id = trackId(path);
    if (id == null) return null;
    final direct = await _audioEndpoint(Uri.parse(path));
    if (direct != null) return direct.toString();

    final metadata = Uri.https(
        'api.audius.co', '/v1/tracks/$id', {'app_name': 'OfflineTunes'});
    try {
      final response = await _client.get(metadata,
          headers: {'User-Agent': MusicCatalog.userAgent}).timeout(_timeout);
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      final track = body is Map ? body['data'] : null;
      if (track is! Map ||
          track['id'] != id ||
          track['is_streamable'] != true ||
          track['is_stream_gated'] == true ||
          track['is_available'] == false) {
        return null;
      }
      final stream = track['stream'];
      if (stream is! Map) return null;
      final primary = _https(stream['url']);
      if (primary == null) return null;
      final mirrors = stream['mirrors'];
      final routes = <Uri>{primary};
      if (mirrors is List) {
        for (final mirror in mirrors.take(4)) {
          final host = _https(mirror);
          if (host != null) {
            routes.add(primary.replace(host: host.host, port: host.port));
          }
        }
      }
      final resolved = Completer<Uri?>();
      var remaining = routes.length;
      for (final route in routes) {
        unawaited(_audioEndpoint(route).then((uri) {
          remaining--;
          if (!resolved.isCompleted && (uri != null || remaining == 0)) {
            resolved.complete(uri);
          }
        }));
      }
      return (await resolved.future)?.toString();
    } on Exception {
      return null;
    }
  }

  Future<Uri?> _audioEndpoint(Uri initial) async {
    var uri = initial;
    try {
      for (var redirects = 0; redirects < 4; redirects++) {
        final request = http.Request('GET', uri)
          ..followRedirects = false
          ..headers['Range'] = 'bytes=0-1'
          ..headers['User-Agent'] = MusicCatalog.userAgent;
        final response = await _client.send(request).timeout(_timeout);
        await response.stream.listen((_) {}).cancel();
        if (response.statusCode >= 300 && response.statusCode < 400) {
          final location = response.headers['location'];
          if (location == null) return null;
          final next = _https(uri.resolve(location).toString());
          if (next == null) return null;
          uri = next;
          continue;
        }
        final type = response.headers['content-type'] ?? '';
        if ((response.statusCode == 206 || response.statusCode == 200) &&
            (type.startsWith('audio/') ||
                type.startsWith('application/octet-stream'))) {
          return uri;
        }
        return null;
      }
    } on Exception {
      // The next official route may use a different host.
    }
    return null;
  }

  static Uri? _https(Object? value) {
    final uri = value is String ? Uri.tryParse(value) : null;
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri
        : null;
  }

  void dispose() => _client.close();
}

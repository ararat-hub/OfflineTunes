import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:offlinetunes/data/models/playback_track.dart';
import 'package:offlinetunes/data/services/music_catalog.dart';
import 'package:offlinetunes/data/services/offline_tracks.dart';
import 'package:offlinetunes/data/services/zaycev_streams.dart';

const page = 'https://zaycev.net/pages/249741/24974150.shtml';
const media = 'https://zaycev.cdn.zerocdn.com/test.mp3?signature=temporary';
const recording = PlaybackTrack(
    path: page, downloadUrl: page, title: 'Юра, Юра', artist: 'CUPSIZE');
const id = '24974150';
const mp3Header = [73, 68, 51, 4, 0, 0, 0, 0, 0, 0, 255, 251];

http.Response jsonResponse(Object value) =>
    http.Response.bytes(utf8.encode(jsonEncode(value)), 200);

Map<String, Object?> entry(
        {String title = 'Юра, Юра', String artist = 'CUPSIZE'}) =>
    {
      'track': title,
      'artistName': artist,
      'duration': '02:12',
      'playbackEnabled': true,
      'downloadEnabled': true,
      'imageJpg': 'https://cdnimg.zaycev.net/test.jpg',
    };

Map<String, Object?> searchPage(Map<String, Object?> track,
        {int pages = 1, List<Object> ids = const [24974150]}) =>
    {
      'trackIds': ids,
      'tracksInfo': {id: track},
      'pagesCount': pages,
    };

http.Response credentials(
        {Object trackId = 24974150, Object? key = 'download-key'}) =>
    jsonResponse({
      'tracks': [
        {'id': trackId, 'download': key, 'streaming': 'stream-key'}
      ]
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('search can find downloadable recordings', () {
    for (final (query, title, artist) in const [
      ('Юра, Юра', 'Юра, Юра', 'CUPSIZE'),
      ('Юра Юра', 'Юра, Юра', 'CUPSIZE'),
      ('юра-юра', 'Юра, Юра', 'CUPSIZE'),
      ('ЮРА ЮРА', 'Юра, Юра', 'CUPSIZE'),
      ('  CUPSIZE  ', 'Юра, Юра', 'CUPSIZE'),
      ('CUPSIZE Юра, Юра', 'Юра, Юра', 'CUPSIZE'),
      ('Юра Юра CUPSIZE', 'Юра, Юра', 'CUPSIZE'),
      ('Баста Мама', 'Мама', 'Баста'),
      ('мама баста', 'Мама', 'Баста'),
      ('Баста Осень', 'Осень (Acoustic Version)', 'Баста'),
      ('МАТРАНГ', 'Медуза', 'МАТРАНГ'),
      ('Прекрасное далёко', 'Прекрасное далеко', 'Гостья'),
      ('НА ЧАСАХ НОЛЬ', 'На часах ноль-ноль', 'Dabro'),
      ('Dabro ноль ноль', 'На часах ноль-ноль', 'Dabro'),
      ('Би-2', 'Варвара', 'Би 2'),
    ]) {
      test(query, () async {
        final client = MockClient((request) async {
          expect(request.url.path, '/api/external/pages/search/tracks');
          expect(request.url.queryParameters['q'], query.trim());
          return jsonResponse(searchPage(entry(title: title, artist: artist)));
        });
        addTearDown(client.close);
        final result = await MusicCatalog(client)
            .search(query, source: CatalogSource.zaycev);
        expect(result.tracks.single.track.title, title);
        expect(result.tracks.single.track.artist, artist);
        expect(result.tracks.single.track.downloadUrl, page);
      });
    }
  });

  group('search excludes non-playable results', () {
    for (final (field, value) in const <(String, Object?)>[
      ('playbackEnabled', false),
      ('playbackEnabled', null),
      ('duration', '00:00'),
      ('duration', 'invalid'),
      ('duration', 132),
      ('artistName', null),
      ('track', 'Несвязанный результат'),
    ]) {
      test('$field = $value', () async {
        final client = MockClient(
            (_) async => jsonResponse(searchPage({...entry(), field: value})));
        addTearDown(client.close);
        final result = await MusicCatalog(client)
            .search('Юра, Юра', source: CatalogSource.zaycev);
        expect(result.tracks, isEmpty);
      });
    }
    test('the generic popular fallback is excluded', () async {
      final client = MockClient((_) async =>
          jsonResponse({...searchPage(entry()), 'popularInSearch': true}));
      addTearDown(client.close);
      final result = await MusicCatalog(client)
          .search('Юра, Юра', source: CatalogSource.zaycev);
      expect(result.tracks, isEmpty);
      expect(result.nextOffset, isNull);
    });
    test('stream-only tracks have no download action', () async {
      final client = MockClient((_) async =>
          jsonResponse(searchPage({...entry(), 'downloadEnabled': false})));
      addTearDown(client.close);
      final result = await MusicCatalog(client)
          .search('Юра, Юра', source: CatalogSource.zaycev);
      expect(result.tracks.single.track.path, page);
      expect(result.tracks.single.track.downloadUrl, isNull);
    });
    test('pagination uses a stable id, skips duplicates and stops on last page',
        () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['page'], '2');
        return jsonResponse(
            searchPage(entry(), pages: 2, ids: const [24974150, id, -1]));
      });
      addTearDown(client.close);
      final result = await MusicCatalog(client)
          .search('CUPSIZE', source: CatalogSource.zaycev, offset: 1);
      expect(result.tracks.single.track.identity, page);
      expect(result.nextOffset, isNull);
    });
    test('search surfaces retryable errors if API and fallback are down',
        () async {
      final client = MockClient((_) async => http.Response('', 503));
      addTearDown(client.close);
      await expectLater(
          MusicCatalog(client).search('CUPSIZE', source: CatalogSource.zaycev),
          throwsA(isA<http.ClientException>()));
    });
  });

  group('download resolver rejects incompatible inputs', () {
    for (final url in const [
      'http://zaycev.net/pages/249741/24974150.shtml',
      'https://zaycev.net.fake.test/pages/249741/24974150.shtml',
      'https://fake.test/pages/249741/24974150.shtml',
      'https://user@zaycev.net/pages/249741/24974150.shtml',
      'https://zaycev.net/artist/101594652.shtml',
      'https://zaycev.net/pages/249741/invalid.shtml',
      'file:///music/test.mp3',
      'https://www.youtube.com/watch?v=jcrA-YE65fE',
    ]) {
      test(url, () async {
        final resolver = ZaycevStreams(MockClient((_) async {
          fail('Invalid paths must never reach the resolver endpoint');
        }));
        addTearDown(resolver.dispose);
        expect(await resolver.resolveDownload(url), isNull);
      });
    }
  });

  group('download resolver validates guest permissions and responses', () {
    for (final (label, reply, count) in <(String, http.Response, int)>[
      ('missing permission', credentials(key: null), 1),
      ('invalid token', credentials(key: '../play/key'), 1),
      ('wrong recording id', credentials(trackId: 1), 1),
      ('metadata denied', http.Response('', 403), 1),
      ('malformed metadata', http.Response('<html>', 200), 1),
      ('link denied', http.Response('', 403), 2),
      ('blank link', http.Response('', 200), 2),
      (
        'insecure link',
        http.Response('http://zaycev.cdn.zerocdn.com/test.mp3', 200),
        2
      ),
      ('unexpected CDN', http.Response('https://example.com/test.mp3', 200), 2),
      (
        'link with credentials',
        http.Response('https://user@zaycev.cdn.zerocdn.com/test.mp3', 200),
        2
      ),
    ]) {
      test(label, () async {
        var calls = 0;
        final resolver = ZaycevStreams(MockClient((_) async {
          calls++;
          return count == 1 || calls == 2 ? reply : credentials();
        }));
        addTearDown(resolver.dispose);
        expect(await resolver.resolveDownload(page), isNull);
        expect(calls, count);
      });
    }
    test('valid guest download succeeds with the plain-text provider URL',
        () async {
      final resolver = ZaycevStreams(MockClient((request) async {
        expect(request.headers['authorization'], isNull);
        if (request.method == 'POST') {
          expect(jsonDecode(request.body), {
            'trackIds': [id],
            'subscription': false
          });
          return credentials(trackId: id);
        }
        expect(request.url.path, '/api/external/track/download/download-key');
        return http.Response(' $media\n', 200);
      }));
      addTearDown(resolver.dispose);
      expect(await resolver.resolveDownload(page), media);
    });
  });

  group('authorized downloads remain available offline', () {
    for (final (label, type, status, bytes, saved) in const [
      ('MP3', 'audio/mpeg', 200, mp3Header, true),
      ('binary audio', 'application/octet-stream', 200, mp3Header, true),
      ('HTML error', 'text/html', 200, mp3Header, false),
      ('empty file', 'audio/mpeg', 200, <int>[], false),
      ('unexpected partial response', 'audio/mpeg', 206, mp3Header, false),
      ('expired URL', 'audio/mpeg', 403, mp3Header, false),
    ]) {
      test(label, () async {
        final directory = await Directory.systemTemp.createTemp('otune-zaycev');
        addTearDown(() => directory.delete(recursive: true));
        final client = MockClient((request) async {
          if (request.method == 'POST') return credentials();
          if (request.url.host == 'zaycev.net') {
            return http.Response(media, 200);
          }
          expect(request.url.toString(), media);
          return http.Response.bytes(bytes, status,
              headers: {'content-type': type});
        });
        final downloads = OfflineTracks(
            client: client,
            directory: () async => directory,
            artwork: (_) async => null);
        try {
          if (!saved) {
            await expectLater(
                downloads.download(recording), throwsFormatException);
            expect(downloads.tracks, isEmpty);
            expect(downloads.isLoading(page), isFalse);
          } else {
            await downloads.download(recording);
            expect(downloads.tracks.single.identity, page);
            expect(
                await File(downloads.tracks.single.path).readAsBytes(), bytes);
          }
        } finally {
          downloads.dispose();
        }
        final reopened = OfflineTracks(
            client: MockClient(
                (_) async => fail('Offline restore requested the network')),
            directory: () async => directory,
            artwork: (_) async => null);
        addTearDown(reopened.dispose);
        await reopened.ready;
        expect(reopened.tracks.length, saved ? 1 : 0);
        if (saved) {
          final local = reopened.localOrOriginal(recording);
          expect(File(local.path).existsSync(), isTrue);
          expect(local.downloadUrl, page);
          expect(local.path, endsWith('.mp3'));
        }
      });
    }
  });
}

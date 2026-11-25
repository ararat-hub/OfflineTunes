import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:offlinetunes/data/db/app_database.dart';
import 'package:offlinetunes/data/models/equalizer.dart';
import 'package:offlinetunes/data/models/music_query.dart';
import 'package:offlinetunes/data/models/playback_track.dart';
import 'package:offlinetunes/data/services/audius_streams.dart';
import 'package:offlinetunes/data/services/catalog_playback.dart';
import 'package:offlinetunes/data/services/listening_history.dart';
import 'package:offlinetunes/data/services/music_catalog.dart';
import 'package:offlinetunes/data/services/update_service.dart';
import 'package:offlinetunes/theme/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('previous catalogue history is resolved as audio after the update', () {
    const youtube = 'https://www.youtube.com/watch?v=jcrA-YE65fE';
    expect(
        CatalogPlayback.needsAudioLookup(const PlaybackTrack(
            path: youtube,
            title: 'Юра, Юра',
            artist: 'CUPSIZE',
            youtube: true)),
        isFalse);
    expect(
        CatalogPlayback.needsAudioLookup(const PlaybackTrack(
            path: youtube,
            title: 'Юра, Юра',
            artist: 'CUPSIZE',
            youtube: true,
            originalPath: 'https://www.deezer.com/track/42')),
        isTrue);
    expect(
        CatalogPlayback.needsAudioLookup(const PlaybackTrack(
            path: 'https://www.deezer.com/track/42',
            title: 'Юра, Юра',
            artist: 'CUPSIZE',
            externalProvider: 'Deezer')),
        isTrue);
  });

  test('guest Russian search returns the full label recording with stable id',
      () async {
    final playlist = {
      'trackIds': {
        'history': [1],
        'search_cupsize': [24974150, 2, 3]
      },
      'info': {
        '24974150': {
          'track': 'Юра, Юра',
          'artistName': 'CUPSIZE',
          'duration': '02:12',
          'playbackEnabled': true,
          'imageJpg': 'https://cdnimg.zaycev.net/cover.jpg',
        },
        '2': {
          'track': 'Юра, Юра',
          'artistName': 'CUPSIZE',
          'duration': '00:30',
          'playbackEnabled': false,
        },
        '3': {
          'track': 'Концерт',
          'artistName': 'Другой артист',
          'duration': '04:00',
          'playbackEnabled': true,
        },
      },
      'status': {
        'search_cupsize': {'pagesCount': 3}
      }
    };
    final catalog = MusicCatalog(MockClient((request) async {
      expect(request.url.host, 'zaycev.net');
      expect(request.url.queryParameters['tracks-page'], '2');
      final state = jsonEncode({
        'props': {
          'initialReduxState': {'playlist': playlist}
        }
      });
      return http.Response.bytes(
          utf8.encode(
              '<script id="__NEXT_DATA__" type="application/json">$state</script>'),
          200);
    }));
    final page = await catalog.search('CUPSIZE Юра, Юра',
        source: CatalogSource.zaycev, offset: 1);
    final entry = page.tracks.single;
    expect(entry.track.title, 'Юра, Юра');
    expect(entry.track.path, 'https://zaycev.net/pages/249741/24974150.shtml');
    expect(CatalogPlayback.canPlayInApp(entry.track), isTrue);
    expect(entry.duration, const Duration(seconds: 132));
    expect(page.nextOffset, 2);
  });

  test('search and charts accept audio and exclude watch pages and previews',
      () {
    bool playable(String path, {bool youtube = false}) =>
        CatalogPlayback.canPlayInApp(
            PlaybackTrack(path: path, title: '', artist: '', youtube: youtube));

    expect(playable('https://api.audius.co/v1/tracks/Track42/stream'), isTrue);
    expect(playable('https://upload.wikimedia.org/test.ogg'), isTrue);
    expect(playable('file:///music/song.flac'), isTrue);
    expect(playable('https://www.deezer.com/track/42'), isFalse);
    expect(playable('https://music.apple.com/ru/album/111?i=222'), isFalse);
    expect(playable('https://www.youtube.com/watch?v=jcrA-YE65fE'), isFalse);
    expect(playable('https://example.com/demo.mp3', youtube: true), isFalse);
    expect(playable('https://audio-ssl.itunes.apple.com/audiopreview/demo.m4a'),
        isFalse);
    expect(playable('https://cdns-preview-1.dzcdn.net/demo.mp3'), isFalse);
  });

  test(
      'Audius playback recovers from an unreachable redirect using a full audio mirror',
      () async {
    final requests = <Uri>[];
    final streams = AudiusStreams(MockClient((request) async {
      final uri = request.url;
      requests.add(uri);
      if (uri.host == 'api.audius.co' && uri.path.endsWith('/stream')) {
        return http.Response('', 302,
            headers: {'location': 'https://first.example/audio'});
      }
      if (uri.host == 'api.audius.co') {
        return http.Response(
            jsonEncode({
              'data': {
                'id': 'Pala',
                'is_streamable': true,
                'is_stream_gated': false,
                'stream': {
                  'url': 'https://first.example/audio?token=signed',
                  'mirrors': ['https://mirror.example'],
                }
              }
            }),
            200);
      }
      expect(request.headers['Range'], 'bytes=0-1');
      if (uri.host == 'mirror.example') {
        expect(uri.queryParameters['token'], 'signed');
        return http.Response('ff', 206,
            headers: {'content-type': 'audio/mpeg'});
      }
      return http.Response('Invalid route', 503);
    }));
    expect(await streams.resolve('https://api.audius.co/v1/tracks/Pala/stream'),
        'https://mirror.example/audio?token=signed');
    expect(requests.map((uri) => uri.host),
        containsAll(['api.audius.co', 'first.example', 'mirror.example']));
    expect(
        await streams.resolve('https://api.audius.co/v1/tracks/Pala/preview'),
        isNull);
    streams.dispose();
  });

  test('Russian music search handles artist aliases and ё in track names', () {
    expect(
        MusicQuery('Виктор Цой Кукушка')
            .matches('Viktor Tsoi - Kukushka', 'Jacku'),
        isTrue);
    expect(MusicQuery('Zemfira').matches('Земфира — Самолёты', 'SIDXKICK'),
        isTrue);
    expect(MusicQuery('самолеты').matches('Самолёты', 'Земфира'), isTrue);
    expect(MusicQuery('Оксимирон').matches('Field of Snow', 'ThePurpleAnon'),
        isFalse);
  });

  test('search returns full recordings from Commons and pagination', () async {
    Map<String, Object> file(String name, double duration) => {
          'title': 'File:$name.ogg',
          'imageinfo': [
            {
              'url':
                  'https://upload.wikimedia.org/wikipedia/commons/a/b/$name.ogg?utm_source=commons',
              'descriptionurl':
                  'https://commons.wikimedia.org/wiki/File:$name.ogg',
              'duration': duration,
              'mime': 'application/ogg',
              'extmetadata': {
                'Artist': {'value': '<b>Beethoven</b>'},
                'LicenseShortName': {'value': 'Public domain'},
              },
            }
          ],
        };
    final catalog = MusicCatalog(MockClient((request) async {
      expect(request.url.host, 'commons.wikimedia.org');
      expect(
          request.url.queryParameters['gsrsearch'], 'Beethoven filetype:audio');
      return http.Response(
          jsonEncode({
            'continue': {'gsroffset': 30},
            'query': {
              'pages': [file('Symphony', 436.02), file('Excerpt', 30)]
            },
          }),
          200);
    }));
    final page = await catalog.search('Beethoven');
    expect(page.nextOffset, 30);
    final entry = page.tracks.single;
    expect(entry.duration, const Duration(milliseconds: 436020));
    expect(entry.track.path,
        'https://upload.wikimedia.org/wikipedia/commons/a/b/Symphony.ogg');
    expect(entry.track.artist, 'Beethoven');
    expect(entry.track.license, 'Public domain');
  });

  test('history de-duplicates tracks, persists and recommends related music',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final history = ListeningHistory(prefs);
    const first = PlaybackTrack(
        path: 'a', title: 'A', artist: 'Miles Davis', genre: 'Jazz');
    const second = PlaybackTrack(
        path: 'b', title: 'B', artist: 'Bach', genre: 'Classical');
    history.record(first);
    history.record(second);
    history.record(first);
    await history.saved;
    final restored = ListeningHistory(prefs);
    expect(restored.recent.map((track) => track.path), ['a', 'b']);
    expect(restored.mostPlayed.single.track.path, 'a');
    expect(restored.mostPlayed.single.count, 2);

    Track candidate(String id, String artist, String genre) => Track(
          id: id,
          title: id,
          artist: artist,
          genre: genre,
          duration: 0,
          localPath: id,
          isFavorite: 0,
          isDownloaded: 0,
          addedAt: DateTime(2025),
        );
    expect(
        restored.recommend([
          candidate('a', 'Miles Davis', 'Jazz'),
          candidate('jazz', 'John Coltrane', 'Jazz'),
          candidate('miles', 'Miles Davis', 'Jazz'),
          candidate('unrelated', 'Other', 'Pop'),
        ]).map((track) => track.path),
        ['miles', 'jazz']);
    restored.dispose();
    history.dispose();
  });

  test('Audius uses the full public stream and omits access-gated tracks', () {
    const item = {
      'id': 'ng9rl',
      'title': 'Lofi type beat',
      'duration': 334,
      'genre': 'Hip-Hop/Rap',
      'permalink': '/bsdu/lofi-type-beat-14815',
      'is_streamable': true,
      'is_stream_gated': false,
      'is_unlisted': false,
      'user': {'name': 'bsdu'},
    };
    final page = MusicCatalog.parseAudiusPage({
      'data': [
        item,
        {...item, 'is_stream_gated': true},
        {...item, 'is_unlisted': true},
        {...item, 'is_streamable': false}
      ],
    }, offset: 0, limit: 30);
    final track = page.tracks.single;
    expect(track.track.path,
        'https://api.audius.co/v1/tracks/ng9rl/stream?app_name=OfflineTunes');
    expect(
        track.track.sourcePage, 'https://audius.co/bsdu/lofi-type-beat-14815');
    expect(track.duration, const Duration(seconds: 334));
  });

  test('popular tracks are ordered by Audius play count', () async {
    Map<String, Object> track(String id, int count) => {
          'id': id,
          'title': id,
          'duration': 150,
          'permalink': '/artist/$id',
          'is_streamable': true,
          'is_stream_gated': false,
          'is_unlisted': false,
          'play_count': count,
        };
    final catalog = MusicCatalog(MockClient((request) async {
      expect(request.url.path, '/v1/tracks/trending');
      expect(request.url.queryParameters['time'], 'allTime');
      return http.Response(
          jsonEncode({
            'data': [track('A', 400), track('B', 7000), track('C', 1200)],
          }),
          200);
    }));
    final entries = await catalog.popular();
    expect(entries.map((item) => item.track.title), ['B', 'C', 'A']);
    expect(entries.map((item) => item.plays), [7000, 1200, 400]);
  });

  test('popular retries other Audius nodes and keeps the last chart offline',
      () async {
    final attempts = <String>[];
    var offline = false;
    final catalog = MusicCatalog(MockClient((request) async {
      attempts.add(request.url.host);
      if (offline || attempts.length == 1) return http.Response('', 503);
      return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'Track42',
                'title': 'Full recording',
                'duration': 190,
                'permalink': '/artist/track-42',
                'play_count': 500,
                'artwork': {
                  '150x150': 'https://one.example/content/cover/150x150.jpg',
                  'mirrors': ['https://two.example', 'http://bad.example'],
                },
              },
            ],
          }),
          200);
    }));
    final live = await catalog.popularWithCache();
    expect(attempts, [
      'api.audius.co',
      'discoveryprovider.audius.co',
      'discoveryprovider2.audius.co'
    ]);
    expect(live.cached, isFalse);
    expect(live.tracks.single.track.artworkAlternatives,
        ['https://two.example/content/cover/150x150.jpg']);
    offline = true;
    final cached = await catalog.popularWithCache();
    expect(cached.cached, isTrue);
    expect(
        cached.tracks.single.track.toJson(), live.tracks.single.track.toJson());
  });

  test('Russian catalog search prioritizes the artist and keeps previews out',
      () async {
    Map<String, Object> entry(int id, String title, String artist, int rank) =>
        {
          'id': id,
          'title': title,
          'duration': 207,
          'artist': {'name': artist},
          'rank': rank,
          'preview': 'https://example.com/preview.mp3',
          'album': {
            'cover_medium': 'https://cdn-images.dzcdn.net/images/cover/c.jpg'
          },
        };
    final catalog = MusicCatalog(MockClient((request) async {
      if (request.url.host == 'itunes.apple.com') return http.Response('', 503);
      expect(request.url.host, 'api.deezer.com');
      expect(request.url.queryParameters['order'], 'RANKING');
      return http.Response.bytes(
          utf8.encode(jsonEncode({
            'data': [
              entry(12, 'Первый сингл', 'Пётр Тестов', 8000),
              entry(4, 'Второй сингл', 'Пётр Тестов', 9000),
              entry(3, 'Пётр Тестов', 'Другой артист', 9999),
              entry(7, 'Совсем другая песня', 'Другой артист', 9900),
            ]
          })),
          200);
    }));
    final page =
        await catalog.search('Пётр Тестов', source: CatalogSource.recordings);
    expect(page.tracks.map((entry) => entry.track.title),
        ['Второй сингл', 'Первый сингл', 'Пётр Тестов']);
    final first = page.tracks.first.track;
    expect(first.externalProvider, 'Deezer');
    expect(first.path, 'https://www.deezer.com/track/4');
    expect(first.downloadUrl, isNull);
    expect(first.artworkAlternatives.single,
        'https://cdn-images.deezer.com/images/cover/c.jpg');
  });

  test('bundled Russian catalog returns exact records during a DNS outage',
      () async {
    final catalog =
        MusicCatalog(MockClient((_) async => http.Response('', 503)));
    final search = await catalog.searchRecordings('Виктор Цой');
    expect(search.ranked, isFalse);
    final track = search.page.tracks
        .firstWhere((item) => item.track.title == 'Звезда по имени Солнце')
        .track;
    expect(track.artist, 'Кино');
    expect(track.artwork, startsWith('https://is1-ssl.mzstatic.com/'));
    expect(track.path, startsWith('https://music.apple.com/ru/'));
  });

  test(
      'Russian catalog matches the same Kino recording from an independent source',
      () async {
    final requests = <String>[];
    final catalog = MusicCatalog(MockClient((request) async {
      requests.add(request.url.host);
      if (request.url.host == 'itunes.apple.com') {
        return http.Response.bytes(
            utf8.encode(jsonEncode({
              'results': [
                {
                  'trackName': 'Группа крови',
                  'artistName': 'Кино',
                  'trackTimeMillis': 278500,
                  'artworkUrl100': 'https://is1-ssl.mzstatic.com/album.jpg',
                  'trackViewUrl': 'https://music.apple.com/ru/album/1?i=2'
                },
              ]
            })),
            200);
      }
      return http.Response.bytes(
          utf8.encode(jsonEncode({
            'data': [
              {
                'id': 22,
                'title': 'Группа крови',
                'artist': {'name': 'Виктор Цой'},
                'duration': 275,
                'rank': 5000
              },
            ]
          })),
          200);
    }));
    final search = await catalog.searchRecordings('Виктор Цой');
    expect(requests, containsAll(['api.deezer.com', 'itunes.apple.com']));
    expect(search.ranked, isTrue);
    expect(search.page.tracks.single.rank, 5000);
    expect(search.page.tracks.single.track.externalProvider, 'Apple Music');
    expect(search.page.tracks.single.track.artwork,
        'https://is1-ssl.mzstatic.com/album.jpg');
  });

  test('Russian-language chart ranks playable tracks and caches them',
      () async {
    var offline = false;
    Map<String, Object> track(String id, String title, int plays,
            {bool gated = false}) =>
        {
          'id': id,
          'title': title,
          'duration': 160,
          'permalink': '/artist/$id',
          'play_count': plays,
          'is_streamable': true,
          'is_stream_gated': gated,
        };
    final catalog = MusicCatalog(MockClient((request) async {
      expect(request.url.path, '/v1/tracks/search');
      if (offline) return http.Response('', 503);
      final query = request.url.queryParameters['query'];
      return http.Response.bytes(
          utf8.encode(jsonEncode({
            'data': [
              track('A', 'Первый', 100),
              if (query == 'russian rap') track('B', 'Второй', 400),
              track('C', 'English Song', 900),
              track('D', 'Закрытый трек', 800, gated: true),
            ],
          })),
          200);
    }));
    final result = await catalog.popularWithCache(region: ChartRegion.russia);
    expect(result.source, 'Audius');
    expect(
        result.tracks.map((entry) => entry.track.title), ['Второй', 'Первый']);
    expect(result.tracks.map((entry) => entry.plays), [400, 100]);
    expect(
        result.tracks
            .every((entry) => CatalogPlayback.canPlayInApp(entry.track)),
        isTrue);
    offline = true;
    final cached = await catalog.popularWithCache(region: ChartRegion.russia);
    expect(cached.cached, isTrue);
    expect(cached.tracks.map((entry) => entry.track.path),
        result.tracks.map((entry) => entry.track.path));
  });

  test('a first install has a playable global chart if the catalog is offline',
      () async {
    final catalog =
        MusicCatalog(MockClient((_) async => http.Response('', 503)));
    final fallback = await catalog.popularWithCache(genre: 'Rock');
    expect(fallback.cached, isTrue);
    expect(fallback.tracks, isNotEmpty);
    expect(
        fallback.tracks.every((item) =>
            item.track.genre == 'Rock' && item.track.externalProvider == null),
        isTrue);
  });

  test(
      'background gallery remembers independent widget and player media and loops',
      () async {
    final folder =
        await Directory.systemTemp.createTemp('offlinetunes-appearance');
    addTearDown(() async {
      await for (final file in folder.list(followLinks: false)) {
        if (file is File) await file.delete();
      }
      await folder.delete();
    });
    final main = File('${folder.path}${Platform.pathSeparator}main.png');
    final widget = File('${folder.path}${Platform.pathSeparator}widget.mp4');
    await main.writeAsBytes([1, 2]);
    await widget.writeAsBytes([3, 4, 5]);
    final theme = ThemeProvider();
    await theme.ready;
    await theme.importBackground(main.path, compact: false, directory: folder);
    await theme.importBackground(widget.path, compact: true, directory: folder);
    await theme.setVideoLoop((from: 2, to: 12), compact: true);
    await widget.delete();
    final restored = ThemeProvider();
    await restored.ready;
    expect(restored.savedBackgrounds.map((item) => item.name),
        ['widget.mp4', 'main.png']);
    expect(restored.backgroundType(compact: false), BackgroundType.image);
    expect(restored.backgroundType(compact: true), BackgroundType.video);
    expect(restored.videoLoop(compact: true), (from: 2, to: 12));
    expect(await File(restored.widgetMediaPath!).readAsBytes(), [3, 4, 5]);
    restored.noteBackgroundDuration(
        restored.widgetMediaPath!, const Duration(seconds: 5));
    expect(restored.videoLoop(compact: true), (from: 2, to: null));
    await restored.setWidgetBackground(null);
    expect(restored.mediaPath(compact: true), restored.backgroundImagePath);
    expect(restored.savedBackgrounds.length, 2);
    restored.dispose();
    theme.dispose();
  });

  test('equalizer uses supported filters and lowers gain for boosted bands',
      () {
    expect(equalizerFilter(flatEqualizer), '');
    const tone = (bass: 5, mid: -2, treble: 3);
    expect(equalizerFilter(tone),
        'lavfi=[equalizer=f=110:t=o:w=2:g=5,equalizer=f=1000:t=o:w=2:g=-2,equalizer=f=6500:t=o:w=2:g=3]');
    expect(equalizerHeadroom(tone), closeTo(.5623, .001));
  });

  test('updates compare numeric versions and only open the official release',
      () async {
    const payload = {
      'tag_name': 'v1.10.0',
      'draft': false,
      'prerelease': false,
      'html_url': 'https://example.com/not-the-app',
      'assets': [
        {
          'name': 'oTune-Setup-1.10.0.exe',
          'state': 'uploaded',
          'browser_download_url':
              'https://github.com/ararat-hub/OfflineTunes/releases/download/v1.10.0/oTune-Setup-1.10.0.exe',
        },
      ],
    };
    final prefs = await SharedPreferences.getInstance();
    var calls = 0;
    final service = UpdateService(
      prefs,
      installedVersion: '1.4.0+4',
      assetExtension: '.exe',
      client: MockClient((request) async {
        calls++;
        expect(request.url.host, 'api.github.com');
        return http.Response(jsonEncode(payload), 200);
      }),
    );
    final update = await service.check();
    expect(update?.version, '1.10.0');
    expect(update?.page.toString(),
        'https://github.com/ararat-hub/OfflineTunes/releases/tag/v1.10.0');
    expect(update?.download?.path, endsWith('/oTune-Setup-1.10.0.exe'));
    expect(UpdateService.parseRelease(payload, '1.0.0', assetExtension: '.apk'),
        isNull);
    expect(await service.check(), isNull);
    expect(calls, 1);
    expect(UpdateService.parseRelease(payload, '1.10.1'), isNull);
    expect(
        UpdateService.parseRelease({...payload, 'prerelease': true}, '1.0.0'),
        isNull);
    service.dispose();
  });
}

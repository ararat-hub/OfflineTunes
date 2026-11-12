import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:offlinetunes/data/db/app_database.dart';
import 'package:offlinetunes/data/models/equalizer.dart';
import 'package:offlinetunes/data/models/playback_track.dart';
import 'package:offlinetunes/data/services/listening_history.dart';
import 'package:offlinetunes/data/services/music_catalog.dart';
import 'package:offlinetunes/data/services/update_service.dart';
import 'package:offlinetunes/theme/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
    expect(entry.duration.inSeconds, 436);
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
    expect(track.duration.inSeconds, 334);
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
    };
    final prefs = await SharedPreferences.getInstance();
    var calls = 0;
    final service = UpdateService(
      prefs,
      installedVersion: '1.4.0+4',
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
    expect(await service.check(), isNull);
    expect(calls, 1);
    expect(UpdateService.parseRelease(payload, '1.10.1'), isNull);
    expect(
        UpdateService.parseRelease({...payload, 'prerelease': true}, '1.0.0'),
        isNull);
    service.dispose();
  });
}

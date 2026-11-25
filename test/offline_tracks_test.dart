import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:offlinetunes/data/models/playback_track.dart';
import 'package:offlinetunes/data/services/app_preferences.dart';
import 'package:offlinetunes/data/services/offline_tracks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as zones;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const track = PlaybackTrack(
    path: 'https://upload.wikimedia.org/example.ogg',
    downloadUrl: 'https://upload.wikimedia.org/example.ogg',
    title: 'Example',
    artist: 'Composer',
    license: 'CC BY 4.0',
  );

  test('a direct HTTPS audio link is saved with its query intact', () async {
    final root = await Directory.systemTemp.createTemp('otune-link');
    addTearDown(() => root.delete(recursive: true));
    const path = 'https://example.com/music/test.flac?token=example';
    final service = OfflineTracks(
        directory: () async => root,
        client: MockClient((request) async {
          expect(request.url.toString(), path);
          return http.Response.bytes([102, 76, 97, 67, 10], 200,
              headers: {'content-type': 'audio/flac'});
        }));
    addTearDown(service.dispose);
    await service.download(const PlaybackTrack(
        path: path, downloadUrl: path, title: 'Test', artist: 'Artist'));
    expect(service.tracks.single.path, endsWith('.flac'));
    expect(service.tracks.single.identity, path);
  });

  test('a download plays from disk and survives restart with attribution',
      () async {
    final root = await Directory.systemTemp.createTemp('otune-download');
    addTearDown(() => root.delete(recursive: true));
    Future<Directory> directory() async => root;
    var requests = 0;
    final service = OfflineTracks(
        directory: directory,
        client: MockClient((_) async {
          requests++;
          return http.Response.bytes([79, 103, 103, 83, 10], 200,
              headers: {'content-type': 'audio/ogg', 'content-length': '5'});
        }));
    await Future.wait([service.download(track), service.download(track)]);
    final local = service.localOrOriginal(track);
    expect(local.path, isNot(track.path));
    expect(local.identity, track.path);
    expect(await File(local.path).readAsBytes(), [79, 103, 103, 83, 10]);
    expect(requests, 1);
    service.dispose();

    final restored = OfflineTracks(directory: directory);
    addTearDown(restored.dispose);
    await restored.ready;
    expect(restored.tracks.single.license, 'CC BY 4.0');
    expect(restored.localOrOriginal(track).path, local.path);
    await restored.remove(restored.tracks.single);
    expect(await File(local.path).exists(), isFalse);
    expect(restored.tracks, isEmpty);
  });

  test('a partial download is not added and can be retried', () async {
    final root = await Directory.systemTemp.createTemp('otune-partial');
    addTearDown(() => root.delete(recursive: true));
    var complete = false;
    final service = OfflineTracks(
        directory: () async => root,
        client: MockClient.streaming((_, __) async {
          return http.StreamedResponse(Stream.value([79, 103, 103]), 200,
              headers: {'content-type': 'audio/ogg'},
              contentLength: complete ? 3 : 8);
        }));
    addTearDown(service.dispose);
    await expectLater(service.download(track), throwsFormatException);
    expect(service.tracks, isEmpty);
    expect(await Directory('${root.path}/downloads').list().isEmpty, isTrue);
    complete = true;
    await service.download(track);
    expect(service.tracks, hasLength(1));
  });

  test('download artwork survives cache deletion and offline restart',
      () async {
    final root = await Directory.systemTemp.createTemp('otune-durable-cover');
    addTearDown(() => root.delete(recursive: true));
    final cache = File('${root.path}/temporary-cover.png');
    await cache.writeAsBytes([137, 80, 78, 71]);
    final downloads = OfflineTracks(
        directory: () async => root,
        artwork: (_) async => cache,
        client: MockClient((_) async => http.Response.bytes(
            [79, 103, 103, 83], 200,
            headers: {'content-type': 'audio/ogg'})));
    await downloads.download(track);
    final cover = File(downloads.tracks.single.artwork!);
    expect(cover.path, isNot(cache.path));
    await cache.delete();
    downloads.dispose();
    final offline = OfflineTracks(
        directory: () async => root,
        artwork: (_) async =>
            fail('Saved artwork must load without a request.'));
    addTearDown(offline.dispose);
    await offline.ready;
    expect(offline.tracks.single.artwork, cover.path);
    expect(await cover.readAsBytes(), [137, 80, 78, 71]);
    await offline.remove(offline.tracks.single);
    expect(await cover.exists(), isFalse);
  });

  test('existing downloads regain an independently saved cover', () async {
    final root = await Directory.systemTemp.createTemp('otune-legacy-cover');
    addTearDown(() => root.delete(recursive: true));
    final directory = await Directory('${root.path}/downloads').create();
    await File('${directory.path}/old.ogg').writeAsBytes([79, 103, 103, 83]);
    await File('${directory.path}/old.json')
        .writeAsString(jsonEncode({...track.toJson(), 'file': 'old.ogg'}));
    final cache = File('${root.path}/cover.png');
    await cache.writeAsBytes([137, 80, 78, 71]);
    final changed = Completer<void>();
    final downloads =
        OfflineTracks(directory: () async => root, artwork: (_) async => cache);
    addTearDown(downloads.dispose);
    downloads.addListener(() {
      if (!changed.isCompleted &&
          downloads.tracks.firstOrNull?.artwork != null) {
        changed.complete();
      }
    });
    await changed.future.timeout(const Duration(seconds: 3));
    expect(p.normalize(downloads.tracks.single.artwork!),
        p.normalize(p.join(directory.path, 'old.art.png')));
  });

  test('the selected zone changes the displayed day and respects summer time',
      () async {
    zones.initializeTimeZones();
    SharedPreferences.setMockInitialValues({});
    final preferences = AppPreferences(await SharedPreferences.getInstance());
    addTearDown(preferences.dispose);
    await preferences.setTimeZone('America/New_York');
    final time = preferences.clockTime(DateTime.utc(2026, 7, 4, 2));
    expect([time.day, time.hour, time.weekday], [3, 22, DateTime.friday]);
    expect(time.timeZoneOffset, const Duration(hours: -4));
    await preferences.setTimeZone('Asia/Tokyo');
    expect(preferences.clockTime(time).hour, 11);
    expect(preferences.timeZone, 'Asia/Tokyo');
  });
}

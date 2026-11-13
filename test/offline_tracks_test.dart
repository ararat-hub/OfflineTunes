import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

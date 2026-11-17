import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:offlinetunes/data/db/app_database.dart' show Track;
import 'package:offlinetunes/data/models/playback_track.dart';
import 'package:offlinetunes/data/services/audio_player_service.dart';
import 'package:offlinetunes/data/services/catalog_playback.dart';
import 'package:offlinetunes/widgets/mini_player.dart';

class FakePlayer extends PlatformPlayer {
  FakePlayer() : super(configuration: const PlayerConfiguration());
  Playlist? opened;
  Duration? sought;
  double? volume;
  int playCount = 0;
  int nextCount = 0;
  Completer<void>? openGate;
  final openedSignal = Completer<void>();
  bool delayMetadata = false;

  void emitPosition(Duration value) => positionController.add(value);

  void emitMetadata() {
    state = state.copyWith(duration: const Duration(seconds: 60));
    durationController.add(state.duration);
  }

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    await openGate?.future;
    opened = playable as Playlist;
    playlistController.add(opened!);
    if (!delayMetadata) emitMetadata();
    positionController.add(Duration.zero);
    if (!openedSignal.isCompleted) openedSignal.complete();
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Future<void> play() async {
    playCount++;
    playingController.add(true);
  }

  @override
  Future<void> pause() async {
    playingController.add(false);
  }

  @override
  Future<void> stop() async {
    playingController.add(false);
  }

  @override
  Future<void> seek(Duration value) async {
    sought = value;
    positionController.add(value);
  }

  @override
  Future<void> setVolume(double value) async {
    volume = value;
  }

  @override
  Future<void> setShuffle(bool value) async {}
  @override
  Future<void> setPlaylistMode(PlaylistMode value) async {}
  @override
  Future<void> next() async {
    nextCount++;
    final playlist = opened!;
    opened = Playlist(playlist.medias,
        index: (playlist.index + 1) % playlist.medias.length);
    playlistController.add(opened!);
    positionController.add(Duration.zero);
  }

  @override
  Future<void> previous() async {}
}

const first = PlaybackTrack(
    path: 'https://example.com/a.mp3', title: 'Первый', artist: 'Автор');
const second = PlaybackTrack(
    path: 'https://example.com/b.mp3', title: 'Второй', artist: 'Автор');
const cupsize = PlaybackTrack(
    path: 'https://www.deezer.com/track/42',
    title: 'Юра, Юра',
    artist: 'CUPSIZE',
    externalProvider: 'Deezer');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakePlayer engine;
  late AudioPlayerService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    engine = FakePlayer();
    service = AudioPlayerService(player: Player(platformPlayer: engine));
  });
  tearDown(() async {
    service.dispose();
    await Future<void>.delayed(Duration.zero);
  });

  test('catalogue playback uses the matching device file without a request',
      () async {
    final file = File('${Directory.systemTemp.path}/otune-catalog-local.mp3');
    await file.create();
    addTearDown(file.delete);
    final catalog = CatalogPlayback(service, () async {
      return [
        PlaybackTrack(
            path: file.path, title: cupsize.title, artist: 'Cover band'),
        PlaybackTrack(
            path: file.path,
            title: 'CUPSIZE - Юра, Юра.mp3',
            artist: 'Неизвестный исполнитель'),
      ];
    }, client: MockClient((request) async {
      fail('An available local recording should play without networking.');
    }));
    addTearDown(catalog.dispose);

    expect(await catalog.play(cupsize), CatalogPlaybackResult.started);
    expect(service.currentPath, file.path);
    expect(service.currentTitle, 'CUPSIZE - Юра, Юра.mp3');
    expect(service.isPlaying, isTrue);
  });

  test('missing catalogue audio leaves the current playback active', () async {
    final catalog = CatalogPlayback(service, () async => [],
        client: MockClient((request) async {
      expect(request.url.host, 'api.audius.co');
      return http.Response('{"data":[]}', 200);
    }));
    addTearDown(catalog.dispose);
    await service.playQueue([first]);

    expect(await catalog.play(cupsize), CatalogPlaybackResult.unavailable);
    expect(service.currentPath, first.path);
    expect(service.isPlaying, isTrue);
    expect(catalog.pending, isNull);
  });

  test('database UUID resolves to localPath, legacy paths still work', () {
    final track = Track(
        id: 'a-uuid',
        title: 'Track',
        artist: 'Artist',
        duration: 0,
        isFavorite: 0,
        isDownloaded: 1,
        addedAt: DateTime(2026),
        localPath: r'C:\Music\track.mp3');
    expect(PlaybackTrack.fromTrack(track).path, r'C:\Music\track.mp3');
    final legacy = track.copyWith(id: r'C:\Music\old.mp3');
    final legacyJson = legacy.toJson()..['localPath'] = null;
    expect(PlaybackTrack.fromTrack(Track.fromJson(legacyJson)).path,
        r'C:\Music\old.mp3');
    final invalid = track.toJson()..['localPath'] = null;
    expect(PlaybackTrack.fromTrack(Track.fromJson(invalid)).path, isEmpty);
  });

  test('selected track and queue metadata follow next', () async {
    await service.playQueue([first, second]);
    await Future<void>.delayed(Duration.zero);
    expect(service.currentTitle, 'Первый');
    expect(service.isPlaying, isTrue);
    await service.next();
    await Future<void>.delayed(Duration.zero);
    expect(service.currentTitle, 'Второй');
    expect(service.duration, const Duration(seconds: 60));
    expect(engine.nextCount, 1);
  });

  test('resume reopens saved file before playing and seeks saved position',
      () async {
    final file =
        await File('${Directory.systemTemp.path}/offlinetunes-resume-test.wav')
            .create();
    addTearDown(() => file.delete());
    service.dispose();
    SharedPreferences.setMockInitialValues({
      'player_last_path': file.path,
      'player_last_title': 'Сохранённый',
      'player_last_position_ms': 12000,
      'player_volume': 45.0,
    });
    engine = FakePlayer();
    engine.delayMetadata = true;
    service = AudioPlayerService(player: Player(platformPlayer: engine));
    await service.setVolume(.45);
    engine.emitPosition(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(service.position, const Duration(seconds: 12));
    final starting = service.togglePlayPause();
    await engine.openedSignal.future;
    await Future<void>.delayed(Duration.zero);
    expect(engine.sought, isNull);
    engine.emitMetadata();
    await starting;
    expect(engine.opened, isNotNull);
    expect(engine.sought, const Duration(seconds: 12));
    expect(engine.playCount, 1);
    expect(service.volume, .45);
  });

  test('new track clears saved position from previous track', () async {
    await service.playQueue([first]);
    await Future<void>.delayed(Duration.zero);
    await service.seek(const Duration(seconds: 20));
    await service.playQueue([second]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('player_last_path'), second.path);
    expect(prefs.getInt('player_last_position_ms'), 0);
  });

  test('missing file produces a visible error and permits recovery', () async {
    await service.playFile(r'C:\missing-offlinetunes-test\missing.mp3');
    expect(service.error, contains('Файл не найден'));
    expect(service.isLoading, isFalse);
    expect(engine.opened, isNull);
    await service.playQueue([first]);
    expect(service.error, isNull);
    expect(engine.opened, isNotNull);
  });

  test('rapid selections are serialized, last selection wins', () async {
    engine.openGate = Completer<void>();
    final one = service.playQueue([first]);
    final two = service.playQueue([second]);
    engine.openGate!.complete();
    await Future.wait([one, two]);
    expect(service.currentPath, second.path);
    expect(engine.opened!.medias.single.uri, second.path);
  });

  test('volume and seek clamp invalid values', () async {
    await service.setVolume(2);
    expect(service.volume, 1);
    await service.playQueue([first]);
    await Future<void>.delayed(Duration.zero);
    await service.seek(const Duration(minutes: 10));
    expect(engine.sought, const Duration(seconds: 60));
    await service.seek(const Duration(seconds: -1));
    expect(engine.sought, Duration.zero);
  });

  testWidgets('volume supports pointer, keyboard and accessible values',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(800, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() => service.setVolume(1));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Align(
                alignment: Alignment.bottomCenter,
                child: MiniPlayer(playerService: service)))));
    await tester.pumpAndSettle();
    final volume = find.bySemanticsLabel('Volume');
    await tester.tap(volume);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(service.volume, closeTo(.5, .01));
    final gesture = find
        .descendant(of: volume, matching: find.byType(GestureDetector))
        .first;
    Focus.of(tester.element(gesture)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(service.volume, closeTo(.49, .01));
    expect(tester.getSemantics(volume).getSemanticsData().value, '49%');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  testWidgets('player fits narrow Windows window and disables empty play',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(380, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Align(
                alignment: Alignment.bottomCenter,
                child: MiniPlayer(playerService: service)))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.play_circle_fill));
    expect(button.onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

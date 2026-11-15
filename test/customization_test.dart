import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:offlinetunes/data/db/app_database.dart' show AppDatabase;
import 'package:offlinetunes/app.dart';
import 'package:offlinetunes/data/models/media_link.dart';
import 'package:offlinetunes/data/services/audio_player_service.dart';
import 'package:offlinetunes/data/services/app_preferences.dart';
import 'package:offlinetunes/data/services/desktop_window_service.dart';
import 'package:offlinetunes/data/services/youtube_player_service.dart';
import 'package:offlinetunes/features/home/home_screen.dart';
import 'package:offlinetunes/theme/theme_provider.dart';
import 'audio_player_service_test.dart' show FakePlayer;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ru_RU');
  });

  test('YouTube watch, short, mobile, live and music URLs resolve video ID',
      () {
    for (final url in [
      'https://www.youtube.com/watch?v=M7lc1UVf-VE',
      'https://youtu.be/M7lc1UVf-VE',
      'youtube.com/shorts/M7lc1UVf-VE',
      'https://m.youtube.com/live/M7lc1UVf-VE',
      'https://music.youtube.com/watch?v=M7lc1UVf-VE',
      'https://www.youtube-nocookie.com/embed/M7lc1UVf-VE',
    ]) {
      expect(MediaLink.parse(url).youtubeId, 'M7lc1UVf-VE');
    }
  });
  test('link start positions and direct audio query strings survive parsing',
      () {
    expect(
        MediaLink.parse('https://youtu.be/M7lc1UVf-VE?t=1h2m3s').startSeconds,
        3723);
    expect(
        MediaLink.parse('https://youtube.com/watch?v=M7lc1UVf-VE&start=37')
            .startSeconds,
        37);
    final audio =
        MediaLink.parse('https://example.com/music/track.FLAC?token=abc');
    expect(audio.isYoutube, isFalse);
    expect(audio.uri.queryParameters['token'], 'abc');
  });
  test('invalid links, lookalike domains and non-network schemes are rejected',
      () {
    for (final input in [
      'not a url',
      'file:///C:/Music/test.mp3',
      'javascript:alert(1)',
      'https://youtube.com.evil/watch?v=M7lc1UVf-VE',
      'https://youtube.com/watch?v=bad',
      'https://example.com/page',
      'https://user:password@example.com/a.mp3'
    ]) {
      expect(() => MediaLink.parse(input), throwsFormatException,
          reason: input);
    }
  });
  test('YouTube errors have actionable messages and player remains visible',
      () {
    expect(YoutubePlayerService.errorMessage(150),
        contains('запретил встраивание'));
    expect(YoutubePlayerService.errorMessage(153), contains('идентификатор'));
    expect(YoutubePlayerService.requiresWatchPage(101), isTrue);
    expect(YoutubePlayerService.requiresWatchPage(150), isTrue);
    expect(YoutubePlayerService.requiresWatchPage(153), isFalse);
    expect(YoutubePlayerService.playerHtml, contains('controls:1'));
    expect(YoutubePlayerService.playerHtml,
        contains('strict-origin-when-cross-origin'));
  });

  test('imported background uses an unchanged local copy and persists',
      () async {
    final dir =
        await Directory.systemTemp.createTemp('offlinetunes-video-test');
    addTearDown(() async {
      for (final file in dir.listSync()) {
        if (file is File) await file.delete();
      }
      await dir.delete();
    });
    final original = File('${dir.path}${Platform.pathSeparator}my-video.MP4');
    await original.writeAsBytes([1, 2, 3, 4, 5]);
    final theme = ThemeProvider();
    await theme.ready;
    await theme.importBackgroundVideo(original.path, directory: dir);
    await original.delete();
    expect(theme.bgType, BackgroundType.video);
    expect(theme.importedVideoName, 'my-video.MP4');
    expect(
        await File(theme.backgroundImagePath!).readAsBytes(), [1, 2, 3, 4, 5]);
    await theme.applyPreset(ThemeProvider.presets.first);
    final restored = ThemeProvider();
    await restored.ready;
    expect(restored.bgType, BackgroundType.ambient);
    expect(restored.importedVideoPath, theme.importedVideoPath);
    await restored.setBackgroundImagePath(restored.importedVideoPath);
    expect(restored.bgType, BackgroundType.video);
    theme.dispose();
    restored.dispose();
  });

  test('hotkeys register, reject collisions and keep the prior binding',
      () async {
    const channel = MethodChannel('offlinetunes/hotkeys');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final changes = <Map<dynamic, dynamic>>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      final binding = call.arguments as Map;
      changes.add(binding);
      return binding['key'] != 0x5A;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final prefs = await SharedPreferences.getInstance();
    final settings = AppPreferences(prefs, windows: true);
    expect(settings.hotkeysEnabled, isFalse);
    await settings.initialize();
    await settings.setHotkeysEnabled(true);
    expect(changes.length, HotkeyAction.values.length);
    final old = settings.binding(HotkeyAction.playPause);
    expect(
        await settings.setBinding(
            HotkeyAction.playPause, settings.binding(HotkeyAction.next)),
        isFalse);
    expect(
        await settings
            .setBinding(HotkeyAction.playPause, (modifiers: 6, key: 0x5A)),
        isFalse);
    expect(settings.binding(HotkeyAction.playPause), old);
    final custom = (modifiers: 6, key: 0x50);
    expect(await settings.setBinding(HotkeyAction.playPause, custom), isTrue);
    expect(settings.binding(HotkeyAction.playPause), custom);
    await settings.setHotkeysEnabled(false);
    expect(changes.last['key'], 0);
    await settings.setLanguage('es');
    expect(AppPreferences(prefs, windows: false).locale.languageCode, 'es');
    settings.dispose();
  });
  test('legacy video wallpaper and font migrate without losing settings',
      () async {
    SharedPreferences.setMockInitialValues({
      'bg_type': 1,
      'bg_image_path': r'C:\wallpaper\background.MP4',
      'font_family': 'Fira Code'
    });
    final theme = ThemeProvider();
    await theme.ready;
    expect(theme.bgType, BackgroundType.video);
    expect(theme.backgroundImagePath, endsWith('.MP4'));
    expect(theme.fontFamily, 'Fira Code');
    theme.dispose();
  });
  test('appearance, profile and widget settings persist after rapid edits',
      () async {
    final theme = ThemeProvider();
    await theme.ready;
    await Future.wait([
      theme.change({'dim': .3}),
      theme.change({'dim': .55}),
      theme.change({
        'name': 'Лиза',
        'bio': 'Вечерний джаз',
        'widgetWidth': 620.0,
        'widgetOnTop': false
      }),
    ]);
    final restored = ThemeProvider();
    await restored.ready;
    expect(restored.dim, .55);
    expect(restored.profileName, 'Лиза');
    expect(restored.widgetWidth, 620);
    expect(restored.widgetOnTop, isFalse);
    theme.dispose();
    restored.dispose();
  });
  test('backdrop edits reuse Material theme and no-op edits skip notifications',
      () async {
    final theme = ThemeProvider();
    await theme.ready;
    final initial = theme.currentTheme;
    var changes = 0;
    theme.addListener(() => changes++);
    await theme.change({'dim': .6});
    await theme.change({'dim': .6});
    expect(changes, 1);
    expect(theme.currentTheme, same(initial));
    await theme.change({'accent': 0xFFFFAA55});
    expect(theme.currentTheme, isNot(same(initial)));
    theme.dispose();
  });
  test('corrupt and out-of-range settings safely fall back or clamp', () async {
    SharedPreferences.setMockInitialValues({
      'appearance_v2': jsonEncode({
        'widgetWidth': -30,
        'dim': 200,
        'font': 'unknown',
        'backgroundType': 'bad',
        'widgetStyle': 'bad',
        'accent': -1,
        'name': '',
      })
    });
    final theme = ThemeProvider();
    await theme.ready;
    expect(theme.widgetWidth, 360);
    expect(theme.dim, .85);
    expect(theme.fontFamily, 'System');
    expect(theme.bgType, BackgroundType.ambient);
    expect(theme.profileName, 'Мой профиль');
    await theme.change({'name': 'Лиза', 'avatar': r'C:\avatar.png'});
    await theme.resetAppearance();
    expect(theme.profileName, 'Лиза');
    expect(theme.avatarPath, r'C:\avatar.png');
    theme.dispose();
  });
  test('window widget mode pins, resizes and restores normal window bounds',
      () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'),
            (call) async {
      calls.add(call);
      if (call.method == 'isMaximized') return false;
      if (call.method == 'getBounds') {
        return {'x': 20.0, 'y': 30.0, 'width': 1280.0, 'height': 720.0};
      }
      return null;
    });
    final theme = ThemeProvider();
    await theme.ready;
    final window = DesktopWindowService();
    await window.enterWidget(theme, youtube: true);
    expect(window.error, isNull);
    expect(window.compact, isTrue);
    expect(
        calls
            .where((c) => c.method == 'setAlwaysOnTop')
            .last
            .arguments['isAlwaysOnTop'],
        true);
    await window.restore();
    expect(window.compact, isFalse);
    expect(calls.where((c) => c.method == 'setBounds').last.arguments['width'],
        1280);
    theme.dispose();
    window.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), null);
  });
  testWidgets('home renders and can switch to compact mode without overflow',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'),
            (call) async {
      if (call.method == 'isMaximized') return false;
      if (call.method == 'getBounds') {
        return {'x': 20.0, 'y': 30.0, 'width': 1280.0, 'height': 720.0};
      }
      return null;
    });
    final theme = ThemeProvider();
    await theme.ready;
    await theme.change({'motion': false});
    final audio =
        AudioPlayerService(player: Player(platformPlayer: FakePlayer()));
    final youtube = YoutubePlayerService(audio);
    final window = DesktopWindowService();
    final db = AppDatabase();
    await tester.binding.setSurfaceSize(const Size(900, 800));
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: theme),
          ChangeNotifierProvider<AudioPlayerService>.value(value: audio),
          ChangeNotifierProvider<YoutubePlayerService>.value(value: youtube),
          ChangeNotifierProvider<DesktopWindowService>.value(value: window),
        ],
        child: MaterialApp(
            theme: theme.currentTheme,
            locale: const Locale('ru'),
            supportedLocales: const [Locale('ru')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: HomeScreen(db: db))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Настроение в один клик'), findsOneWidget);
    await tester.runAsync(() => window.enterWidget(theme));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('oTune'), findsOneWidget);
    await tester.binding.setSurfaceSize(const Size(360, 250));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(const Size(900, 800));
    await tester.runAsync(window.restore);
    await tester.pumpAndSettle();
    expect(find.text('Настроение в один клик'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    youtube.dispose();
    audio.dispose();
    window.dispose();
    theme.dispose();
    await db.close();
    await tester.binding.setSurfaceSize(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), null);
  });

  testWidgets('language selection updates settings and navigation immediately',
      (tester) async {
    final theme = ThemeProvider();
    await theme.ready;
    await theme.change({'motion': false});
    final prefs =
        AppPreferences(await SharedPreferences.getInstance(), windows: false);
    final audio =
        AudioPlayerService(player: Player(platformPlayer: FakePlayer()));
    final youtube = YoutubePlayerService(audio);
    final window = DesktopWindowService();
    final db = AppDatabase();
    await tester.binding.setSurfaceSize(const Size(1024, 760));
    await tester.pumpWidget(MultiProvider(providers: [
      Provider<AppDatabase>.value(value: db),
      ChangeNotifierProvider<ThemeProvider>.value(value: theme),
      ChangeNotifierProvider<AppPreferences>.value(value: prefs),
      ChangeNotifierProvider<AudioPlayerService>.value(value: audio),
      ChangeNotifierProvider<YoutubePlayerService>.value(value: youtube),
      ChangeNotifierProvider<DesktopWindowService>.value(value: window),
    ], child: const OfflinetunesApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Язык'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Язык интерфейса'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    await tester.tap(find.text('Interface language'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'polish');
    await tester.pumpAndSettle();
    expect(find.text('Español'), findsNothing);
    await tester.tap(find.text('Polski'));
    await tester.pumpAndSettle();
    expect(find.text('Język'), findsOneWidget);
    expect(find.text('Biblioteka'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    youtube.dispose();
    audio.dispose();
    window.dispose();
    prefs.dispose();
    theme.dispose();
    await db.close();
    await tester.binding.setSurfaceSize(null);
  });
}

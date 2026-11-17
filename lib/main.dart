import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as time_zones;
import 'data/db/app_database.dart';
import 'data/models/media_link.dart';
import 'data/models/playback_track.dart';
import 'data/services/audio_player_service.dart';
import 'data/services/audius_streams.dart';
import 'data/services/catalog_playback.dart';
import 'data/services/system_media_controls.dart';
import 'data/services/listening_history.dart';
import 'data/services/offline_tracks.dart';
import 'data/services/favorite_tracks.dart';
import 'data/services/update_service.dart';
import 'data/services/app_preferences.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'data/services/desktop_window_service.dart';
import 'data/services/youtube_player_service.dart';
import 'data/services/network_service.dart';
import 'theme/theme_provider.dart';
import 'app.dart';

void main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(480, 600));
  }
  await initializeDateFormatting();
  time_zones.initializeTimeZones();

  final db = AppDatabase();
  final theme = ThemeProvider();
  final prefs = await SharedPreferences.getInstance();
  final preferences = AppPreferences(prefs);
  await preferences.initialize();
  await theme.ready;
  final history = ListeningHistory(prefs);
  final audio = AudioPlayerService(
      onListened: history.record,
      audiusStreams: Platform.isAndroid ? AudiusStreams(http.Client()) : null);
  if (Platform.isAndroid) {
    try {
      final session = await SystemMediaControls.initialize(audio, theme);
      audio.requestAudioFocus = () => session.setActive(true);
    } catch (error) {
      debugPrint('Android media session: $error');
    }
  }
  MediaLink? initialLink;
  if (arguments.isNotEmpty) {
    try {
      initialLink = MediaLink.parse(arguments.first);
    } on FormatException {
      // The application can be launched with a regular command-line flag.
    }
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        ChangeNotifierProvider<AppPreferences>(create: (_) => preferences),
        ChangeNotifierProvider(create: (_) => history, lazy: false),
        ChangeNotifierProvider(create: (_) => FavoriteTracks(db, prefs)),
        if (Platform.isAndroid)
          ChangeNotifierProvider(create: (_) => OfflineTracks()),
        Provider(
            create: (_) => UpdateService(prefs),
            dispose: (_, updates) => updates.dispose()),
        ChangeNotifierProvider<AudioPlayerService>(
          create: (_) => audio,
          lazy: false,
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => theme,
        ),
        ChangeNotifierProvider<YoutubePlayerService>(
            create: (context) => YoutubePlayerService(
                  context.read<AudioPlayerService>(),
                  onListened: context.read<ListeningHistory>().record,
                )),
        ChangeNotifierProvider<CatalogPlayback>(create: (context) {
          final downloads = context.read<OfflineTracks?>();
          return CatalogPlayback(audio, () async {
            await downloads?.ready;
            return [
              ...?downloads?.tracks,
              ...(await db.getAllTracks()).map(PlaybackTrack.fromTrack),
            ];
          });
        }),
        ChangeNotifierProvider<DesktopWindowService>(
            create: (context) => DesktopWindowService(
                theme: theme,
                youtubeActive: () =>
                    context.read<YoutubePlayerService>().active,
                onMinimize:
                    context.read<YoutubePlayerService>().pauseForVisibility)),
        ChangeNotifierProvider<NetworkService>(
          create: (_) => NetworkService(),
        ),
      ],
      child: OfflinetunesApp(initialLink: initialLink),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/db/app_database.dart';
import 'data/services/audio_player_service.dart';
import 'data/services/app_preferences.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'data/services/desktop_window_service.dart';
import 'data/services/youtube_player_service.dart';
import 'data/services/network_service.dart';
import 'data/services/music_api_service.dart'; // Импорт
import 'theme/theme_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(480, 600));
  }
  await initializeDateFormatting();

  final db = AppDatabase();
  final theme = ThemeProvider();
  final preferences = AppPreferences(await SharedPreferences.getInstance());
  await preferences.initialize();
  await theme.ready;

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        ChangeNotifierProvider<AppPreferences>(create: (_) => preferences),
        Provider<MusicApiService>(
          create: (_) => MusicApiService(), // Добавили сервис API
        ),
        ChangeNotifierProvider<AudioPlayerService>(
          create: (_) => AudioPlayerService(),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => theme,
        ),
        ChangeNotifierProvider<YoutubePlayerService>(
            create: (context) =>
                YoutubePlayerService(context.read<AudioPlayerService>())),
        ChangeNotifierProvider<DesktopWindowService>(
            create: (context) => DesktopWindowService(
                onMinimize:
                    context.read<YoutubePlayerService>().pauseForVisibility)),
        ChangeNotifierProvider<NetworkService>(
          create: (_) => NetworkService(),
        ),
      ],
      child: const OfflinetunesApp(),
    ),
  );
}

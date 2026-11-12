import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'data/db/app_database.dart';
import 'data/models/media_link.dart';
import 'data/services/app_preferences.dart';
import 'theme/theme_provider.dart';
import 'features/home/home_screen.dart';

class OfflinetunesApp extends StatelessWidget {
  final MediaLink? initialLink;
  const OfflinetunesApp({super.key, this.initialLink});

  @override
  Widget build(BuildContext context) {
    return Selector2<ThemeProvider, AppPreferences, (ThemeData, Locale)>(
      selector: (_, theme, preferences) =>
          (theme.currentTheme, preferences.locale),
      child:
          HomeScreen(db: context.read<AppDatabase>(), initialLink: initialLink),
      builder: (_, configuration, home) => MaterialApp(
        title: 'OfflineTunes',
        debugShowCheckedModeBanner: false,
        theme: configuration.$1,
        locale: configuration.$2,
        supportedLocales: AppPreferences.languages.keys.map(Locale.new),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: home,
      ),
    );
  }
}

abstract class AppConstants {
  static const String jamendoClientId = String.fromEnvironment(
    'JAMENDO_CLIENT_ID',
    defaultValue: 'bd84fa72', // Базовый публичный ID для теста/демо
  );

  static const String audioChannelId = 'com.example.offlinetunes.channel.audio';
  static const String audioChannelName = 'Воспроизведение oTune';

  static const double minDesktopWidth = 900.0;
  static const double maxContentWidth = 1200.0;
}

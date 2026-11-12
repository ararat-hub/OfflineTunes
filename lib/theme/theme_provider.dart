import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BackgroundType { color, image, video, ambient }

enum WidgetStyle { glass, solid, minimal }

class AppearancePreset {
  final String id, name, description;
  final List<Color> colors;
  final Color accent;
  const AppearancePreset(
      this.id, this.name, this.description, this.colors, this.accent);
}

class ThemeProvider extends ChangeNotifier {
  static const videoExtensions = ['mp4', 'mkv', 'mov', 'webm', 'm4v'];
  static const defaultProfileName = 'Мой профиль';
  static const defaultProfileBio = 'Музыка под ваше настроение';
  static const fonts = [
    'System',
    'Inter',
    'Roboto',
    'Montserrat',
    'Poppins',
    'Outfit',
    'JetBrains Mono',
    'Fira Code'
  ];
  static const presets = [
    AppearancePreset(
        'aurora',
        'Полярное сияние',
        'Холодный зелёный и мягкий свет',
        [Color(0xFF071E26), Color(0xFF12574E), Color(0xFF235079)],
        Color(0xFF75E1C4)),
    AppearancePreset(
        'neon',
        'Неоновая ночь',
        'Фиолетовый, индиго и неон',
        [Color(0xFF141024), Color(0xFF472B81), Color(0xFF193D68)],
        Color(0xFFBEA2FF)),
    AppearancePreset(
        'sunset',
        'Последний закат',
        'Тёплый оранжевый и винный',
        [Color(0xFF291421), Color(0xFF974C42), Color(0xFF553969)],
        Color(0xFFFFBD91)),
    AppearancePreset(
        'ice',
        'Северный лёд',
        'Спокойные оттенки синего',
        [Color(0xFF0D1C31), Color(0xFF27586C), Color(0xFF49677A)],
        Color(0xFFA6DDF5)),
    AppearancePreset(
        'sakura',
        'Сакура',
        'Розовый свет на тёмном фоне',
        [Color(0xFF241323), Color(0xFF6C3A5E), Color(0xFF573D79)],
        Color(0xFFF0B1D0)),
    AppearancePreset(
        'forest',
        'Тихий лес',
        'Мох, хвоя и глубокие тени',
        [Color(0xFF101D18), Color(0xFF294A35), Color(0xFF586246)],
        Color(0xFFBFDB9C)),
    AppearancePreset(
        'amber',
        'Тёплая плёнка',
        'Янтарь, кофе и вечерний свет',
        [Color(0xFF241B17), Color(0xFF755031), Color(0xFF4C3E37)],
        Color(0xFFEAC18E)),
    AppearancePreset(
        'graphite',
        'Графит',
        'Сдержанный монохром',
        [Color(0xFF111318), Color(0xFF2C3039), Color(0xFF373C47)],
        Color(0xFFCFD6E5)),
  ];
  static const _defaults = <String, Object>{
    'preset': 'aurora',
    'backgroundType': 'ambient',
    'mediaPath': '',
    'importedVideoPath': '',
    'importedVideoName': '',
    'backgroundColor': 0xFF071E26,
    'accent': 0xFF75E1C4,
    'font': 'System',
    'dim': .22,
    'blur': 0.0,
    'fit': 'cover',
    'motion': true,
    'panelOpacity': .36,
    'showClock': true,
    'name': defaultProfileName,
    'bio': defaultProfileBio,
    'avatar': '',
    'widgetStyle': 'glass',
    'widgetWidth': 480.0,
    'widgetHeight': 320.0,
    'widgetRadius': 24.0,
    'widgetDim': .28,
    'widgetOnTop': true,
    'widgetArtist': true,
    'widgetProgress': true,
    'widgetClock': false,
  };
  Map<String, Object> _settings = Map.of(_defaults);
  late final Future<void> ready;
  Future<void>? _writes;
  SharedPreferences? _prefs;
  bool _disposed = false;
  (Color, Color, String)? _themeInputs;
  ThemeData? _theme;

  ThemeProvider() {
    ready = _load();
  }
  String get presetId => _settings['preset'] as String;
  AppearancePreset get preset =>
      presets.firstWhere((p) => p.id == presetId, orElse: () => presets.first);
  BackgroundType get bgType => BackgroundType.values.firstWhere(
      (v) => v.name == _settings['backgroundType'],
      orElse: () => BackgroundType.ambient);
  String? get backgroundImagePath => (_settings['mediaPath'] as String).isEmpty
      ? null
      : _settings['mediaPath'] as String;
  String? get importedVideoPath {
    final path = _settings['importedVideoPath'] as String;
    return path.isEmpty ? null : path;
  }

  String get importedVideoName => _settings['importedVideoName'] as String;
  Color get backgroundColor => Color(_settings['backgroundColor'] as int);
  Color get accent => Color(_settings['accent'] as int);
  String get fontFamily => _settings['font'] as String;
  String get currentFontFamily => fontFamily;
  double get dim => _settings['dim'] as double;
  double get blur => _settings['blur'] as double;
  BoxFit get backgroundFit =>
      _settings['fit'] == 'contain' ? BoxFit.contain : BoxFit.cover;
  bool get motion => _settings['motion'] as bool;
  double get panelOpacity => _settings['panelOpacity'] as double;
  bool get showClock => _settings['showClock'] as bool;
  String get profileName => _settings['name'] as String;
  String get profileBio => _settings['bio'] as String;
  String? get avatarPath => (_settings['avatar'] as String).isEmpty
      ? null
      : _settings['avatar'] as String;
  WidgetStyle get widgetStyle =>
      WidgetStyle.values.firstWhere((v) => v.name == _settings['widgetStyle'],
          orElse: () => WidgetStyle.glass);
  double get widgetWidth => _settings['widgetWidth'] as double;
  double get widgetHeight => _settings['widgetHeight'] as double;
  double get widgetRadius => _settings['widgetRadius'] as double;
  double get widgetDim => _settings['widgetDim'] as double;
  bool get widgetOnTop => _settings['widgetOnTop'] as bool;
  bool get widgetArtist => _settings['widgetArtist'] as bool;
  bool get widgetProgress => _settings['widgetProgress'] as bool;
  bool get widgetClock => _settings['widgetClock'] as bool;

  ThemeData get currentTheme {
    final inputs = (accent, backgroundColor, fontFamily);
    if (_themeInputs == inputs) return _theme!;
    final base = ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: inputs.$1, brightness: Brightness.dark),
        scaffoldBackgroundColor: inputs.$2,
        fontFamily: 'Segoe UI');
    final theme = base.copyWith(
      textTheme: inputs.$3 == 'System'
          ? base.textTheme
          : GoogleFonts.getTextTheme(inputs.$3, base.textTheme),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.black.withValues(alpha: .2),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none)),
    );
    _themeInputs = inputs;
    return _theme = theme;
  }

  Future<void> _load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final encoded = _prefs!.getString('appearance_v2');
      if (encoded != null) {
        final data = jsonDecode(encoded);
        if (data is Map<String, dynamic>) _merge(data);
      } else {
        final oldPath = _prefs!.getString('bg_image_path') ?? '';
        final oldType = _prefs!.getInt('bg_type') ?? 0;
        _merge({
          'mediaPath': oldPath,
          'backgroundType': oldType == 1 && oldPath.isNotEmpty
              ? (_isVideo(oldPath) ? 'video' : 'image')
              : 'ambient',
          'font': _prefs!.getString('font_family') ?? 'System',
          'backgroundColor':
              _prefs!.getInt('bg_color') ?? _defaults['backgroundColor'],
        });
      }
    } catch (e) {
      debugPrint('Не удалось загрузить оформление: $e');
    }
    if (importedVideoPath != null) await _removeUnusedVideos();
    if (!_disposed) notifyListeners();
  }

  void _merge(Map<String, dynamic> values) {
    for (final entry in values.entries) {
      final expected = _defaults[entry.key];
      final value = entry.value;
      if (expected is double && value is num && value.isFinite) {
        _settings[entry.key] = value.toDouble();
      } else if (expected is int &&
          value is int &&
          value >= 0 &&
          value <= 0xFFFFFFFF) {
        _settings[entry.key] = value;
      } else if (expected is String && value is String) {
        _settings[entry.key] = value;
      } else if (expected is bool && value is bool) {
        _settings[entry.key] = value;
      }
    }
    for (final entry in {
      'dim': [.0, .85],
      'blur': [.0, 16.0],
      'panelOpacity': [.05, .95],
      'widgetDim': [.0, .85],
      'widgetRadius': [0.0, 40.0],
      'widgetWidth': [360.0, 800.0],
      'widgetHeight': [250.0, 700.0]
    }.entries) {
      _settings[entry.key] = (_settings[entry.key] as double)
          .clamp(entry.value[0], entry.value[1]);
    }
    if (!fonts.contains(fontFamily)) _settings['font'] = 'System';
    if (!presets.any((p) => p.id == presetId)) {
      _settings['preset'] = presets.first.id;
    }
    if (!BackgroundType.values
        .any((v) => v.name == _settings['backgroundType'])) {
      _settings['backgroundType'] = 'ambient';
    }
    if (!WidgetStyle.values.any((v) => v.name == _settings['widgetStyle'])) {
      _settings['widgetStyle'] = 'glass';
    }
    if (!['cover', 'contain'].contains(_settings['fit'])) {
      _settings['fit'] = 'cover';
    }
    _settings['name'] = profileName.trim().isEmpty
        ? defaultProfileName
        : profileName.substring(0, profileName.length.clamp(0, 40));
    _settings['bio'] = profileBio.substring(0, profileBio.length.clamp(0, 140));
  }

  Future<void> change(Map<String, dynamic> values) async {
    await ready;
    if (_disposed) return;
    final previous = _settings;
    _settings = Map.of(previous);
    _merge(values);
    if (mapEquals(previous, _settings)) {
      _settings = previous;
      await _writes;
      return;
    }
    notifyListeners();
    await (_writes ??= _saveLatestSettings());
  }

  Future<void> _saveLatestSettings() async {
    try {
      Map<String, Object> snapshot;
      do {
        snapshot = _settings;
        await _prefs?.setString('appearance_v2', jsonEncode(snapshot));
      } while (!identical(snapshot, _settings));
    } finally {
      _writes = null;
    }
  }

  Future<void> applyPreset(AppearancePreset preset) => change({
        'preset': preset.id,
        'backgroundType': 'ambient',
        'backgroundColor': preset.colors.first.toARGB32(),
        'accent': preset.accent.toARGB32(),
        'dim': .22,
        'blur': 0.0,
        'panelOpacity': .36,
      });
  Future<void> setBackgroundType(BackgroundType type) =>
      change({'backgroundType': type.name});
  Future<void> setBackgroundColor(Color color) =>
      change({'backgroundColor': color.toARGB32(), 'backgroundType': 'color'});
  Future<void> setFontFamily(String font) => change({'font': font});
  Future<void> setBackgroundImage(String? path) => setBackgroundImagePath(path);
  Future<void> setBackgroundImagePath(String? path) => change({
        'mediaPath': path ?? '',
        'backgroundType':
            path == null ? 'ambient' : (_isVideo(path) ? 'video' : 'image')
      });
  static bool _isVideo(String path) => videoExtensions
      .contains(p.extension(path).replaceFirst('.', '').toLowerCase());

  Future<Directory> _videoFolder() async => Directory(p.join(
      (await getApplicationSupportDirectory()).path, 'video_backgrounds'));

  Future<void> importBackgroundVideo(String path,
      {Directory? directory}) async {
    await ready;
    final source = File(path);
    if (!_isVideo(path) || await source.length() == 0) {
      throw const FormatException('Выберите непустой видеофайл.');
    }
    final folder = directory ?? await _videoFolder();
    await folder.create(recursive: true);
    final target = p.join(folder.path,
        'background-${DateTime.now().microsecondsSinceEpoch}${p.extension(path).toLowerCase()}');
    final temporary = File('$target.part');
    try {
      await source.copy(temporary.path);
      await temporary.rename(target);
      await change({
        'importedVideoPath': target,
        'importedVideoName': p.basename(path),
        'mediaPath': target,
        'backgroundType': BackgroundType.video.name,
      });
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<void> _removeUnusedVideos() async {
    try {
      final folder = await _videoFolder();
      if (!await folder.exists()) return;
      await for (final file in folder.list(followLinks: false)) {
        if (file is File &&
            RegExp(r'^background-\d+\.(mp4|mkv|mov|webm|m4v)(\.part)?$')
                .hasMatch(p.basename(file.path)) &&
            file.path != importedVideoPath &&
            file.path != backgroundImagePath) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Background video cleanup: $e');
    }
  }

  Future<void> resetAppearance() async {
    await ready;
    await change({
      ..._defaults,
      'name': profileName,
      'bio': profileBio,
      'avatar': avatarPath ?? '',
      'importedVideoPath': importedVideoPath ?? '',
      'importedVideoName': importedVideoName,
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

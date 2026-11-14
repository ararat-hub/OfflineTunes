import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

enum BackgroundType { color, image, video, ambient }

enum WidgetStyle { glass, solid, minimal }

typedef VideoLoop = ({int from, int? to});

class AppearanceFile {
  const AppearanceFile(this.path, this.name);
  final String path;
  final String name;

  Map<String, String> toJson() => {'path': path, 'name': name};
}

class AppearancePreset {
  final String id, name, description;
  final List<Color> colors;
  final Color accent;
  const AppearancePreset(
      this.id, this.name, this.description, this.colors, this.accent);
}

class ThemeProvider extends ChangeNotifier {
  static const videoExtensions = ['mp4', 'mkv', 'mov', 'webm', 'm4v'];
  static const imageExtensions = ['jpg', 'jpeg', 'png', 'webp'];
  static const fontExtensions = ['ttf', 'otf'];
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
    'savedBackgrounds': '',
    'savedWidgets': '',
    'savedFonts': '',
    'widgetMediaPath': '',
    'widgetFit': '',
    'widgetBlur': -1.0,
    'widgetMotion': '',
    'systemWidgetArtwork': 'track',
    'loopFrom': 0,
    'loopTo': 0,
    'widgetLoopFrom': 0,
    'widgetLoopTo': 0,
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
  final _loadedFonts = <String>{};
  final _backgroundDurations = <String, Duration>{};

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
  String? get widgetMediaPath {
    final path = _settings['widgetMediaPath'] as String;
    return path.isEmpty ? null : path;
  }

  String? mediaPath({required bool compact}) =>
      compact && widgetMediaPath != null
          ? widgetMediaPath
          : backgroundImagePath;

  BackgroundType backgroundType({required bool compact}) =>
      compact && widgetMediaPath != null
          ? (_isVideo(widgetMediaPath!)
              ? BackgroundType.video
              : BackgroundType.image)
          : bgType;

  VideoLoop videoLoop({required bool compact}) {
    final widgetUsesOwnMedia = compact && widgetMediaPath != null;
    final from =
        _settings[widgetUsesOwnMedia ? 'widgetLoopFrom' : 'loopFrom'] as int;
    final to = _settings[widgetUsesOwnMedia ? 'widgetLoopTo' : 'loopTo'] as int;
    final duration = _backgroundDurations[mediaPath(compact: compact)];
    if (duration != null && Duration(seconds: from) >= duration) {
      return (from: 0, to: null);
    }
    return (
      from: from,
      to: to > from && (duration == null || Duration(seconds: to) < duration)
          ? to
          : null
    );
  }

  Duration? backgroundDuration(String? path) => _backgroundDurations[path];

  void noteBackgroundDuration(String path, Duration duration) {
    if (_disposed ||
        duration <= Duration.zero ||
        _backgroundDurations[path] == duration) {
      return;
    }
    _backgroundDurations[path] = duration;
    notifyListeners();
  }

  Future<void> setVideoLoop(VideoLoop loop, {required bool compact}) => change({
        if (compact) 'widgetLoopFrom': loop.from else 'loopFrom': loop.from,
        if (compact) 'widgetLoopTo': loop.to ?? 0 else 'loopTo': loop.to ?? 0,
      });

  List<AppearanceFile> get savedBackgrounds {
    final files = _files('savedBackgrounds');
    if (importedVideoPath != null &&
        files.every((item) => item.path != importedVideoPath)) {
      files.add(AppearanceFile(importedVideoPath!, importedVideoName));
    }
    return files;
  }

  List<AppearanceFile> get savedFonts => _files('savedFonts');
  static String fontId(AppearanceFile file) =>
      'file-${p.basenameWithoutExtension(file.path)}';

  List<AppearanceFile> _files(String key) {
    try {
      final raw = _settings[key] as String;
      if (raw.isEmpty) return [];
      final rows = jsonDecode(raw) as List;
      return [
        for (final row in rows.whereType<Map>())
          if (row['path'] is String && row['name'] is String)
            AppearanceFile(row['path'] as String, row['name'] as String),
      ];
    } catch (_) {
      return [];
    }
  }

  String backgroundName(String path) {
    for (final file in savedBackgrounds) {
      if (file.path == path) return file.name;
    }
    return p.basename(path);
  }

  Color get backgroundColor => Color(_settings['backgroundColor'] as int);
  Color get accent => Color(_settings['accent'] as int);
  String get fontFamily => _settings['font'] as String;
  String get currentFontFamily => fontFamily;
  double get dim => _settings['dim'] as double;
  double get blur => _settings['blur'] as double;
  BoxFit get backgroundFit =>
      _settings['fit'] == 'contain' ? BoxFit.contain : BoxFit.cover;
  bool get motion => _settings['motion'] as bool;
  BoxFit backdropFit(bool compact) =>
      switch (compact ? _settings['widgetFit'] : '') {
        'contain' => BoxFit.contain,
        'cover' => BoxFit.cover,
        _ => backgroundFit,
      };
  double backdropBlur(bool compact) {
    final value = _settings['widgetBlur'] as double;
    return compact && value >= 0 ? value : blur;
  }

  bool backdropMotion(bool compact) =>
      switch (compact ? _settings['widgetMotion'] : '') {
        'on' => true,
        'off' => false,
        _ => motion,
      };
  bool get systemWidgetUsesBackground =>
      _settings['systemWidgetArtwork'] == 'background';
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
      splashFactory: Platform.isWindows ? InkRipple.splashFactory : null,
      hoverColor: Platform.isWindows ? inputs.$1.withValues(alpha: .10) : null,
      highlightColor:
          Platform.isWindows ? inputs.$1.withValues(alpha: .18) : null,
      focusColor: Platform.isWindows ? inputs.$1.withValues(alpha: .14) : null,
      navigationRailTheme: Platform.isWindows
          ? NavigationRailThemeData(
              indicatorShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9)),
              indicatorColor: inputs.$1.withValues(alpha: .20),
            )
          : null,
      textTheme: switch (inputs.$3) {
        'System' => base.textTheme,
        final family when _loadedFonts.contains(family) =>
          base.textTheme.apply(fontFamily: family),
        final family when fonts.contains(family) =>
          GoogleFonts.getTextTheme(family, base.textTheme),
        _ => base.textTheme,
      },
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
    final legacyMedia = backgroundImagePath;
    if (legacyMedia != null &&
        !legacyMedia.startsWith('asset:///') &&
        savedBackgrounds.every((file) => file.path != legacyMedia)) {
      _settings['savedBackgrounds'] = jsonEncode([
        AppearanceFile(legacyMedia, p.basename(legacyMedia)).toJson(),
        ...savedBackgrounds.map((file) => file.toJson()),
      ]);
    }
    if (!fonts.contains(fontFamily)) {
      try {
        await _loadFont(
            savedFonts.firstWhere((file) => fontId(file) == fontFamily));
      } catch (error) {
        debugPrint('Restore custom font: $error');
        _settings['font'] = 'System';
      }
    }
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
      'widgetBlur': [-1.0, 16.0],
      'widgetRadius': [0.0, 40.0],
      'widgetWidth': [360.0, 800.0],
      'widgetHeight': [250.0, 700.0]
    }.entries) {
      _settings[entry.key] = (_settings[entry.key] as double)
          .clamp(entry.value[0], entry.value[1]);
    }
    for (final key in [
      'loopFrom',
      'loopTo',
      'widgetLoopFrom',
      'widgetLoopTo'
    ]) {
      _settings[key] = (_settings[key] as int).clamp(0, 86400);
    }
    if (!fonts.contains(fontFamily) &&
        !savedFonts.any((file) => fontId(file) == fontFamily)) {
      _settings['font'] = 'System';
    }
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
  Future<void> setFontFamily(String font) async {
    if (!fonts.contains(font)) {
      await _loadFont(savedFonts.firstWhere((file) => fontId(file) == font));
    }
    await change({'font': font});
  }

  Future<void> setBackgroundImage(String? path) => setBackgroundImagePath(path);
  Future<void> setBackgroundImagePath(String? path) => change({
        'mediaPath': path ?? '',
        if (path != backgroundImagePath) 'loopFrom': 0,
        if (path != backgroundImagePath) 'loopTo': 0,
        'backgroundType':
            path == null ? 'ambient' : (_isVideo(path) ? 'video' : 'image')
      });
  Future<void> setWidgetBackground(String? path) => change({
        'widgetMediaPath': path ?? '',
        if (Platform.isAndroid)
          'systemWidgetArtwork': path == null ? 'track' : 'background',
        if (path != widgetMediaPath) 'widgetLoopFrom': 0,
        if (path != widgetMediaPath) 'widgetLoopTo': 0,
      });

  static const _widgetKeys = [
    'widgetMediaPath',
    'systemWidgetArtwork',
    'widgetFit',
    'widgetBlur',
    'widgetMotion',
    'widgetLoopFrom',
    'widgetLoopTo',
    'widgetWidth',
    'widgetHeight',
    'widgetRadius',
    'widgetDim',
    'widgetStyle',
    'widgetArtist',
    'widgetProgress',
    'widgetClock',
    'widgetOnTop',
  ];

  Map<String, Map<String, dynamic>> get savedWidgets {
    try {
      final data = jsonDecode(_settings['savedWidgets'] as String);
      if (data is Map<String, dynamic>) {
        return data.map((name, value) =>
            MapEntry(name, Map<String, dynamic>.from(value as Map)));
      }
    } catch (_) {/* Missing or invalid settings use an empty list. */}
    return {};
  }

  Future<void> saveWidget(String name) async {
    await ready;
    final clean = name.trim();
    if (clean.isEmpty) return;
    final saved = savedWidgets;
    final values = {for (final key in _widgetKeys) key: _settings[key]};
    if (!Platform.isAndroid &&
        widgetMediaPath == null &&
        mediaPath(compact: false) != null) {
      values['widgetMediaPath'] = mediaPath(compact: false);
      values['widgetLoopFrom'] = _settings['loopFrom'];
      values['widgetLoopTo'] = _settings['loopTo'];
    }
    await change({
      'savedWidgets': jsonEncode({...saved, clean: values})
    });
  }

  Future<void> applyWidget(String name) async {
    final values = savedWidgets[name];
    if (values != null) {
      await change({
        for (final key in _widgetKeys)
          if (values.containsKey(key)) key: values[key],
        if (Platform.isAndroid && !values.containsKey('systemWidgetArtwork'))
          'systemWidgetArtwork':
              (values['widgetMediaPath'] as String? ?? '').isEmpty
                  ? 'track'
                  : 'background',
      });
    }
  }

  Future<void> importAvatar(String path) async {
    final avatar = await _copyFile(path, imageExtensions, 'avatars');
    final previous = avatarPath;
    await change({'avatar': avatar.path});
    if (previous != null && p.dirname(previous) == p.dirname(avatar.path)) {
      try {
        await File(previous).delete();
      } on FileSystemException {/* The old copy may already be gone. */}
    }
  }

  static bool _isVideo(String path) => videoExtensions
      .contains(p.extension(path).replaceFirst('.', '').toLowerCase());

  Future<void> importBackgroundVideo(String path,
      {Directory? directory, bool compact = false}) async {
    if (!_isVideo(path)) throw const FormatException('Expected a video file');
    await importBackground(path, compact: compact, directory: directory);
  }

  Future<void> importBackground(String path,
      {required bool compact, Directory? directory}) async {
    await ready;
    final copied = await _copyFile(
        path, [...imageExtensions, ...videoExtensions], 'saved_backgrounds',
        directory: directory);
    await change({
      'savedBackgrounds': jsonEncode(
          [copied.toJson(), ...savedBackgrounds.map((file) => file.toJson())]),
      if (_isVideo(copied.path)) 'importedVideoPath': copied.path,
      if (_isVideo(copied.path)) 'importedVideoName': copied.name,
      if (compact) ...{
        'widgetMediaPath': copied.path,
        if (Platform.isAndroid) 'systemWidgetArtwork': 'background',
        'widgetLoopFrom': 0,
        'widgetLoopTo': 0,
      } else ...{
        'mediaPath': copied.path,
        'loopFrom': 0,
        'loopTo': 0,
        'backgroundType': _isVideo(copied.path) ? 'video' : 'image',
      },
    });
  }

  Future<void> importFont(String path, {Directory? directory}) async {
    await ready;
    if (await File(path).length() > 32 * 1024 * 1024) {
      throw const FormatException('Font exceeds 32 MB');
    }
    final copied =
        await _copyFile(path, fontExtensions, 'fonts', directory: directory);
    try {
      await _loadFont(copied);
    } catch (_) {
      await File(copied.path).delete();
      rethrow;
    }
    await change({
      'savedFonts': jsonEncode(
          [...savedFonts.map((file) => file.toJson()), copied.toJson()]),
      'font': fontId(copied),
    });
  }

  Future<void> _loadFont(AppearanceFile file) async {
    final id = fontId(file);
    if (_loadedFonts.contains(id)) return;
    final bytes = await File(file.path).readAsBytes();
    if (bytes.length < 12) throw const FormatException('Invalid font file');
    final header = ByteData.sublistView(bytes).getUint32(0);
    if (header != 0x00010000 && header != 0x4f54544f) {
      throw const FormatException('Expected a TTF or OTF font');
    }
    final loader = FontLoader(id)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    _loadedFonts.add(id);
  }

  Future<AppearanceFile> _copyFile(
      String path, List<String> extensions, String storage,
      {Directory? directory}) async {
    final extension = p.extension(path).toLowerCase();
    final source = File(path);
    if (!extensions.contains(extension.replaceFirst('.', '')) ||
        await source.length() == 0) {
      throw const FormatException('Invalid appearance file');
    }
    final folder = directory ??
        Directory(
            p.join((await getApplicationSupportDirectory()).path, storage));
    await folder.create(recursive: true);
    final target = p.join(folder.path, '${const Uuid().v4()}$extension');
    final temporary = File('$target.part');
    try {
      await source.copy(temporary.path);
      await temporary.rename(target);
      return AppearanceFile(target, p.basename(path));
    } finally {
      if (await temporary.exists()) await temporary.delete();
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
      'savedBackgrounds': _settings['savedBackgrounds'],
      'savedFonts': _settings['savedFonts'],
      'savedWidgets': _settings['savedWidgets'],
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

import 'dart:async';
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HotkeyAction { playPause, next, previous, mute, widget }

typedef HotkeyBinding = ({int modifiers, int key});

class AppPreferences extends ChangeNotifier {
  AppPreferences(this._prefs, {bool? windows})
      : supportsHotkeys = windows ?? Platform.isWindows;

  static const languages = {
    'ru': 'Русский',
    'en': 'English',
    'es': 'Español',
    'de': 'Deutsch',
    'fr': 'Français',
  };
  static const _channel = MethodChannel('offlinetunes/hotkeys');
  static const _defaultKeys = [0x50, 0x4E, 0x42, 0x4D, 0x57];
  static const keyChoices = <int>[
    ...[0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39],
    ...[
      0x41,
      0x42,
      0x43,
      0x44,
      0x45,
      0x46,
      0x47,
      0x48,
      0x49,
      0x4A,
      0x4B,
      0x4C,
      0x4D,
      0x4E,
      0x4F,
      0x50,
      0x51,
      0x52,
      0x53,
      0x54,
      0x55,
      0x56,
      0x57,
      0x58,
      0x59,
      0x5A
    ],
    ...[0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A],
  ];
  static const modifierChoices = {
    3: 'Ctrl + Alt',
    6: 'Ctrl + Shift',
    5: 'Alt + Shift',
    7: 'Ctrl + Alt + Shift',
  };

  final SharedPreferences _prefs;
  final bool supportsHotkeys;
  final _pressed = StreamController<HotkeyAction>.broadcast();
  final Set<HotkeyAction> _unavailable = {};
  bool _busy = false;
  bool _disposed = false;
  Stream<HotkeyAction> get pressed => _pressed.stream;
  bool get hotkeysEnabled => _prefs.getBool('hotkeys_enabled') ?? false;
  bool get busy => _busy;
  bool unavailable(HotkeyAction action) => _unavailable.contains(action);

  Locale get locale {
    final code = _prefs.getString('interface_language');
    return Locale(languages.containsKey(code) ? code! : 'ru');
  }

  static List<String> get timeZones => tz.timeZoneDatabase.locations.keys
      .where((zone) => zone.contains('/') && !zone.startsWith('Etc/'))
      .toList()
    ..sort();

  String get timeZone => _prefs.getString('clock_time_zone') ?? '';

  DateTime clockTime([DateTime? instant]) {
    final now = instant ?? DateTime.now();
    final zone = tz.timeZoneDatabase.locations[timeZone];
    return zone == null ? now.toLocal() : tz.TZDateTime.from(now, zone);
  }

  Future<void> setTimeZone(String value) async {
    if (value == timeZone ||
        (value.isNotEmpty &&
            !tz.timeZoneDatabase.locations.containsKey(value))) {
      return;
    }
    if (!await _prefs.setString('clock_time_zone', value)) {
      throw StateError('Could not save the time zone');
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (!languages.containsKey(code) || code == locale.languageCode) return;
    final saved = await _prefs.setString('interface_language', code);
    if (!saved) throw StateError('Could not save interface language');
    if (!_disposed) notifyListeners();
  }

  static String keyLabel(int key) =>
      key >= 0x70 ? 'F${key - 0x70 + 1}' : String.fromCharCode(key);

  HotkeyBinding binding(HotkeyAction action) {
    final value = _prefs.getInt('hotkey_${action.name}');
    final modifiers = (value ?? 0) >> 8;
    final key = (value ?? 0) & 0xff;
    if (modifierChoices.containsKey(modifiers) && keyChoices.contains(key)) {
      return (modifiers: modifiers, key: key);
    }
    return (modifiers: 3, key: _defaultKeys[action.index]);
  }

  Future<void> initialize() async {
    if (!supportsHotkeys) return;
    _channel.setMethodCallHandler((call) async {
      final id = call.arguments;
      if (call.method == 'pressed' &&
          !_disposed &&
          !_busy &&
          hotkeysEnabled &&
          id is int &&
          id >= 0 &&
          id < HotkeyAction.values.length) {
        _pressed.add(HotkeyAction.values[id]);
      }
    });
    if (hotkeysEnabled) await _registerAll(true);
  }

  Future<void> _registerAll(bool enabled) async {
    _unavailable.clear();
    for (final action in HotkeyAction.values) {
      if (!await _register(action, enabled ? binding(action) : null)) {
        _unavailable.add(action);
      }
    }
  }

  Future<bool> _register(HotkeyAction action, HotkeyBinding? value) async {
    try {
      return await _channel.invokeMethod<bool>('bind', {
            'id': action.index,
            'key': value?.key ?? 0,
            'modifiers': value?.modifiers ?? 0,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> setHotkeysEnabled(bool enabled) async {
    if (!supportsHotkeys || _busy || enabled == hotkeysEnabled) return;
    _busy = true;
    notifyListeners();
    try {
      if (!await _prefs.setBool('hotkeys_enabled', enabled)) {
        throw StateError('Could not save shortcut settings');
      }
      await _registerAll(enabled);
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> setBinding(HotkeyAction action, HotkeyBinding value) async {
    if (!supportsHotkeys || _busy) return false;
    if (!modifierChoices.containsKey(value.modifiers) ||
        !keyChoices.contains(value.key) ||
        HotkeyAction.values
            .any((other) => other != action && binding(other) == value)) {
      return false;
    }
    final previous = binding(action);
    if (previous == value && !_unavailable.contains(action)) return true;
    _busy = true;
    notifyListeners();
    try {
      if (hotkeysEnabled && !await _register(action, value)) return false;
      final encoded = value.modifiers << 8 | value.key;
      try {
        if (!await _prefs.setInt('hotkey_${action.name}', encoded)) {
          throw StateError('Could not save keyboard shortcut');
        }
      } catch (_) {
        if (hotkeysEnabled && !await _register(action, previous)) {
          _unavailable.add(action);
        }
        rethrow;
      }
      _unavailable.remove(action);
      return true;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (supportsHotkeys) {
      _channel.setMethodCallHandler(null);
      unawaited(_registerAll(false));
    }
    unawaited(_pressed.close());
    super.dispose();
  }
}

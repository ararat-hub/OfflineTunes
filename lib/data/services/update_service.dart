import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUpdate {
  const AppUpdate(this.version, this.page);
  final String version;
  final Uri page;
}

class UpdateService {
  UpdateService(this._prefs, {http.Client? client, String? installedVersion})
      : _client = client ?? http.Client(),
        _installedVersion = installedVersion;

  static final _latest = Uri.https(
    'api.github.com',
    '/repos/ararat-hub/OfflineTunes/releases/latest',
  );
  final SharedPreferences _prefs;
  final http.Client _client;
  String? _installedVersion;
  Future<AppUpdate?>? _pending;
  bool get automatic => _prefs.getBool('update_check_automatic') ?? true;

  Future<void> setAutomatic(bool value) =>
      _prefs.setBool('update_check_automatic', value);

  Future<void> markOffered(AppUpdate update) =>
      _prefs.setString('update_last_offered', update.version);

  Future<AppUpdate?> check({bool manual = false}) async {
    if (!manual) {
      if (!automatic) return null;
      final last = _prefs.getInt('update_last_check') ?? 0;
      if (DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last)) <
          const Duration(days: 1)) {
        return null;
      }
    }
    final update = await (_pending ??= _check());
    if (!manual && update?.version == _prefs.getString('update_last_offered')) {
      return null;
    }
    return update;
  }

  Future<AppUpdate?> _check() async {
    try {
      final response = await _client.get(_latest, headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'OfflineTunes/1.4',
      }).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw http.ClientException('GitHub Releases: ${response.statusCode}');
      }
      _installedVersion ??= (await PackageInfo.fromPlatform()).version;
      final release =
          parseRelease(jsonDecode(response.body), _installedVersion!);
      await _prefs.setInt(
          'update_last_check', DateTime.now().millisecondsSinceEpoch);
      return release;
    } finally {
      _pending = null;
    }
  }

  static AppUpdate? parseRelease(Object? payload, String installed) {
    if (payload is! Map ||
        payload['draft'] == true ||
        payload['prerelease'] == true) {
      return null;
    }
    final tag = payload['tag_name'];
    if (tag is! String) return null;
    final current = _version(installed);
    final newer = _version(tag);
    if (current == null || newer == null) return null;
    for (var i = 0; i < current.length; i++) {
      if (newer[i] < current[i]) return null;
      if (newer[i] > current[i]) {
        return AppUpdate(
            newer.join('.'),
            Uri.https(
              'github.com',
              '/ararat-hub/OfflineTunes/releases/tag/$tag',
            ));
      }
    }
    return null;
  }

  static List<int>? _version(String text) {
    final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:\+\d+)?$').firstMatch(text);
    return match == null
        ? null
        : [for (var i = 1; i <= 3; i++) int.parse(match[i]!)];
  }

  void dispose() => _client.close();
}

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUpdate {
  const AppUpdate(this.version, this.page, {this.download});
  final String version;
  final Uri page;
  final Uri? download;
}

class UpdateService {
  UpdateService(this._prefs,
      {http.Client? client, String? installedVersion, String? assetExtension})
      : _client = client ?? http.Client(),
        _installedVersion = installedVersion,
        _assetExtension = assetExtension ??
            (Platform.isAndroid
                ? '.apk'
                : Platform.isWindows
                    ? '.exe'
                    : null);

  static final _latest = Uri.https(
    'api.github.com',
    '/repos/ararat-hub/OfflineTunes/releases/latest',
  );
  final SharedPreferences _prefs;
  final http.Client _client;
  String? _installedVersion;
  final String? _assetExtension;
  Future<AppUpdate?>? _pending;
  DateTime? _lastRequest;
  bool get automatic => _prefs.getBool('update_check_automatic') ?? true;

  Future<void> setAutomatic(bool value) =>
      _prefs.setBool('update_check_automatic', value);

  Future<void> markOffered(AppUpdate update) async {
    await _prefs.setString('update_last_offered', update.version);
    await _prefs.setInt(
        'update_last_offer_time', DateTime.now().millisecondsSinceEpoch);
  }

  Future<AppUpdate?> check({bool manual = false}) async {
    if (!manual) {
      if (!automatic) return null;
      final last = _lastRequest;
      if (last != null &&
          DateTime.now().difference(last) < const Duration(minutes: 30)) {
        return null;
      }
    }
    final update = await (_pending ??= _check());
    if (!manual && update != null) {
      final last = _prefs.getInt('update_last_offer_time') ?? 0;
      if (update.version == _prefs.getString('update_last_offered') &&
          DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last)) <
              const Duration(days: 1)) {
        return null;
      }
    }
    return update;
  }

  Future<AppUpdate?> _check() async {
    try {
      final response = await _client.get(_latest, headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'oTune (https://github.com/ararat-hub/OfflineTunes)',
        'Cache-Control': 'no-cache',
      }).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw http.ClientException('GitHub Releases: ${response.statusCode}');
      }
      _installedVersion ??= (await PackageInfo.fromPlatform()).version;
      final release = parseRelease(
          jsonDecode(response.body), _installedVersion!,
          assetExtension: _assetExtension);
      _lastRequest = DateTime.now();
      return release;
    } finally {
      _pending = null;
    }
  }

  static AppUpdate? parseRelease(Object? payload, String installed,
      {String? assetExtension}) {
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
        final page = Uri.https(
            'github.com', '/ararat-hub/OfflineTunes/releases/tag/$tag');
        final assets = payload['assets'];
        Uri? download;
        if (assetExtension != null) {
          final fileName = assetExtension == '.apk'
              ? 'oTune-Android-${newer.join('.')}.apk'
              : 'oTune-Setup-${newer.join('.')}.exe';
          final expected = Uri.https('github.com',
              '/ararat-hub/OfflineTunes/releases/download/$tag/$fileName');
          if (assets is List &&
              assets.whereType<Map>().any((asset) =>
                  asset['name'] == fileName &&
                  asset['state'] == 'uploaded' &&
                  asset['browser_download_url'] == expected.toString())) {
            download = expected;
          } else {
            return null;
          }
        }
        return AppUpdate(newer.join('.'), page, download: download);
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

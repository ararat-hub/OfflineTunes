class MediaLink {
  final Uri uri;
  final String? youtubeId;
  final int startSeconds;
  const MediaLink._(this.uri, this.youtubeId, this.startSeconds);
  bool get isYoutube => youtubeId != null;
  bool get isDownloadableAudio =>
      !isYoutube && uri.scheme == 'https' && isDirectAudioFile(uri);

  static bool isDirectAudioFile(Uri uri) =>
      RegExp(r'\.(mp3|flac|m4a|aac|wav|ogg|oga|opus)$', caseSensitive: false)
          .hasMatch(uri.path);

  static bool isStorePreview(Uri uri) {
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    return ((host.endsWith('.itunes.apple.com') ||
                host.endsWith('.mzstatic.com')) &&
            path.contains('/audiopreview')) ||
        (host.startsWith('cdns-preview-') && host.endsWith('.dzcdn.net'));
  }

  static const zaycevHost = 'zaycev.net';
  static final _zaycevPage = RegExp(r'^/pages/\d+/(\d+)\.shtml$');

  static Uri zaycevTrackPage(int id) =>
      Uri.https(zaycevHost, '/pages/${id ~/ 100}/$id.shtml');

  static int? zaycevTrackId(String path) {
    final uri = Uri.tryParse(path);
    if (uri == null ||
        !uri.isScheme('https') ||
        uri.host != zaycevHost ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    final match = _zaycevPage.firstMatch(uri.path);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  Uri get canonicalYoutubeUrl => Uri.https('www.youtube.com', '/watch',
      {'v': youtubeId!, if (startSeconds > 0) 't': '${startSeconds}s'});

  factory MediaLink.parse(String input) {
    var text = input.trim();
    if (!text.contains('://')) text = 'https://$text';
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException(
          'Введите корректную ссылку HTTPS на YouTube или аудиофайл.');
    }
    final host = uri.host.toLowerCase();
    String? id;
    if (['youtu.be', 'www.youtu.be'].contains(host)) {
      if (uri.pathSegments.isNotEmpty) id = uri.pathSegments.first;
    } else if ([
      'youtube.com',
      'www.youtube.com',
      'm.youtube.com',
      'music.youtube.com',
      'youtube-nocookie.com',
      'www.youtube-nocookie.com'
    ].contains(host)) {
      if (uri.path == '/watch') {
        id = uri.queryParameters['v'];
      } else if (uri.pathSegments.length >= 2 &&
          ['shorts', 'embed', 'live'].contains(uri.pathSegments.first)) {
        id = uri.pathSegments[1];
      }
    }
    if (id != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) {
      final rawTime =
          uri.queryParameters['t'] ?? uri.queryParameters['start'] ?? '';
      var seconds = int.tryParse(rawTime) ?? 0;
      if (seconds == 0) {
        final match =
            RegExp(r'^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?$').firstMatch(rawTime);
        if (match != null) {
          seconds = (int.tryParse(match[1] ?? '') ?? 0) * 3600 +
              (int.tryParse(match[2] ?? '') ?? 0) * 60 +
              (int.tryParse(match[3] ?? '') ?? 0);
        }
      }
      return MediaLink._(uri, id, seconds.clamp(0, 604800));
    }
    if (isDirectAudioFile(uri) || uri.path.toLowerCase().endsWith('.m3u8')) {
      return MediaLink._(uri, null, 0);
    }
    throw const FormatException(
        'Нужна ссылка на отдельный ролик YouTube или прямая ссылка на аудиофайл.');
  }
}

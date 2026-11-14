import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:webview_flutter/webview_flutter.dart' as mobile;
import '../models/media_link.dart';
import '../models/playback_track.dart';
import 'audio_player_service.dart';

class YoutubePlayerService extends ChangeNotifier {
  static const appId = 'io.github.ararat-hub.offlinetunes';
  static const _androidAppId = 'com.example.offlinetunes';
  static Future<void>? _environment;
  final AudioPlayerService audio;
  final ValueChanged<PlaybackTrack>? onListened;
  WebviewController? controller;
  mobile.WebViewController? androidController;
  Future<void>? _initializing;
  StreamSubscription<dynamic>? _messages;
  StreamSubscription<LoadingState>? _navigation;
  StreamSubscription<WebErrorStatus>? _loadErrors;
  Timer? _timeout;
  bool active = false;
  bool loading = false;
  bool playing = false;
  bool watchPage = false;
  bool _starting = false;
  bool _disposed = false;
  bool _recorded = false;
  int _generation = 0;
  String? error;
  String title = 'YouTube';
  MediaLink? link;
  bool get initialized =>
      androidController != null || (controller?.value.isInitialized ?? false);

  YoutubePlayerService(this.audio, {this.onListened}) {
    audio.addListener(_audioChanged);
  }
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _audioChanged() {
    if (active && !_starting && audio.isPlaying) unawaited(close());
  }

  Future<void> open(MediaLink media) async {
    if (!media.isYoutube) throw const FormatException('Нужна ссылка YouTube');
    final generation = ++_generation;
    _timeout?.cancel();
    _starting = true;
    active = true;
    loading = true;
    playing = false;
    _recorded = false;
    watchPage = false;
    error = null;
    title = 'YouTube · ${media.youtubeId}';
    link = media;
    _notify();
    try {
      await audio.pause();
      await (_initializing ??= _initialize());
      if (_disposed || generation != _generation) return;
      final url = Uri.https(appId, '/player.html', {
        'video': media.youtubeId!,
        'start': '${media.startSeconds}',
        'request': '$generation',
      });
      final android = androidController;
      if (android != null) {
        final parameters = jsonEncode(url.query);
        await android.loadHtmlString(
            playerHtml.replaceFirst('location.search', parameters),
            baseUrl: 'https://$_androidAppId/player.html');
      } else {
        await controller!.loadUrl(url.toString());
      }
      _timeout?.cancel();
      _timeout = Timer(const Duration(seconds: 25), () {
        if (_disposed || generation != _generation || !loading) return;
        loading = false;
        error = 'YouTube не отвечает. Проверьте подключение к интернету.';
        _notify();
      });
    } catch (e) {
      _initializing = null;
      if (!_disposed && generation == _generation) {
        loading = false;
        error = e is _WebViewUnavailable
            ? 'Для YouTube нужен Microsoft Edge WebView2 Runtime.'
            : 'Не удалось запустить YouTube.';
        debugPrint('YouTube initialization: $e');
      }
    } finally {
      if (generation == _generation) _starting = false;
      _notify();
    }
  }

  Future<void> _initialize() async {
    if (Platform.isAndroid) {
      final web = mobile.WebViewController();
      await web.setJavaScriptMode(mobile.JavaScriptMode.unrestricted);
      await web.setBackgroundColor(Colors.black);
      await web.addJavaScriptChannel('OTunePlayer', onMessageReceived: (event) {
        try {
          _message(jsonDecode(event.message));
        } on FormatException {
          return;
        }
      });
      await web.setNavigationDelegate(mobile.NavigationDelegate(
        onNavigationRequest: (request) {
          if (!request.isMainFrame) return mobile.NavigationDecision.navigate;
          final uri = Uri.tryParse(request.url);
          if (request.url == 'about:blank' ||
              (uri?.scheme == 'https' && uri?.host == _androidAppId)) {
            return mobile.NavigationDecision.navigate;
          }
          return mobile.NavigationDecision.prevent;
        },
      ));
      if (!_disposed) androidController = web;
      return;
    }
    if (!Platform.isWindows) {
      throw UnsupportedError(
          'Встроенный YouTube пока доступен в Windows-версии');
    }
    if (await WebviewController.getWebViewVersion() == null) {
      throw const _WebViewUnavailable();
    }
    final support = await getApplicationSupportDirectory();
    final folder = Directory(p.join(support.path, 'youtube_player'));
    await folder.create(recursive: true);
    await File(p.join(folder.path, 'player.html')).writeAsString(playerHtml);
    try {
      await (_environment ??= WebviewController.initializeEnvironment(
          userDataPath: p.join(support.path, 'youtube_webview')));
    } catch (_) {
      _environment = null;
      rethrow;
    }
    if (_disposed) return;
    final web = WebviewController();
    controller = web;
    await web.initialize();
    if (_disposed) {
      await web.dispose();
      return;
    }
    await web.setBackgroundColor(Colors.black);
    await web.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    await web.addVirtualHostNameMapping(
        appId, folder.path, WebviewHostResourceAccessKind.denyCors);
    _messages = web.webMessage.listen(_message, onError: (Object e) {
      if (!_disposed) {
        error = 'Ошибка связи с YouTube.';
        debugPrint('YouTube WebView message: $e');
        _notify();
      }
    });
    _navigation = web.loadingState.listen((state) {
      if (!active || !watchPage || state != LoadingState.navigationCompleted) {
        return;
      }
      loading = false;
      _notify();
    });
    _loadErrors = web.onLoadError.listen((reason) {
      if (!active ||
          !watchPage ||
          reason == WebErrorStatus.WebErrorStatusOperationCanceled) {
        return;
      }
      loading = false;
      error = 'Не удалось открыть страницу YouTube.';
      _notify();
    });
    _notify();
  }

  void _message(dynamic value) {
    if (_disposed ||
        value is! Map ||
        value['video'] != link?.youtubeId ||
        value['request'] != '$_generation' ||
        watchPage ||
        !active) {
      return;
    }
    switch (value['type']) {
      case 'ready':
        loading = false;
        error = null;
        _timeout?.cancel();
        break;
      case 'state':
        playing = value['state'] == 1;
        final name = value['title'];
        if (name is String && name.isNotEmpty) title = name;
        if (playing) {
          loading = false;
          error = null;
          unawaited(audio.pause());
        }
        break;
      case 'played':
        final media = link;
        if (!_recorded && playing && media != null) {
          _recorded = true;
          debugPrint('YouTube embedded playback advanced.');
          onListened?.call(PlaybackTrack(
              path: media.canonicalYoutubeUrl.toString(),
              title: title,
              artist: 'YouTube',
              youtube: true));
        }
        return;
      case 'error':
        loading = false;
        playing = false;
        final code = value['code'] is int ? value['code'] as int : 0;
        debugPrint('YouTube embed error: $code');
        _timeout?.cancel();
        if (requiresWatchPage(code) && Platform.isWindows) {
          unawaited(openWatchPage());
          return;
        }
        error = errorMessage(code);
        break;
      case 'blocked':
        loading = false;
        error = 'Нажмите ▶ внутри видео, чтобы начать воспроизведение.';
        break;
    }
    _notify();
  }

  static bool requiresWatchPage(int code) => code == 101 || code == 150;

  static String errorMessage(int code) => switch (code) {
        100 => 'Видео удалено, скрыто или недоступно.',
        101 || 150 => 'YouTube запретил встраивание этого ролика.',
        153 => 'YouTube не принял идентификатор приложения.',
        5 => 'Встроенный проигрыватель YouTube не смог открыть видео.',
        _ => 'YouTube не смог открыть видео.',
      };

  Future<void> openWatchPage() async {
    final url = link?.canonicalYoutubeUrl;
    if (!Platform.isWindows ||
        !active ||
        !initialized ||
        url == null ||
        watchPage) {
      return;
    }
    final generation = ++_generation;
    _starting = false;
    _timeout?.cancel();
    watchPage = true;
    playing = false;
    loading = true;
    error = null;
    _notify();
    try {
      await controller!.loadUrl(url.toString());
    } catch (e) {
      if (generation != _generation || _disposed) return;
      loading = false;
      error = 'Не удалось открыть страницу YouTube.';
      debugPrint('YouTube watch page: $e');
      _notify();
    }
  }

  Future<void> toggleEmbeddedPlayback() async {
    if (!active || !initialized || watchPage) return;
    await _execute(
        'if(window.player?.getPlayerState?.() === 1) window.player.pauseVideo(); '
        'else window.player?.playVideo?.();');
  }

  Future<void> close() async {
    _generation++;
    _timeout?.cancel();
    active = false;
    playing = false;
    loading = false;
    watchPage = false;
    _notify();
    if (initialized) {
      try {
        final android = androidController;
        if (android != null) {
          await android.loadRequest(Uri.parse('about:blank'));
        } else {
          await controller!.loadUrl('about:blank');
        }
      } catch (e) {
        debugPrint('YouTube pause: $e');
      }
    }
  }

  Future<void> openInBrowser() async {
    final url = link?.canonicalYoutubeUrl;
    if (url == null) return;
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      error = 'Не удалось открыть браузер';
      _notify();
    }
  }

  Future<void> pauseForVisibility() async {
    if (!active || !initialized || watchPage) return;
    try {
      await _execute('if(window.player) window.player.pauseVideo();');
      playing = false;
      _notify();
    } catch (e) {
      debugPrint('YouTube visibility: $e');
    }
  }

  Future<void> _execute(String script) async {
    final android = androidController;
    if (android != null) {
      await android.runJavaScript(script);
    } else {
      await controller!.executeScript(script);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timeout?.cancel();
    audio.removeListener(_audioChanged);
    unawaited(_messages?.cancel());
    unawaited(_navigation?.cancel());
    unawaited(_loadErrors?.cancel());
    final web = controller;
    if (web?.value.isInitialized == true) unawaited(web!.dispose());
    super.dispose();
  }

  static const playerHtml = r'''<!doctype html>
<html lang="ru"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>html,body,#player{margin:0;width:100%;height:100%;background:#000;overflow:hidden}</style></head>
<body><div id="player"></div><script>
const params = new URLSearchParams(location.search);
const video = params.get('video') || '';
const request = params.get('request') || '';
const start = Math.max(0, Math.min(604800, parseInt(params.get('start') || '0', 10) || 0));
function emit(data){
  const message=Object.assign({video:video,request:request},data);
  if(window.chrome && window.chrome.webview) window.chrome.webview.postMessage(message);
  else if(window.OTunePlayer) window.OTunePlayer.postMessage(JSON.stringify(message));
}
window.onYouTubeIframeAPIReady = function(){
  if(!/^[A-Za-z0-9_-]{11}$/.test(video)){ emit({type:'error',code:2}); return; }
  window.player = new YT.Player('player', {
    width:'100%',height:'100%',videoId:video,
    playerVars:{autoplay:1,controls:1,playsinline:1,start:start,origin:location.origin,rel:0},
    events:{onReady:function(){emit({type:'ready'});},
      onStateChange:function(e){
        let name='';try{name=e.target.getVideoData().title||'';}catch(_){}
        emit({type:'state',state:e.data,title:name});
        clearTimeout(window.listenTimer);
        if(e.data===YT.PlayerState.PLAYING){
          const initial=e.target.getCurrentTime();
          window.listenTimer=setTimeout(function(){
            if(e.target.getPlayerState()===YT.PlayerState.PLAYING &&
               e.target.getCurrentTime()>initial+0.5) emit({type:'played'});
          },1600);
        }
      },
      onError:function(e){emit({type:'error',code:e.data});},
      onAutoplayBlocked:function(){emit({type:'blocked'});}}
  });
};
const script=document.createElement('script');script.src='https://www.youtube.com/iframe_api';
script.onerror=function(){emit({type:'error',code:0});};document.head.appendChild(script);
</script></body></html>''';
}

class _WebViewUnavailable implements Exception {
  const _WebViewUnavailable();
}

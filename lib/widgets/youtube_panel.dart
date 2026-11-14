import '../core/localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:webview_flutter/webview_flutter.dart' as mobile;
import '../data/services/youtube_player_service.dart';
import 'player_controls.dart';

class YoutubePanel extends StatelessWidget {
  final bool compact;
  final bool fill;
  const YoutubePanel({super.key, this.compact = false, this.fill = false});
  @override
  Widget build(BuildContext context) {
    final youtube = context.watch<YoutubePlayerService>();
    if (!youtube.active) return const SizedBox.shrink();
    final android = youtube.androidController;
    final viewport = android != null
        ? mobile.WebViewWidget(controller: android)
        : youtube.initialized
            ? Webview(youtube.controller!,
                permissionRequested: (_, __, ___) async =>
                    WebviewPermissionDecision.deny)
            : Center(
                child: youtube.error == null
                    ? const CircularProgressIndicator()
                    : const Icon(Icons.play_disabled, size: 42));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            const Icon(Icons.smart_display, color: Colors.redAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
                    youtube.watchPage
                        ? context.tr('Страница YouTube')
                        : youtube.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
            if (youtube.controller != null &&
                youtube.initialized &&
                !youtube.watchPage &&
                youtube.error != null)
              PlayerControlButton(
                  tooltip: context.tr('Открыть страницу YouTube здесь'),
                  icon: const Icon(Icons.ondemand_video, size: 18),
                  onPressed: youtube.openWatchPage),
            PlayerControlButton(
                tooltip: context.tr('Открыть в браузере'),
                icon: const Icon(Icons.open_in_new, size: 18),
                onPressed: youtube.openInBrowser),
            PlayerControlButton(
                tooltip: context.tr('Закрыть YouTube'),
                icon: const Icon(Icons.close, size: 18),
                onPressed: youtube.close),
          ])),
      if (youtube.error != null)
        Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(context.tr(youtube.error!),
                style: const TextStyle(fontSize: 12, color: Colors.white70))),
      if (youtube.loading) const LinearProgressIndicator(minHeight: 2),
      if (fill)
        Expanded(child: SizedBox(width: double.infinity, child: viewport))
      else
        SizedBox(
            height: compact ? 220 : 270,
            width: double.infinity,
            child: viewport),
    ]);
  }
}

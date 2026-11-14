import '../core/localization.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/models/media_link.dart';
import '../data/models/playback_track.dart';
import '../data/services/audio_player_service.dart';
import '../data/services/offline_tracks.dart';
import '../data/services/youtube_player_service.dart';

class OpenLinkCard extends StatefulWidget {
  const OpenLinkCard({super.key});
  @override
  State<OpenLinkCard> createState() => _OpenLinkCardState();
}

class _OpenLinkCardState extends State<OpenLinkCard> {
  final _input = TextEditingController();
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _open({bool download = false}) async {
    if (_busy) return;
    try {
      final link = MediaLink.parse(_input.text);
      setState(() {
        _busy = true;
        _error = null;
      });
      final audio = context.read<AudioPlayerService>();
      final youtube = context.read<YoutubePlayerService>();
      final fromLink = context.tr('По ссылке');
      if (download && !link.isDownloadableAudio) {
        throw const FormatException(
            'Для загрузки нужна прямая HTTPS-ссылка на аудиофайл.');
      }
      if (link.isYoutube) {
        if (Platform.isAndroid) {
          await audio.pause();
          if (!await launchUrl(link.uri,
              mode: LaunchMode.externalApplication)) {
            throw StateError('Could not open YouTube');
          }
        } else {
          await youtube.open(link);
        }
      } else {
        final path = link.uri.toString();
        final track = PlaybackTrack(
            path: path,
            title: link.uri.pathSegments.last,
            artist: fromLink,
            downloadUrl: link.isDownloadableAudio ? path : null);
        final offline = context.read<OfflineTracks?>();
        if (download && offline != null) {
          await offline.download(track);
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(context.tr('Скачано'))));
          }
        } else {
          await youtube.close();
          await audio.playQueue([offline?.localOrOriginal(track) ?? track]);
        }
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('Open link: $e');
      if (mounted) {
        setState(() => _error = download
            ? 'Не удалось скачать трек.'
            : 'Не удалось открыть ссылку.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.tr('Включить по ссылке'),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
            context.tr(
                'YouTube, Shorts или прямая ссылка на MP3, FLAC, M4A и другие аудиофайлы.'),
            style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 16),
        TextField(
            controller: _input,
            onSubmitted: (_) => _open(),
            maxLines: 1,
            decoration: InputDecoration(
                hintText: context.tr('Вставьте ссылку на трек…'),
                prefixIcon: const Icon(Icons.link),
                errorText: _error == null ? null : context.tr(_error!))),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
              onPressed: _busy ? null : _open,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow),
              label: Text(_busy
                  ? context.tr('Открываем…')
                  : context.tr('Воспроизвести ссылку'))),
          if (Platform.isAndroid)
            OutlinedButton.icon(
                onPressed: _busy ? null : () => _open(download: true),
                icon: const Icon(Icons.download_outlined),
                label: Text(context.tr('Скачать'))),
        ]),
      ]);
}

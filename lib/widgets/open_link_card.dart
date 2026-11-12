import '../core/localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/models/media_link.dart';
import '../data/services/audio_player_service.dart';
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

  Future<void> _open() async {
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
      if (link.isYoutube) {
        await youtube.open(link);
      } else {
        await youtube.close();
        await audio.playUrl(link.uri.toString(),
            title: link.uri.pathSegments.last, artist: fromLink);
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('Open link: $e');
      if (mounted) {
        setState(() => _error = 'Не удалось открыть ссылку.');
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
      ]);
}

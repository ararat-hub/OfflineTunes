import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/localization.dart';
import '../data/db/app_database.dart';
import '../data/models/media_link.dart';
import '../data/models/playback_track.dart';
import '../data/services/audio_player_service.dart';
import '../data/services/catalog_playback.dart';
import '../data/services/favorite_tracks.dart';
import '../data/services/offline_tracks.dart';
import '../data/services/scanner_service.dart';
import '../data/services/track_artwork_store.dart';
import '../data/services/youtube_player_service.dart';

Future<void> playHistoryTrack(BuildContext context, List<PlaybackTrack> tracks,
    PlaybackTrack selected) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final playback = context.read<CatalogPlayback?>();
  if (CatalogPlayback.needsAudioLookup(selected)) {
    final result = await playback?.play(selected);
    if (context.mounted &&
        (result == null || result == CatalogPlaybackResult.unavailable)) {
      final import = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
                title: Text(selected.title),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TrackArtwork(track: selected, size: 96),
                  const SizedBox(height: 16),
                  Text(context.tr(
                      'Для этой записи доступна карточка каталога. Добавьте аудиофайл, чтобы слушать её в oTune.')),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: Text(context.tr('Закрыть'))),
                  FilledButton.icon(
                      onPressed: () => Navigator.pop(dialog, true),
                      icon: const Icon(Icons.audio_file_outlined),
                      label: Text(context.tr('Выбрать аудиофайл'))),
                ],
              ));
      if (import == true && context.mounted) {
        await _importRecording(context, selected);
      }
    }
  } else if (selected.youtube) {
    playback?.cancel();
    await context
        .read<YoutubePlayerService>()
        .open(MediaLink.parse(selected.path), recording: selected);
  } else {
    playback?.cancel();
    final originals = tracks
        .where((track) => !track.youtube && track.externalProvider == null)
        .toList();
    final saved = context.read<OfflineTracks?>();
    final audio = originals
        .map((track) => saved?.localOrOriginal(track) ?? track)
        .toList();
    context
        .read<AudioPlayerService>()
        .playQueue(audio, index: originals.indexOf(selected));
  }
}

Future<void> playAudioTracks(BuildContext context, List<PlaybackTrack> tracks,
    PlaybackTrack selected) async {
  if (!CatalogPlayback.canPlayInApp(selected)) return;
  FocusManager.instance.primaryFocus?.unfocus();
  context.read<CatalogPlayback?>()?.cancel();
  final audio = context.read<AudioPlayerService>();
  final saved = context.read<OfflineTracks?>();
  final queue = tracks.where(CatalogPlayback.canPlayInApp).toList();
  await audio.playQueue(
    queue.map((track) => saved?.localOrOriginal(track) ?? track).toList(),
    index: queue.indexOf(selected),
  );
}

Future<void> _importRecording(
    BuildContext context, PlaybackTrack recording) async {
  if (!context.mounted) return;
  final scanner = ScannerService(context.read<AppDatabase>());
  final audio = context.read<AudioPlayerService>();
  try {
    final file =
        await openFile(acceptedTypeGroups: ScannerService.audioFileTypes);
    if (file == null || !context.mounted) return;
    final path = await scanner.importPickedAudio(file, recording: recording);
    if (path == null) throw const FormatException('Unsupported audio file');
    if (context.mounted) {
      await audio.playQueue([
        PlaybackTrack(
          path: path,
          title: recording.title,
          artist: recording.artist,
          libraryId: path,
          artwork: recording.artwork,
          artworkAlternatives: recording.artworkAlternatives,
        ),
      ]);
    }
  } catch (error) {
    debugPrint('Import recording: $error');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr('Не удалось добавить аудиофайл.'))));
    }
  }
}

class TrackRow extends StatelessWidget {
  const TrackRow(
      {super.key,
      required this.track,
      required this.onPlay,
      this.duration,
      this.playCount,
      this.rank,
      this.trailing});

  final PlaybackTrack track;
  final VoidCallback onPlay;
  final Duration? duration;
  final int? playCount;
  final int? rank;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final time = duration?.inSeconds;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final selected = context.select<AudioPlayerService?, bool>(
        (audio) => audio?.currentTrack?.identity == track.identity);
    final metadata = [
      if (track.artist.isNotEmpty) track.artist,
      if (time != null && rank == null)
        '${time ~/ 60}:${(time % 60).toString().padLeft(2, '0')}',
      if (track.externalProvider != null) track.externalProvider!,
      if (playCount != null && wide)
        context.tr('Прослушиваний: {count}', {
          'count': NumberFormat.decimalPattern(
                  Localizations.localeOf(context).languageCode)
              .format(playCount),
        }),
    ];
    return ListTile(
      selected: selected,
      selectedTileColor:
          Theme.of(context).colorScheme.primary.withValues(alpha: .08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      minVerticalPadding: 10,
      horizontalTitleGap: rank == null ? null : 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: rank == null
          ? TrackArtwork(track: track)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                    width: 23,
                    child: Text('$rank',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium)),
                const SizedBox(width: 8),
                TrackArtwork(track: track),
              ],
            ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: metadata.isEmpty
          ? null
          : Text(metadata.join(' · '),
              maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: trailing ??
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (time != null && wide && rank != null)
              Text('${time ~/ 60}:${(time % 60).toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.labelMedium),
            if (CatalogPlayback.needsAudioLookup(track))
              _CatalogTrackButton(track: track, onPlay: onPlay)
            else
              _TrackPlayButton(track: track, onPlay: onPlay),
            TrackActions(track: track, duration: duration),
          ]),
      onTap: onPlay,
    );
  }
}

class _CatalogTrackButton extends StatelessWidget {
  const _CatalogTrackButton({required this.track, required this.onPlay});
  final PlaybackTrack track;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final pending = context.select<CatalogPlayback?, bool>(
        (service) => service?.pending == track.identity);
    return IconButton(
      tooltip: context.tr('Найти полную запись'),
      onPressed: pending ? null : onPlay,
      icon: pending
          ? const SizedBox.square(
              dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.audio_file_outlined, size: 21),
    );
  }
}

class _TrackPlayButton extends StatelessWidget {
  const _TrackPlayButton({required this.track, required this.onPlay});
  final PlaybackTrack track;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final preferredPath = context.select<OfflineTracks?, String>(
        (offline) => offline?.localOrOriginal(track).path ?? track.path);
    final state = context
        .select<AudioPlayerService?, (bool, bool, bool, String?)>((audio) => (
              audio?.currentTrack?.identity == track.identity,
              audio?.isPlaying ?? false,
              audio?.isLoading ?? false,
              audio?.currentPath,
            ));
    final loading = state.$1 && state.$3;
    final playing = state.$1 && state.$2;
    return IconButton(
        tooltip: context.tr(playing ? 'Пауза' : 'Воспроизвести'),
        onPressed: loading
            ? null
            : playing || (state.$1 && state.$4 == preferredPath)
                ? context.read<AudioPlayerService>().togglePlayPause
                : onPlay,
        icon: loading
            ? const SizedBox.square(
                dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded));
  }
}

class TrackArtwork extends StatefulWidget {
  const TrackArtwork({super.key, this.track, this.size = 42});
  final PlaybackTrack? track;
  final double size;

  @override
  State<TrackArtwork> createState() => _TrackArtworkState();
}

class _TrackArtworkState extends State<TrackArtwork> {
  late var _file =
      widget.track == null ? null : TrackArtworkStore.resolve(widget.track!);

  @override
  void didUpdateWidget(covariant TrackArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.track;
    final next = widget.track;
    if (before?.path != next?.path ||
        before?.artwork != next?.artwork ||
        !listEquals(before?.artworkAlternatives, next?.artworkAlternatives)) {
      _file = next == null ? null : TrackArtworkStore.resolve(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final colors = Theme.of(context).colorScheme;
    final name = widget.track?.title ?? '';
    final tint = Color(0xFF000000 |
        (name.codeUnits
            .fold<int>(0, (value, code) => (value * 31 + code) & 0xffffff)));
    final coverColor = HSLColor.fromColor(tint)
        .withSaturation(.22)
        .withLightness(.24)
        .toColor();
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              name.isEmpty ? colors.primaryContainer : coverColor,
              colors.surfaceContainerHighest
            ]),
        color: colors.surfaceContainerHighest,
      ),
      child: Center(
          child: name.isNotEmpty
              ? Text(String.fromCharCode(name.runes.first).toUpperCase(),
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: size * .40,
                      fontWeight: FontWeight.w500))
              : Icon(
                  widget.track?.youtube == true
                      ? Icons.smart_display_outlined
                      : Platform.isAndroid
                          ? Icons.graphic_eq_rounded
                          : Icons.music_note_rounded,
                  color: colors.onPrimaryContainer,
                  size: size * .48)),
    );
    return ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: SizedBox.square(
          dimension: size,
          child: _file == null
              ? fallback
              : FutureBuilder(
                  future: _file,
                  builder: (context, snapshot) {
                    final file = snapshot.data;
                    if (file == null ||
                        snapshot.connectionState != ConnectionState.done) {
                      return fallback;
                    }
                    return Image.file(file,
                        fit: BoxFit.cover,
                        cacheWidth: size < 100 ? 128 : null,
                        errorBuilder: (_, __, ___) => fallback);
                  }),
        ));
  }
}

class FavoriteTrackButton extends StatelessWidget {
  const FavoriteTrackButton({super.key, required this.track});
  final PlaybackTrack track;

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoriteTracks?>();
    if (favorites == null) return const SizedBox.shrink();
    final selected = favorites.contains(track);
    return IconButton(
      tooltip: context.tr(selected ? 'Убрать из избранного' : 'В избранное'),
      color: selected ? Theme.of(context).colorScheme.primary : null,
      icon: Icon(
          selected ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 20),
      onPressed: () async {
        try {
          await favorites.toggle(track);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(context.tr('Не удалось сохранить настройки.'))));
          }
        }
      },
    );
  }
}

class TrackActions extends StatelessWidget {
  const TrackActions({super.key, required this.track, this.duration});
  final PlaybackTrack track;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final offline = context.watch<OfflineTracks?>();
    final favorites = context.watch<FavoriteTracks?>();
    final identity = track.identity;
    final downloaded = offline?.contains(identity) == true;
    final downloading = offline?.isLoading(identity) == true;
    final favorite = favorites?.contains(track) == true;

    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (offline != null && track.downloadUrl != null)
        IconButton(
          tooltip: context.tr(downloading
              ? 'Скачивание'
              : downloaded
                  ? 'Скачано'
                  : 'Скачать'),
          visualDensity: VisualDensity.compact,
          onPressed: downloading || downloaded
              ? null
              : () => _download(context, offline),
          icon: downloading
              ? SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, value: offline.progress(identity)))
              : Icon(
                  downloaded
                      ? Icons.download_done_rounded
                      : Icons.download_outlined,
                  size: 21),
        ),
      PopupMenuButton<String>(
          tooltip: context.tr('О треке'),
          icon: const Icon(Icons.more_horiz_rounded, size: 21),
          itemBuilder: (_) => [
                if (favorites != null)
                  PopupMenuItem(
                      value: 'favorite',
                      child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(favorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded),
                          title: Text(context.tr(favorite
                              ? 'Убрать из избранного'
                              : 'В избранное')))),
                PopupMenuItem(
                    value: 'info',
                    child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.info_outline_rounded),
                        title: Text(context.tr('О треке')))),
              ],
          onSelected: (action) async {
            try {
              if (action == 'favorite') await favorites?.toggle(track);
              if (action == 'info' && context.mounted) _details(context);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content:
                        Text(context.tr('Не удалось сохранить настройки.'))));
              }
            }
          }),
    ]);
  }

  Future<void> _download(BuildContext context, OfflineTracks offline) async {
    var message = 'Скачано';
    try {
      await offline.download(track);
    } catch (_) {
      message = 'Не удалось скачать трек.';
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr(message))));
    }
  }

  void _details(BuildContext context) => showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
            title: Text(track.title),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TrackArtwork(track: track, size: 128),
                  const SizedBox(height: 16),
                  if (track.artist.isNotEmpty) Text(track.artist),
                  if (duration != null)
                    Text(
                        '${duration!.inMinutes}:${(duration!.inSeconds % 60).toString().padLeft(2, '0')}'),
                  if (track.license != null) Text(track.license!),
                  if (track.sourcePage != null)
                    TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                              ClipboardData(text: track.sourcePage!));
                          if (dialog.mounted) {
                            ScaffoldMessenger.of(dialog).showSnackBar(SnackBar(
                                content:
                                    Text(dialog.tr('Ссылка скопирована'))));
                          }
                        },
                        icon: const Icon(Icons.copy_rounded),
                        label:
                            Text(context.tr('Скопировать ссылку на источник'))),
                ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialog),
                  child: Text(context.tr('Закрыть'))),
            ],
          ));
}

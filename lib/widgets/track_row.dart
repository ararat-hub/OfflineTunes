import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/localization.dart';
import '../data/db/app_database.dart';
import '../data/models/playback_track.dart';
import '../data/models/media_link.dart';
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(context.tr('Полный поток этой записи недоступен.')),
          action: SnackBarAction(
              label: context.tr('Выбрать аудиофайл'),
              onPressed: () => _importRecording(context, selected)),
        ));
    }
  } else if (selected.youtube) {
    playback?.cancel();
    context
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

Future<void> openTrackSource(BuildContext context, PlaybackTrack track) async {
  final url = Uri.tryParse(track.sourcePage ?? '');
  if (url != null &&
      url.scheme == 'https' &&
      await launchUrl(url, mode: LaunchMode.externalApplication)) {
    return;
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Не удалось открыть ссылку.'))));
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
    final narrowChart = rank != null && MediaQuery.sizeOf(context).width < 560;
    final metadata = [
      if (track.artist.isNotEmpty) track.artist,
      if (time != null && rank == null)
        '${time ~/ 60}:${(time % 60).toString().padLeft(2, '0')}',
      if (track.license != null) track.license!,
      if (track.externalProvider != null) track.externalProvider!,
      if (playCount != null)
        context.tr('Прослушиваний: {count}', {
          'count': NumberFormat.decimalPattern(
                  Localizations.localeOf(context).languageCode)
              .format(playCount),
        }),
    ];
    return ListTile(
      horizontalTitleGap: rank == null ? null : 12,
      contentPadding:
          rank == null ? null : const EdgeInsets.symmetric(horizontal: 4),
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
          (CatalogPlayback.needsAudioLookup(track)
              ? _CatalogTrackButton(track: track, onPlay: onPlay)
              : rank == null
                  ? TrackActions(track: track, duration: duration)
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      if (time != null)
                        Text(
                            '${time ~/ 60}:${(time % 60).toString().padLeft(2, '0')}',
                            style: Theme.of(context).textTheme.labelMedium),
                      if (!narrowChart) FavoriteTrackButton(track: track),
                      IconButton(
                        icon: const Icon(Icons.more_horiz),
                        tooltip: context.tr('О треке'),
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          builder: (sheet) => SafeArea(
                              child: ListTile(
                            leading: TrackArtwork(track: track),
                            title: Text(track.title),
                            subtitle: Text(track.artist),
                            trailing:
                                TrackActions(track: track, duration: duration),
                          )),
                        ),
                      ),
                    ])),
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
      tooltip: context.tr('Воспроизвести'),
      onPressed: pending ? null : onPlay,
      icon: pending
          ? const SizedBox.square(
              dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.play_arrow_rounded, size: 22),
    );
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
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: Platform.isAndroid
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                    colors.primaryContainer,
                    colors.surfaceContainerHighest
                  ])
            : null,
        color: colors.surfaceContainerHighest,
      ),
      child: Center(
          child: Icon(
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
    final path = track.path;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (offline != null &&
          track.downloadUrl != null &&
          (Uri.tryParse(path)?.scheme == 'https'))
        if (offline.isLoading(path))
          SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: offline.progress(path),
                  semanticsLabel: context.tr('Скачивание')))
        else
          IconButton(
              tooltip:
                  context.tr(offline.contains(path) ? 'Скачано' : 'Скачать'),
              icon: Icon(
                  offline.contains(path)
                      ? Icons.download_done_rounded
                      : Icons.download_outlined,
                  size: 21),
              onPressed: offline.contains(path)
                  ? null
                  : () async {
                      try {
                        await offline.download(track);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  context.tr('Не удалось скачать трек.'))));
                        }
                      }
                    }),
      FavoriteTrackButton(track: track),
      IconButton(
          tooltip: context.tr('О треке'),
          icon: const Icon(Icons.info_outline_rounded, size: 19),
          onPressed: () => showDialog<void>(
              context: context,
              builder: (dialog) => AlertDialog(
                    title: Text(track.title),
                    content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TrackArtwork(track: track, size: 104),
                          const SizedBox(height: 12),
                          if (track.artist.isNotEmpty) Text(track.artist),
                          if (duration != null)
                            Text(
                                '${duration!.inMinutes}:${(duration!.inSeconds % 60).toString().padLeft(2, '0')}'),
                          if (track.license != null) Text(track.license!),
                          if (track.sourcePage != null)
                            TextButton.icon(
                                onPressed: () =>
                                    openTrackSource(context, track),
                                icon: const Icon(Icons.open_in_new),
                                label: Text(context.tr('Источник записи'))),
                        ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialog),
                          child: Text(context.tr('Закрыть')))
                    ],
                  ))),
    ]);
  }
}

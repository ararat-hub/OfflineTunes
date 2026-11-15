import '../../core/localization.dart';
import '../../core/strings.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../../data/db/app_database.dart';
import '../../data/models/media_link.dart';
import '../../data/services/app_preferences.dart';
import '../../data/services/audio_player_service.dart';
import '../../data/services/desktop_window_service.dart';
import '../../data/services/update_service.dart';
import '../../data/services/youtube_player_service.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/appearance_editor.dart' show ProfileAvatar;
import '../../widgets/mobile_icon_button.dart';
import '../../widgets/mini_player.dart';
import '../../widgets/player_controls.dart';
import '../../widgets/player_clock.dart';
import '../../widgets/track_row.dart';
import '../../widgets/youtube_panel.dart';
import '../../widgets/update_controls.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../profile/profile_screen.dart';
import '../favorites/favorites_screen.dart';
import '../add_music/add_music_screen.dart';
import '../library/library_screen.dart';
import '../discover/discover_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppDatabase db;
  final MediaLink? initialLink;
  const HomeScreen({super.key, required this.db, this.initialLink});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _compactChannel = MethodChannel('otune/compact_window');
  AudioPlayerService? _compactAudio;
  YoutubePlayerService? _compactYoutube;
  bool _mobileCompact = false;
  bool? _autoCompact;
  int _selectedIndex = 0;
  StreamSubscription<HotkeyAction>? _hotkeys;
  Timer? _updateTimer;
  bool _checkingUpdates = false;
  double _volumeBeforeMute = 1;
  static const _titles = [
    'Главная',
    'Поиск',
    'Медиатека',
    'Избранное',
    'Добавить музыку',
    'Настройки',
    'Ваш профиль',
    'Рекомендации',
  ];
  static const _navigation = [
    (0, Icons.home_outlined, Icons.home, 'Главная'),
    (1, Icons.search, Icons.search, 'Поиск'),
    (2, Icons.library_music_outlined, Icons.library_music, 'Медиатека'),
    (3, Icons.favorite_border, Icons.favorite, 'Избранное'),
    (7, Icons.explore_outlined, Icons.explore, 'Подборки'),
    (4, Icons.add_circle_outline, Icons.add_circle, 'Добавить'),
    (5, Icons.settings_outlined, Icons.settings, 'Настройки'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isAndroid) {
      _compactAudio = context.read<AudioPlayerService>()
        ..addListener(_syncCompact);
      _compactYoutube = context.read<YoutubePlayerService>()
        ..addListener(_syncCompact);
      _compactChannel.setMethodCallHandler((call) async {
        if (call.method == 'changed') _setMobileCompact(call.arguments == true);
      });
      unawaited(_readMobileCompact());
      _syncCompact();
    }
    _updateTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_checkUpdates());
      }
    });
    final link = widget.initialLink;
    if (link != null) _selectedIndex = 4;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (link?.isYoutube == true) {
        unawaited(context.read<YoutubePlayerService>().open(link!));
      } else if (link != null) {
        unawaited(context
            .read<AudioPlayerService>()
            .playUrl(link.uri.toString(), title: link.uri.pathSegments.last));
      }
      unawaited(_checkUpdates());
    });
  }

  Future<void> _checkUpdates() async {
    if (_checkingUpdates) return;
    _checkingUpdates = true;
    try {
      final update = await context.read<UpdateService?>()?.check();
      if (mounted &&
          update != null &&
          !context.read<DesktopWindowService>().compact) {
        await showUpdate(context, update);
      }
    } catch (error) {
      debugPrint('Check for updates: $error');
    } finally {
      _checkingUpdates = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_checkUpdates());
    if (Platform.isAndroid && state == AppLifecycleState.paused) {
      unawaited(context.read<YoutubePlayerService>().pauseForVisibility());
    }
  }

  void _navigate(int index) => setState(() => _selectedIndex = index);
  Future<void> _editFromWidget() async {
    await context.read<DesktopWindowService>().restore();
    if (mounted) _navigate(5);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _hotkeys ??= context.read<AppPreferences?>()?.pressed.listen(_hotkey);
  }

  Future<void> _hotkey(HotkeyAction action) async {
    if (!mounted) return;
    final window = context.read<DesktopWindowService>();
    final youtube = context.read<YoutubePlayerService>();
    final audio = context.read<AudioPlayerService>();
    final theme = context.read<ThemeProvider>();
    try {
      if (action == HotkeyAction.widget) {
        if (await windowManager.isMinimized()) await windowManager.restore();
        if (window.compact) {
          await window.restore();
        } else {
          await window.enterWidget(theme, youtube: youtube.active);
        }
      } else if (youtube.active) {
        if (action == HotkeyAction.playPause) {
          await youtube.toggleEmbeddedPlayback();
        }
      } else {
        switch (action) {
          case HotkeyAction.playPause:
            await audio.togglePlayPause();
          case HotkeyAction.next:
            await audio.next();
          case HotkeyAction.previous:
            await audio.previous();
          case HotkeyAction.mute:
            if (audio.volume > 0) {
              _volumeBeforeMute = audio.volume;
              await audio.setVolume(0);
            } else {
              await audio.setVolume(_volumeBeforeMute);
            }
          case HotkeyAction.widget:
            break;
        }
      }
    } catch (e) {
      debugPrint('Hotkey ${action.name}: $e');
    }
  }

  @override
  void dispose() {
    _compactAudio?.removeListener(_syncCompact);
    _compactYoutube?.removeListener(_syncCompact);
    if (Platform.isAndroid) _compactChannel.setMethodCallHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    _updateTimer?.cancel();
    unawaited(_hotkeys?.cancel());
    super.dispose();
  }

  void _syncCompact() {
    final enabled = _compactAudio!.isPlaying && !_compactYoutube!.active;
    if (_autoCompact == enabled) return;
    _autoCompact = enabled;
    unawaited(_configureMobileCompact(enabled));
  }

  Future<void> _configureMobileCompact(bool enabled) async {
    try {
      await _compactChannel.invokeMethod<void>('configure', enabled);
    } on PlatformException catch (error) {
      debugPrint('Android compact window: $error');
    }
  }

  Future<void> _readMobileCompact() async {
    try {
      _setMobileCompact(
          await _compactChannel.invokeMethod<bool>('state') == true);
    } on PlatformException catch (error) {
      debugPrint('Android compact window: $error');
    }
  }

  void _setMobileCompact(bool compact) {
    if (mounted && _mobileCompact != compact) {
      setState(() => _mobileCompact = compact);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final window = context.watch<DesktopWindowService>();
    final youtube = context.watch<YoutubePlayerService>();
    final compact = window.compact || _mobileCompact;
    final fullWatchPage = youtube.watchPage && _selectedIndex == 4;
    final navigationIndex =
        _navigation.indexWhere((item) => item.$1 == _selectedIndex);
    final pages = [
      _Dashboard(onNavigate: _navigate),
      SearchScreen(db: widget.db),
      const LibraryScreen(),
      const FavoritesScreen(),
      const AddMusicScreen(),
      const SettingsScreen(),
      ProfileScreen(onSettings: () => _navigate(5)),
      DiscoverScreen(db: widget.db),
    ];
    return Scaffold(
        backgroundColor: Colors.transparent,
        body: ClipRRect(
          borderRadius:
              BorderRadius.circular(window.compact ? theme.widgetRadius : 0),
          child: Stack(fit: StackFit.expand, children: [
            AppBackdrop(
                theme: theme,
                compact: compact,
                visibleInBackground: _mobileCompact),
            if (window.compact)
              DragToResizeArea(child: _FloatingPlayer(onEdit: _editFromWidget))
            else if (_mobileCompact)
              const _AndroidCompactPlayer()
            else if (Platform.isAndroid)
              Positioned.fill(
                  child: SafeArea(
                      child: Column(children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                    child: Row(children: [
                      Image.asset('assets/images/otune-icon.png',
                          width: 34, height: 34),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(context.tr(_titles[_selectedIndex]),
                              style: Theme.of(context).textTheme.titleLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                      MobileIconButton(
                          label: context.tr('Добавить музыку'),
                          onPressed: () {
                            if (youtube.active) unawaited(youtube.close());
                            _navigate(4);
                          },
                          icon: const Icon(Icons.add_rounded)),
                      MobileIconButton(
                          label: context.tr('Мой профиль'),
                          onPressed: () {
                            if (youtube.active) unawaited(youtube.close());
                            _navigate(6);
                          },
                          icon:
                              ProfileAvatar(path: theme.avatarPath, size: 30)),
                    ])),
                Expanded(
                    child: youtube.active
                        ? const YoutubePanel(fill: true)
                        : pages[_selectedIndex]),
                if (!youtube.active)
                  _MobilePlayerBar(
                      audio: context.read<AudioPlayerService>(),
                      opacity: theme.panelOpacity),
                NavigationBar(
                  height: 62,
                  backgroundColor: Colors.black.withValues(alpha: .68),
                  indicatorColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  indicatorShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  animationDuration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 210),
                  selectedIndex: [0, 1, 2, 7].contains(_selectedIndex)
                      ? [0, 1, 2, 7].indexOf(_selectedIndex)
                      : 2,
                  onDestinationSelected: (index) {
                    if (youtube.active) unawaited(youtube.close());
                    _navigate([0, 1, 2, 7][index]);
                  },
                  destinations: [
                    for (final item in _navigation
                        .where((item) => [0, 1, 2, 7].contains(item.$1)))
                      NavigationDestination(
                          icon: Icon(
                              switch (item.$1) {
                                0 => Icons.grid_view_rounded,
                                1 => Icons.search_rounded,
                                2 => Icons.library_music_outlined,
                                _ => Icons.explore_outlined,
                              },
                              size: 22),
                          selectedIcon: Icon(
                              switch (item.$1) {
                                0 => Icons.dashboard_rounded,
                                1 => Icons.manage_search_rounded,
                                2 => Icons.library_music_rounded,
                                _ => Icons.explore_rounded,
                              },
                              size: 23),
                          label: context.tr(item.$4)),
                  ],
                ),
              ])))
            else
              Row(children: [
                Container(
                    width: 152,
                    decoration: BoxDecoration(
                        color:
                            Colors.black.withValues(alpha: theme.panelOpacity),
                        border: const Border(
                            right: BorderSide(color: Colors.white12))),
                    child: Column(children: [
                      const SizedBox(height: 14),
                      Expanded(
                          child: SingleChildScrollView(
                              child: IntrinsicHeight(
                                  child: NavigationRail(
                        backgroundColor: Colors.transparent,
                        selectedIndex:
                            navigationIndex < 0 ? null : navigationIndex,
                        extended: true,
                        minExtendedWidth: 150,
                        groupAlignment: -1,
                        onDestinationSelected: (index) =>
                            _navigate(_navigation[index].$1),
                        destinations: [
                          for (final destination in _navigation)
                            NavigationRailDestination(
                              icon: Icon(destination.$2),
                              selectedIcon: Icon(destination.$3),
                              label: Text(context.tr(destination.$4),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11)),
                            ),
                        ],
                      )))),
                      PlayerControlButton(
                          tooltip: context.tr('Плавающий виджет'),
                          icon:
                              const Icon(Icons.picture_in_picture_alt_outlined),
                          onPressed: window.busy
                              ? null
                              : () => window.enterWidget(theme,
                                  youtube: youtube.active)),
                      TextButton.icon(
                          onPressed: () => _navigate(6),
                          icon: ProfileAvatar(path: theme.avatarPath, size: 30),
                          label: Text(context.tr('Профиль'))),
                      const SizedBox(height: 12),
                    ])),
                Expanded(
                    child: Column(children: [
                  Container(
                      padding: const EdgeInsets.fromLTRB(24, 14, 16, 14),
                      child: Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(context.tr(_titles[_selectedIndex]),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 17)),
                              Text(
                                  theme.profileName ==
                                          ThemeProvider.defaultProfileName
                                      ? context.tr(theme.profileName)
                                      : theme.profileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 12)),
                            ])),
                        PlayerControlButton(
                            tooltip: context.tr('Открыть ссылку'),
                            icon: const Icon(Icons.link),
                            onPressed: () {
                              if (youtube.watchPage) unawaited(youtube.close());
                              _navigate(4);
                            }),
                        PlayerControlButton(
                            tooltip: context.tr('Открыть плавающий виджет'),
                            icon: const Icon(
                                Icons.picture_in_picture_alt_outlined),
                            onPressed: window.busy
                                ? null
                                : () => window.enterWidget(theme,
                                    youtube: youtube.active)),
                      ])),
                  if (window.error != null)
                    Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(context.tr(window.error!),
                            style: const TextStyle(color: Colors.redAccent))),
                  if (youtube.active)
                    Flexible(
                        flex: fullWatchPage ? 1 : 2,
                        fit: fullWatchPage ? FlexFit.tight : FlexFit.loose,
                        child: YoutubePanel(fill: fullWatchPage)),
                  if (!fullWatchPage) Expanded(child: pages[_selectedIndex]),
                  if (!youtube.active)
                    MiniPlayer(
                        playerService: context.read<AudioPlayerService>(),
                        opacity: theme.panelOpacity),
                ])),
              ]),
          ]),
        ));
  }
}

class _FloatingPlayer extends StatelessWidget {
  final VoidCallback onEdit;
  const _FloatingPlayer({required this.onEdit});
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final window = context.watch<DesktopWindowService>();
    final youtube = context.watch<YoutubePlayerService>();
    final opacity = theme.widgetStyle == WidgetStyle.solid
        ? .85
        : theme.widgetStyle == WidgetStyle.minimal
            ? 0.0
            : theme.panelOpacity;
    return Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(theme.widgetRadius),
            border: Border.all(color: Colors.white24)),
        child: Column(children: [
          Container(
              color: Colors.black.withValues(alpha: opacity),
              padding: const EdgeInsets.only(left: 14, right: 4),
              child: Row(children: [
                Expanded(
                    child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (_) => window.drag(),
                        child: const SizedBox(
                            height: 48,
                            child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(AppStrings.appName,
                                    style: TextStyle(
                                        letterSpacing: 1.8,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600)))))),
                PlayerControlButton(
                    tooltip: context.tr('Закрепить поверх окон'),
                    icon: Icon(
                        theme.widgetOnTop
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        size: 17),
                    onPressed: () async {
                      await theme.change({'widgetOnTop': !theme.widgetOnTop});
                      await window.setPinned(theme.widgetOnTop);
                    }),
                PlayerControlButton(
                    tooltip: context.tr('Настроить виджет'),
                    icon: const Icon(Icons.tune, size: 18),
                    onPressed: onEdit),
                PlayerControlButton(
                    tooltip: context.tr('Развернуть плеер'),
                    icon: const Icon(Icons.open_in_full, size: 17),
                    onPressed: window.busy ? null : window.restore),
                PlayerControlButton(
                    tooltip: context.tr('Свернуть в панель задач'),
                    icon: const Icon(Icons.remove, size: 18),
                    onPressed: window.minimize),
              ])),
          if (youtube.active)
            const Expanded(child: YoutubePanel(compact: true, fill: true))
          else ...[
            Expanded(
                child: LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxHeight < (theme.widgetClock ? 100 : 64)
                            ? const SizedBox.shrink()
                            : Center(
                                child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (theme.widgetClock)
                                            const PlayerClock(compact: true),
                                          Icon(Icons.graphic_eq,
                                              color: theme.accent
                                                  .withValues(alpha: .8),
                                              size: 40),
                                        ]))))),
            MiniPlayer(
                playerService: context.read<AudioPlayerService>(),
                compact: true,
                showArtist: theme.widgetArtist,
                showProgress: theme.widgetProgress,
                opacity: opacity),
          ],
        ]));
  }
}

class _AndroidCompactPlayer extends StatelessWidget {
  const _AndroidCompactPlayer();

  @override
  Widget build(BuildContext context) {
    return Selector<AudioPlayerService, (String, String, bool)>(
      selector: (_, audio) =>
          (audio.currentTitle, audio.currentArtist, audio.isPlaying),
      builder: (context, track, _) => Align(
        alignment: Alignment.bottomCenter,
        child: ColoredBox(
          color: Colors.black54,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              Expanded(
                  child: Text(
                track.$2.isEmpty ? track.$1 : '${track.$1} · ${track.$2}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              )),
              Icon(track.$3 ? Icons.pause : Icons.play_arrow,
                  size: 15, color: Colors.white),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MobilePlayerBar extends StatelessWidget {
  const _MobilePlayerBar({required this.audio, required this.opacity});
  final AudioPlayerService audio;
  final double opacity;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: audio,
      builder: (context, _) {
        final track = audio.currentTrack;
        if (track == null) return const SizedBox.shrink();
        return Material(
            color: Colors.black.withValues(alpha: opacity.clamp(.48, .85)),
            child: ListTile(
              leading: TrackArtwork(track: track, size: 38),
              title: Text(track.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(track.artist,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                FavoriteTrackButton(track: track),
                MobileIconButton(
                    emphasized: true,
                    label:
                        context.tr(audio.isPlaying ? 'Пауза' : 'Воспроизвести'),
                    icon: AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 150),
                      child: Icon(
                          audio.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          key: ValueKey(audio.isPlaying)),
                    ),
                    onPressed: audio.togglePlayPause),
              ]),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                        appBar:
                            AppBar(title: Text(context.tr('Сейчас играет'))),
                        body: SafeArea(
                            child: Center(
                                child: ListenableBuilder(
                                    listenable: audio,
                                    builder: (context, _) {
                                      final current = audio.currentTrack;
                                      return SingleChildScrollView(
                                          child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                            TrackArtwork(
                                                track: current,
                                                size:
                                                    (MediaQuery.sizeOf(context)
                                                                .width -
                                                            48)
                                                        .clamp(120, 320)),
                                            const SizedBox(height: 16),
                                            MiniPlayer(
                                                playerService: audio,
                                                compact: true,
                                                opacity: 0),
                                            if (current != null)
                                              TrackActions(
                                                  track: current,
                                                  duration: audio.duration),
                                          ]));
                                    }))),
                      ))),
            ));
      });
}

class _Dashboard extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const _Dashboard({required this.onNavigate});
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return ListView(
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final greeting =
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('ВАША МУЗЫКА. ВАШ РИТМ.'),
                  style: TextStyle(
                      fontSize: 11, letterSpacing: 2.5, color: theme.accent)),
              const SizedBox(height: 16),
              Text(
                  theme.profileName == ThemeProvider.defaultProfileName
                      ? context.tr(theme.profileName)
                      : theme.profileName,
                  style: const TextStyle(
                      fontSize: 36, fontWeight: FontWeight.w700),
                  maxLines: 2),
              const SizedBox(height: 8),
              Text(
                  theme.profileBio == ThemeProvider.defaultProfileBio
                      ? context.tr(theme.profileBio)
                      : theme.profileBio,
                  style: const TextStyle(color: Colors.white70, fontSize: 15)),
            ]);
            if (constraints.maxWidth < 600) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    greeting,
                    if (theme.showClock)
                      const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: PlayerClock())
                  ]);
            }
            return Row(children: [
              Expanded(child: greeting),
              if (theme.showClock) const PlayerClock()
            ]);
          }),
          const SizedBox(height: 28),
          Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: theme.panelOpacity),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('СЕЙЧАС В ВАШЕМ ПРОСТРАНСТВЕ'),
                        style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: theme.accent)),
                    const SizedBox(height: 12),
                    Selector<AudioPlayerService, String>(
                        selector: (_, player) => player.currentTitle,
                        builder: (context, title, _) => Text(
                            title.isEmpty
                                ? context
                                    .tr('Добавьте музыку и найдите свой ритм')
                                : title,
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis)),
                    const SizedBox(height: 20),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      FilledButton.icon(
                          onPressed: () => onNavigate(2),
                          icon: const Icon(Icons.library_music),
                          label: Text(context.tr('Моя музыка'))),
                      OutlinedButton.icon(
                          onPressed: () => onNavigate(4),
                          icon: const Icon(Icons.link),
                          label: Text(context.tr('YouTube / ссылка'))),
                      OutlinedButton.icon(
                          onPressed: () {
                            if (Platform.isAndroid) {
                              onNavigate(5);
                              return;
                            }
                            context.read<DesktopWindowService>().enterWidget(
                                theme,
                                youtube: context
                                    .read<YoutubePlayerService>()
                                    .active);
                          },
                          icon: const Icon(Icons.picture_in_picture_alt),
                          label: Text(context.tr('Виджет'))),
                    ]),
                  ])),
          const SizedBox(height: 26),
          Text(context.tr('Настроение в один клик'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ThemeProvider.presets
                  .map((preset) => InkWell(
                        onTap: () => theme.applyPreset(preset),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                            width: 150,
                            height: 90,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                gradient: LinearGradient(colors: preset.colors),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: theme.presetId == preset.id
                                        ? preset.accent
                                        : Colors.white12)),
                            child: Align(
                                alignment: Alignment.bottomLeft,
                                child: Text(context.tr(preset.name),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12)))),
                      ))
                  .toList()),
          const SizedBox(height: 22),
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ProfileAvatar(path: theme.avatarPath, size: 44),
              title: Text(context.tr('Настроить оформление')),
              subtitle:
                  Text(context.tr('4K-видеофон, шрифты и оформление виджета')),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => onNavigate(5)),
        ]);
  }
}

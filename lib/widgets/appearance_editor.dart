import '../core/localization.dart';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import '../data/services/desktop_window_service.dart';
import '../data/services/youtube_player_service.dart';
import '../data/services/audio_player_service.dart';
import 'player_controls.dart';
import 'app_backdrop.dart';
import 'player_clock.dart';
import 'background_thumbnail.dart';

class AppearanceEditor extends StatefulWidget {
  const AppearanceEditor({super.key});
  @override
  State<AppearanceEditor> createState() => _AppearanceEditorState();
}

class _AppearanceEditorState extends State<AppearanceEditor> {
  static const _bundledVideo = 'asset:///assets/backgrounds/aurora-4k.mp4';
  bool _importing = false;
  bool _widgetBackground = false;
  final _style = GlobalKey(),
      _background = GlobalKey(),
      _interface = GlobalKey(),
      _widget = GlobalKey();

  Future<void> _saveWidget(ThemeProvider theme) async {
    var name = '';
    final selected = await showDialog<String>(
        context: context,
        builder: (dialog) => AlertDialog(
              title: Text(context.tr('Сохранить виджет')),
              content: TextField(
                  autofocus: true,
                  maxLength: 40,
                  onChanged: (value) => name = value,
                  decoration: InputDecoration(labelText: context.tr('Имя')),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) Navigator.pop(dialog, value);
                  }),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog),
                    child: Text(context.tr('Отмена'))),
                FilledButton(
                    onPressed: () {
                      if (name.trim().isNotEmpty) Navigator.pop(dialog, name);
                    },
                    child: Text(context.tr('Сохранить')))
              ],
            ));
    if (selected != null && mounted) {
      try {
        await theme.saveWidget(selected);
      } catch (_) {
        if (mounted) _fileError();
      }
    }
  }

  Future<void> _savedWidgets(ThemeProvider theme) async {
    final chosen = await showDialog<String>(
        context: context,
        builder: (dialog) => AlertDialog(
              title: Text(context.tr('Сохранённые виджеты')),
              content: SizedBox(
                width: 420,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in theme.savedWidgets.entries)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => Navigator.pop(dialog, item.key),
                        leading: BackgroundThumbnail(
                            path:
                                item.value['widgetMediaPath'] as String? ?? ''),
                        title: Text(item.key),
                        subtitle: Text(theme.backgroundName(
                            item.value['widgetMediaPath'] as String? ?? '')),
                      ),
                  ],
                ),
              ),
            ));
    if (chosen != null && mounted) await theme.applyWidget(chosen);
  }

  Future<void> _importFile(String label, List<String> extensions,
      {bool font = false}) async {
    setState(() => _importing = true);
    final compact = _widgetBackground;
    try {
      final file = await openFile(acceptedTypeGroups: [
        XTypeGroup(label: context.tr(label), extensions: extensions),
      ]);
      if (file == null || !mounted) return;
      final theme = context.read<ThemeProvider>();
      if (font) {
        await theme.importFont(file.path);
      } else {
        await theme.importBackground(file.path, compact: compact);
      }
    } catch (e) {
      debugPrint('Appearance import: $e');
      if (mounted) _fileError();
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _fileError() => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.tr('Не удалось открыть файл оформления.'))),
      );

  Future<void> _setFont(ThemeProvider theme, String font) async {
    try {
      await theme.setFontFamily(font);
    } catch (error) {
      if (mounted) _fileError();
    }
  }

  Future<void> _setBackground(ThemeProvider theme, String? path) =>
      _widgetBackground
          ? theme.setWidgetBackground(path)
          : theme.setBackgroundImagePath(path);

  Future<void> _pickSaved(ThemeProvider theme) async {
    final files = [
      AppearanceFile(_bundledVideo, context.tr('Готовый 4K-видеофон')),
      ...theme.savedBackgrounds,
    ];
    final compact = _widgetBackground;
    final active = compact ? theme.widgetMediaPath : theme.backgroundImagePath;
    final selection = await showDialog<AppearanceFile>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr(
            compact ? 'Сохранённые фоны виджета' : 'Сохранённые фоны плеера')),
        content: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final file in files)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => Navigator.pop(context, file),
                  leading: BackgroundThumbnail(path: file.path),
                  title: Text(file.name,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: file.path == active
                      ? const Icon(Icons.check, size: 20)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
    if (selection != null && mounted) {
      await _setBackground(theme, selection.path);
    }
  }

  Future<void> _editLoop(ThemeProvider theme) async {
    final compact = _widgetBackground;
    final path = theme.mediaPath(compact: compact);
    final duration = theme.backgroundDuration(path);
    final selected = await showDialog<VideoLoop>(
      context: context,
      builder: (_) => _LoopDialog(
          initial: theme.videoLoop(compact: compact),
          maxSeconds: duration != null
              ? (duration.inMilliseconds / 1000).ceil()
              : (path == _bundledVideo ? 4 : 86400)),
    );
    if (selected != null && mounted) {
      await theme.setVideoLoop(selected, compact: compact);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final selectedMedia =
        _widgetBackground ? theme.widgetMediaPath : theme.backgroundImagePath;
    final loop = theme.videoLoop(compact: _widgetBackground);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final (key, label) in [
          (_style, 'Готовый стиль'),
          (_background, 'Свой фон'),
          (_interface, 'Акцент и интерфейс'),
          (_widget, 'Виджет плеера')
        ])
          TextButton(
              onPressed: () {
                final target = key.currentContext;
                if (target != null) {
                  Scrollable.ensureVisible(target,
                      duration: const Duration(milliseconds: 240));
                }
              },
              child: Text(context.tr(label))),
      ]),
      SizedBox(key: _style),
      _SectionTitle(
          context.tr('Готовый стиль'),
          context.tr(
              'Выберите настроение — оформление плеера и виджета изменится сразу.')),
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 520
                ? 2
                : 1;
        return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ThemeProvider.presets
                .map((preset) => SizedBox(
                      width:
                          (constraints.maxWidth - (columns - 1) * 12) / columns,
                      child: Semantics(
                          button: true,
                          selected: theme.presetId == preset.id,
                          label: context.tr(preset.name),
                          child: InkWell(
                            onTap: () => theme.applyPreset(preset),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                                height: 116,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient:
                                        LinearGradient(colors: preset.colors),
                                    border: Border.all(
                                        color: theme.presetId == preset.id
                                            ? preset.accent
                                            : Colors.white12,
                                        width: 2)),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Expanded(
                                            child: Text(context.tr(preset.name),
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700))),
                                        if (theme.presetId == preset.id)
                                          Icon(Icons.check_circle,
                                              size: 18, color: preset.accent)
                                      ]),
                                      const Spacer(),
                                      Text(context.tr(preset.description),
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12),
                                          maxLines: 2),
                                    ])),
                          )),
                    ))
                .toList());
      }),
      const SizedBox(height: 28),
      _EditorCard(
          key: _background,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SectionTitle(
                context.tr('Свой фон'),
                context.tr(
                    'Картинка или зацикленное видео. Исходный файл используется без повторного сжатия.')),
            Wrap(spacing: 8, runSpacing: 6, children: [
              ChoiceChip(
                label: Text(context.tr('Основной плеер')),
                selected: !_widgetBackground,
                onSelected: _importing
                    ? null
                    : (_) => setState(() => _widgetBackground = false),
              ),
              ChoiceChip(
                label: Text(context.tr('Виджет')),
                selected: _widgetBackground,
                onSelected: _importing
                    ? null
                    : (_) => setState(() => _widgetBackground = true),
              ),
            ]),
            const SizedBox(height: 10),
            if (_importing) const LinearProgressIndicator(minHeight: 2),
            Wrap(spacing: 10, runSpacing: 10, children: [
              FilledButton.tonalIcon(
                  onPressed: () => _setBackground(theme, _bundledVideo),
                  icon: const Icon(Icons.high_quality_outlined),
                  label: Text(context.tr('Готовый 4K-видеофон'))),
              FilledButton.icon(
                  onPressed: _importing
                      ? null
                      : () => _importFile(
                          'Видеофайлы', ThemeProvider.videoExtensions),
                  icon: const Icon(Icons.video_library_outlined),
                  label: Text(context.tr('Импортировать своё видео'))),
              OutlinedButton.icon(
                  onPressed: _importing
                      ? null
                      : () => _importFile(
                          'Изображения', ThemeProvider.imageExtensions),
                  icon: const Icon(Icons.image_outlined),
                  label: Text(context.tr('Выбрать фото'))),
              OutlinedButton.icon(
                  onPressed: () => _pickSaved(theme),
                  icon: const Icon(Icons.collections_outlined),
                  label: Text(context.tr('Сохранённые фоны'))),
              OutlinedButton.icon(
                  onPressed: () => _setBackground(theme, null),
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(context.tr(_widgetBackground
                      ? 'Использовать фон плеера'
                      : 'Вернуть готовый фон'))),
            ]),
            if (selectedMedia != null)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(children: [
                    BackgroundThumbnail(path: selectedMedia),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(theme.backgroundName(selectedMedia),
                            style: const TextStyle(color: Colors.white70),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                  ])),
            if (selectedMedia != null &&
                theme.backgroundType(compact: _widgetBackground) ==
                    BackgroundType.video)
              TextButton.icon(
                onPressed: () => _editLoop(theme),
                icon: const Icon(Icons.loop),
                label: Text('${context.tr('Участок повтора')} · '
                    '${loop.from}–${loop.to?.toString() ?? context.tr('до конца')}'),
              ),
            const SizedBox(height: 16),
            Wrap(spacing: 8, children: [
              ChoiceChip(
                  label: Text(context.tr('Заполнить без искажения')),
                  selected:
                      theme.backdropFit(_widgetBackground) == BoxFit.cover,
                  onSelected: (_) => theme.change(
                      {_widgetBackground ? 'widgetFit' : 'fit': 'cover'})),
              ChoiceChip(
                  label: Text(context.tr('Показать целиком')),
                  selected:
                      theme.backdropFit(_widgetBackground) == BoxFit.contain,
                  onSelected: (_) => theme.change(
                      {_widgetBackground ? 'widgetFit' : 'fit': 'contain'})),
            ]),
            SettingSlider(
                label: context.tr('Затемнение фона'),
                value: _widgetBackground ? theme.widgetDim : theme.dim,
                max: .85,
                display:
                    '${((_widgetBackground ? theme.widgetDim : theme.dim) * 100).round()}%',
                onChanged: (v) =>
                    theme.change({_widgetBackground ? 'widgetDim' : 'dim': v})),
            SettingSlider(
                label: context.tr('Размытие'),
                value: theme.backdropBlur(_widgetBackground),
                max: 16,
                display: theme.backdropBlur(_widgetBackground) == 0
                    ? context.tr('Выключено')
                    : '${theme.backdropBlur(_widgetBackground).round()}',
                onChanged: (v) => theme
                    .change({_widgetBackground ? 'widgetBlur' : 'blur': v})),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Живой фон')),
                subtitle: Text(
                    context.tr('Движение готовых тем и зацикливание видео')),
                value: theme.backdropMotion(_widgetBackground),
                onChanged: (v) => theme.change(_widgetBackground
                    ? {'widgetMotion': v ? 'on' : 'off'}
                    : {'motion': v})),
          ])),
      const SizedBox(height: 18),
      _EditorCard(
          key: _interface,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SectionTitle(context.tr('Акцент и интерфейс'), ''),
            Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ...ThemeProvider.presets.map((p) => p.accent),
                  Colors.white,
                  Colors.amberAccent
                ]
                    .map((color) => Semantics(
                        button: true,
                        label: context.tr('Цвет {hex}',
                            {'hex': color.toARGB32().toRadixString(16)}),
                        selected: theme.accent == color,
                        child: InkWell(
                            onTap: () =>
                                theme.change({'accent': color.toARGB32()}),
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: theme.accent == color
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: 3)),
                                child: theme.accent == color
                                    ? const Icon(Icons.check, color: Colors.black, size: 18)
                                    : null))))
                    .toList()),
            const SizedBox(height: 18),
            Text(context.tr('Шрифт')),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              ...ThemeProvider.fonts.map((font) => ChoiceChip(
                  label:
                      Text(font == 'System' ? context.tr('Системный') : font),
                  selected: theme.fontFamily == font,
                  onSelected: (_) => _setFont(theme, font))),
              for (final font in theme.savedFonts)
                ChoiceChip(
                  label: Text(font.name),
                  selected: theme.fontFamily == ThemeProvider.fontId(font),
                  onSelected: (_) =>
                      _setFont(theme, ThemeProvider.fontId(font)),
                ),
              OutlinedButton.icon(
                onPressed: _importing
                    ? null
                    : () => _importFile('Шрифты', ThemeProvider.fontExtensions,
                        font: true),
                icon: const Icon(Icons.font_download_outlined),
                label: Text(context.tr('Импортировать шрифт')),
              ),
            ]),
            SettingSlider(
                label: context.tr('Плотность панелей'),
                value: theme.panelOpacity,
                min: .05,
                max: .95,
                display: '${(theme.panelOpacity * 100).round()}%',
                onChanged: (v) => theme.change({'panelOpacity': v})),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Часы на главной')),
                value: theme.showClock,
                onChanged: (v) => theme.change({'showClock': v})),
          ])),
      const SizedBox(height: 18),
      _EditorCard(
          key: _widget,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SectionTitle(
                context.tr(
                    Platform.isAndroid ? 'Виджет плеера' : 'Плавающий виджет'),
                context.tr(Platform.isAndroid
                    ? 'Компактный плеер с отдельным фоном и сохранёнными стилями.'
                    : 'Та же музыка и тот же фон в компактном окне поверх других приложений.')),
            _WidgetPreview(theme: theme),
            const SizedBox(height: 16),
            Wrap(spacing: 8, children: [
              ChoiceChip(
                  label: Text(context.tr('Стекло')),
                  selected: theme.widgetStyle == WidgetStyle.glass,
                  onSelected: (_) => theme.change({'widgetStyle': 'glass'})),
              ChoiceChip(
                  label: Text(context.tr('Матовый')),
                  selected: theme.widgetStyle == WidgetStyle.solid,
                  onSelected: (_) => theme.change({'widgetStyle': 'solid'})),
              ChoiceChip(
                  label: Text(context.tr('Минимум')),
                  selected: theme.widgetStyle == WidgetStyle.minimal,
                  onSelected: (_) => theme.change({'widgetStyle': 'minimal'})),
            ]),
            SettingSlider(
                label: context.tr('Ширина'),
                value: theme.widgetWidth,
                min: 360,
                max: 800,
                display: '${theme.widgetWidth.round()} px',
                onChanged: (v) =>
                    theme.change({'widgetWidth': v.roundToDouble()})),
            SettingSlider(
                label: context.tr('Высота'),
                value: theme.widgetHeight,
                min: 250,
                max: 700,
                display: '${theme.widgetHeight.round()} px',
                onChanged: (v) =>
                    theme.change({'widgetHeight': v.roundToDouble()})),
            SettingSlider(
                label: context.tr('Скругление'),
                value: theme.widgetRadius,
                max: 40,
                display: '${theme.widgetRadius.round()} px',
                onChanged: (v) => theme.change({'widgetRadius': v})),
            SettingSlider(
                label: context.tr('Затемнение виджета'),
                value: theme.widgetDim,
                max: .85,
                display: '${(theme.widgetDim * 100).round()}%',
                onChanged: (v) => theme.change({'widgetDim': v})),
            if (Platform.isWindows)
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr('Поверх остальных окон')),
                  value: theme.widgetOnTop,
                  onChanged: (v) => theme.change({'widgetOnTop': v})),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Показывать исполнителя')),
                value: theme.widgetArtist,
                onChanged: (v) => theme.change({'widgetArtist': v})),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Показывать перемотку')),
                value: theme.widgetProgress,
                onChanged: (v) => theme.change({'widgetProgress': v})),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Часы в виджете')),
                value: theme.widgetClock,
                onChanged: (v) => theme.change({'widgetClock': v})),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                  onPressed: () {
                    if (Platform.isWindows) {
                      context.read<DesktopWindowService>().enterWidget(theme,
                          youtube: context.read<YoutubePlayerService>().active);
                    } else {
                      final player = context.read<AudioPlayerService>();
                      showDialog<void>(
                          context: context,
                          builder: (dialog) => Dialog(
                              child: _WidgetPreview(
                                  theme: theme,
                                  player: player,
                                  interactive: true)));
                    }
                  },
                  icon: const Icon(Icons.picture_in_picture_alt),
                  label: Text(context.tr(Platform.isWindows
                      ? 'Открыть плавающий виджет'
                      : 'Открыть виджет'))),
              OutlinedButton.icon(
                  onPressed: () => _saveWidget(theme),
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: Text(context.tr('Сохранить виджет'))),
              if (theme.savedWidgets.isNotEmpty)
                OutlinedButton.icon(
                    onPressed: () => _savedWidgets(theme),
                    icon: const Icon(Icons.widgets_outlined),
                    label: Text(context.tr('Сохранённые виджеты'))),
            ]),
          ])),
      const SizedBox(height: 20),
      TextButton.icon(
          onPressed: theme.resetAppearance,
          icon: const Icon(Icons.restart_alt),
          label: Text(context.tr('Сбросить оформление'))),
    ]);
  }
}

class _WidgetPreview extends StatelessWidget {
  const _WidgetPreview(
      {required this.theme, this.player, this.interactive = false});
  final ThemeProvider theme;
  final AudioPlayerService? player;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final audio = player ?? context.read<AudioPlayerService>();
    final opacity = switch (theme.widgetStyle) {
      WidgetStyle.glass => theme.panelOpacity,
      WidgetStyle.solid => .85,
      WidgetStyle.minimal => .15,
    };
    return LayoutBuilder(builder: (context, box) {
      final scale = (box.maxWidth / 800).clamp(.1, .58);
      final radius = BorderRadius.circular(theme.widgetRadius * scale);
      return Center(
          child: ClipRRect(
              borderRadius: radius,
              child: SizedBox(
                width: theme.widgetWidth * scale,
                height: theme.widgetHeight * scale,
                child: Stack(fit: StackFit.expand, children: [
                  AppBackdrop(
                      theme: theme, compact: true, preview: !interactive),
                  DecoratedBox(
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.white38),
                          borderRadius: radius),
                      child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Column(children: [
                            const Align(
                                alignment: Alignment.topLeft,
                                child: Text('oTune',
                                    style: TextStyle(fontSize: 10))),
                            if (theme.widgetClock)
                              const Flexible(
                                  child: Center(
                                      child: PlayerClock(compact: true))),
                            if (!theme.widgetClock) const Spacer(),
                            ColoredBox(
                                color: Colors.black.withValues(alpha: opacity),
                                child: _WidgetPreviewControls(
                                    audio: audio,
                                    theme: theme,
                                    interactive: interactive)),
                          ]))),
                ]),
              )));
    });
  }
}

class _WidgetPreviewControls extends StatelessWidget {
  const _WidgetPreviewControls(
      {required this.audio, required this.theme, required this.interactive});
  final AudioPlayerService audio;
  final ThemeProvider theme;
  final bool interactive;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: audio,
      builder: (context, _) {
        final duration = audio.duration.inMilliseconds;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const SizedBox(width: 5),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      audio.currentTitle.isEmpty
                          ? context.tr('Выберите трек')
                          : audio.currentTitle,
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (theme.widgetArtist && audio.currentArtist.isNotEmpty)
                    Text(audio.currentArtist,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ])),
            if (interactive)
              IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip:
                      context.tr(audio.isPlaying ? 'Пауза' : 'Воспроизвести'),
                  onPressed: audio.hasTrack ? audio.togglePlayPause : null,
                  icon: Icon(
                      audio.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 20))
            else
              const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.play_arrow_rounded, size: 18)),
          ]),
          if (theme.widgetProgress)
            LinearProgressIndicator(
                minHeight: 2,
                value: duration == 0
                    ? 0
                    : (audio.position.inMilliseconds / duration)
                        .clamp(0.0, 1.0)),
        ]);
      });
}

class _LoopDialog extends StatefulWidget {
  const _LoopDialog({required this.initial, required this.maxSeconds});
  final VideoLoop initial;
  final int maxSeconds;

  @override
  State<_LoopDialog> createState() => _LoopDialogState();
}

class _LoopDialogState extends State<_LoopDialog> {
  final _form = GlobalKey<FormState>();
  late final _from = TextEditingController(text: '${widget.initial.from}');
  late final _to = TextEditingController(text: widget.initial.to?.toString());

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(context.tr('Участок повтора')),
        content: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _from,
              decoration:
                  InputDecoration(labelText: context.tr('Начало, секунды')),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                final seconds = int.tryParse(value ?? '');
                return seconds == null || seconds >= widget.maxSeconds
                    ? context.tr('Укажите секунду в пределах видео.')
                    : null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _to,
              decoration: InputDecoration(
                labelText: context.tr('Конец, секунды'),
                hintText: context.tr('До конца файла'),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                final seconds = int.tryParse(value);
                final start = int.tryParse(_from.text) ?? 0;
                return seconds == null ||
                        seconds <= start ||
                        seconds > widget.maxSeconds
                    ? context.tr('Конец должен быть после начала.')
                    : null;
              },
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop<VideoLoop>(context, (from: 0, to: null)),
            child: Text(context.tr('Всё видео')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Отмена')),
          ),
          FilledButton(
            onPressed: () {
              if (_form.currentState!.validate()) {
                Navigator.pop<VideoLoop>(context,
                    (from: int.parse(_from.text), to: int.tryParse(_to.text)));
              }
            },
            child: Text(context.tr('Сохранить')),
          ),
        ],
      );
}

class SettingSlider extends StatelessWidget {
  final String label, display;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  const SettingSlider(
      {super.key,
      required this.label,
      required this.value,
      this.min = 0,
      this.max = 1,
      required this.display,
      required this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(label)),
          Text(display,
              style: const TextStyle(color: Colors.white70, fontSize: 12))
        ]),
        PlayerSlider(
            label: label,
            value: value,
            min: min,
            max: max,
            onChanged: onChanged),
      ]));
}

class _EditorCard extends StatelessWidget {
  final Widget child;
  const _EditorCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .24),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white12)),
      child: Material(type: MaterialType.transparency, child: child));
}

class _SectionTitle extends StatelessWidget {
  final String title, subtitle;
  const _SectionTitle(this.title, this.subtitle);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.white60)),
        ],
      ]));
}

class ProfileAvatar extends StatelessWidget {
  final String? path;
  final double size;
  const ProfileAvatar({super.key, this.path, this.size = 64});
  @override
  Widget build(BuildContext context) {
    final fallback = Icon(Icons.person_outline,
        size: size * .5, color: Theme.of(context).colorScheme.primary);
    return ClipOval(
        child: Container(
            width: size,
            height: size,
            color: Colors.white12,
            child: path == null
                ? fallback
                : Image.file(File(path!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => fallback)));
  }
}

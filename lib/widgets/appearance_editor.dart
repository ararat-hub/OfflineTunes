import '../core/localization.dart';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import '../data/services/desktop_window_service.dart';
import '../data/services/youtube_player_service.dart';
import '../data/services/audio_player_service.dart';
import 'mini_player.dart';
import 'player_controls.dart';

class AppearanceEditor extends StatefulWidget {
  const AppearanceEditor({super.key});
  @override
  State<AppearanceEditor> createState() => _AppearanceEditorState();
}

class _AppearanceEditorState extends State<AppearanceEditor> {
  bool _importing = false;

  Future<void> _pickPhoto(BuildContext context) async {
    final file = await openFile(acceptedTypeGroups: [
      XTypeGroup(
          label: context.tr('Изображения'),
          extensions: ['jpg', 'jpeg', 'png', 'webp'])
    ]);
    if (file == null || !context.mounted) return;
    await context.read<ThemeProvider>().setBackgroundImagePath(file.path);
  }

  Future<void> _importVideo() async {
    setState(() => _importing = true);
    try {
      final file = await openFile(acceptedTypeGroups: [
        XTypeGroup(
            label: context.tr('Видеофайлы'),
            extensions: ThemeProvider.videoExtensions)
      ]);
      if (file == null || !mounted) return;
      await context.read<ThemeProvider>().importBackgroundVideo(file.path);
    } catch (e) {
      debugPrint('Background import: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.tr(
                'Не удалось импортировать видео. Проверьте файл и свободное место.'))));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionTitle(
            context.tr('Свой фон'),
            context.tr(
                'Картинка или зацикленное видео. Исходный файл используется без повторного сжатия.')),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.tonalIcon(
              onPressed: () => theme.setBackgroundImagePath(
                  'asset:///assets/backgrounds/aurora-4k.mp4'),
              icon: const Icon(Icons.high_quality_outlined),
              label: Text(context.tr('Готовый 4K-видеофон'))),
          FilledButton.icon(
              onPressed: _importing ? null : _importVideo,
              icon: const Icon(Icons.video_library_outlined),
              label: Text(_importing
                  ? context.tr('Копируем видео…')
                  : context.tr('Импортировать своё видео'))),
          OutlinedButton.icon(
              onPressed: () => _pickPhoto(context),
              icon: const Icon(Icons.image_outlined),
              label: Text(context.tr('Выбрать фото'))),
          if (theme.importedVideoPath != null &&
              theme.backgroundImagePath != theme.importedVideoPath)
            OutlinedButton(
                onPressed: () =>
                    theme.setBackgroundImagePath(theme.importedVideoPath),
                child: Text(context.tr('Моё видео'))),
          OutlinedButton.icon(
              onPressed: () => theme.setBackgroundImagePath(null),
              icon: const Icon(Icons.auto_awesome),
              label: Text(context.tr('Вернуть готовый фон'))),
        ]),
        if (theme.backgroundImagePath != null)
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                  theme.backgroundImagePath == theme.importedVideoPath
                      ? theme.importedVideoName
                      : theme.backgroundImagePath!.split(RegExp(r'[/\\]')).last,
                  style: const TextStyle(color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, children: [
          ChoiceChip(
              label: Text(context.tr('Заполнить без искажения')),
              selected: theme.backgroundFit == BoxFit.cover,
              onSelected: (_) => theme.change({'fit': 'cover'})),
          ChoiceChip(
              label: Text(context.tr('Показать целиком')),
              selected: theme.backgroundFit == BoxFit.contain,
              onSelected: (_) => theme.change({'fit': 'contain'})),
        ]),
        SettingSlider(
            label: context.tr('Затемнение фона'),
            value: theme.dim,
            max: .85,
            display: '${(theme.dim * 100).round()}%',
            onChanged: (v) => theme.change({'dim': v})),
        SettingSlider(
            label: context.tr('Размытие'),
            value: theme.blur,
            max: 16,
            display: theme.blur == 0
                ? context.tr('Выключено')
                : '${theme.blur.round()}',
            onChanged: (v) => theme.change({'blur': v})),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('Живой фон')),
            subtitle:
                Text(context.tr('Движение готовых тем и зацикливание видео')),
            value: theme.motion,
            onChanged: (v) => theme.change({'motion': v})),
      ])),
      const SizedBox(height: 18),
      _EditorCard(
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
                        onTap: () => theme.change({'accent': color.toARGB32()}),
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
                                ? const Icon(Icons.check,
                                    color: Colors.black, size: 18)
                                : null))))
                .toList()),
        const SizedBox(height: 18),
        Text(context.tr('Шрифт')),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            runSpacing: 6,
            children: ThemeProvider.fonts
                .map((font) => ChoiceChip(
                    label:
                        Text(font == 'System' ? context.tr('Системный') : font),
                    selected: theme.fontFamily == font,
                    onSelected: (_) => theme.setFontFamily(font)))
                .toList()),
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionTitle(
            context.tr('Плавающий виджет'),
            context.tr(
                'Та же музыка и тот же фон в компактном окне поверх других приложений.')),
        Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(theme.widgetRadius),
                  child: Container(
                      decoration: BoxDecoration(
                          gradient:
                              LinearGradient(colors: theme.preset.colors)),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(children: [
                              Icon(Icons.drag_indicator, size: 16),
                              SizedBox(width: 8),
                              Text('OFFLINETUNES',
                                  style: TextStyle(
                                      letterSpacing: 2, fontSize: 11)),
                              Spacer(),
                              Icon(Icons.open_in_full, size: 16)
                            ])),
                        MiniPlayer(
                            playerService: context.read<AudioPlayerService>(),
                            compact: true,
                            showArtist: theme.widgetArtist,
                            showProgress: theme.widgetProgress,
                            opacity: theme.widgetStyle == WidgetStyle.solid
                                ? .85
                                : theme.widgetStyle == WidgetStyle.minimal
                                    ? 0
                                    : theme.panelOpacity),
                      ])),
                ))),
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
            onChanged: (v) => theme.change({'widgetWidth': v.roundToDouble()})),
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
        FilledButton.icon(
            onPressed: () => context.read<DesktopWindowService>().enterWidget(
                theme,
                youtube: context.read<YoutubePlayerService>().active),
            icon: const Icon(Icons.picture_in_picture_alt),
            label: Text(context.tr('Открыть плавающий виджет'))),
      ])),
      const SizedBox(height: 20),
      TextButton.icon(
          onPressed: theme.resetAppearance,
          icon: const Icon(Icons.restart_alt),
          label: Text(context.tr('Сбросить оформление'))),
    ]);
  }
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
  const _EditorCard({required this.child});
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

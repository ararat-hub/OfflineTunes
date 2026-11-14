import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/localization.dart';
import '../core/strings.dart';
import '../data/services/update_service.dart';

Future<void> showUpdate(BuildContext context, AppUpdate update) async {
  final updates = context.read<UpdateService>();
  final open = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context
          .tr('Доступна новая версия {app}', {'app': AppStrings.appName})),
      content:
          Text(context.tr('Версия {version}', {'version': update.version})),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Позже'))),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr(update.download == null
                ? 'Открыть релиз на GitHub'
                : 'Скачать обновление'))),
      ],
    ),
  );
  await updates.markOffered(update);
  if (open == true) {
    if (!await launchUrl(update.download ?? update.page,
            mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Не удалось открыть ссылку.'))));
    }
  }
}

class UpdateControls extends StatefulWidget {
  const UpdateControls({super.key});

  @override
  State<UpdateControls> createState() => _UpdateControlsState();
}

class _UpdateControlsState extends State<UpdateControls> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      final update = await context.read<UpdateService>().check(manual: true);
      if (!mounted) return;
      if (update == null) {
        _message('Установлена актуальная версия.');
      } else {
        await showUpdate(context, update);
      }
    } catch (error) {
      if (mounted) _message('Не удалось проверить обновления.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(context.tr(message))));

  @override
  Widget build(BuildContext context) {
    final updates = context.read<UpdateService>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(context.tr('Предлагать новые версии')),
        value: updates.automatic,
        onChanged: (value) async {
          await updates.setAutomatic(value);
          if (mounted) setState(() {});
        },
      ),
      FilledButton.tonalIcon(
        onPressed: _checking ? null : _check,
        icon: const Icon(Icons.system_update_alt),
        label:
            Text(context.tr(_checking ? 'Проверяем…' : 'Проверить обновления')),
      ),
    ]);
  }
}

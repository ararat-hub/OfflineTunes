import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization.dart';
import '../../data/services/app_preferences.dart';
import '../../widgets/appearance_editor.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    final labels = ['Оформление', 'Язык', 'Горячие клавиши'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (var i = 0; i < labels.length; i++)
              ChoiceChip(
                label: Text(context.tr(labels[i])),
                selected: _section == i,
                onSelected: (_) => setState(() => _section = i),
              ),
          ],
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          key: ValueKey(_section),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: switch (_section) {
            1 => const _LanguageSettings(),
            2 => const _HotkeySettings(),
            _ => const AppearanceEditor(),
          },
        ),
      ),
    ]);
  }
}

class _LanguageSettings extends StatelessWidget {
  const _LanguageSettings();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppPreferences>();
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        for (final language in AppPreferences.languages.entries)
          ChoiceChip(
            label: Text(language.value),
            selected: language.key == settings.locale.languageCode,
            onSelected: (_) async {
              try {
                await settings.setLanguage(language.key);
              } catch (_) {
                if (context.mounted) _settingsError(context);
              }
            },
          ),
      ],
    );
  }
}

class _HotkeySettings extends StatelessWidget {
  const _HotkeySettings();

  static String label(HotkeyAction action) => switch (action) {
        HotkeyAction.playPause => 'Воспроизведение / пауза',
        HotkeyAction.next => 'Следующий трек',
        HotkeyAction.previous => 'Предыдущий трек',
        HotkeyAction.mute => 'Выключить / включить звук',
        HotkeyAction.widget => 'Переключить плавающий виджет',
      };

  Future<void> _edit(BuildContext context, AppPreferences settings,
      HotkeyAction action) async {
    final binding = await showDialog<HotkeyBinding>(
        context: context,
        builder: (_) => _BindingDialog(
              title: label(action),
              initial: settings.binding(action),
            ));
    if (binding == null || !context.mounted) return;
    try {
      if (!await settings.setBinding(action, binding) && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(context.tr('Это сочетание уже занято. Выберите другое.')),
        ));
      }
    } catch (_) {
      if (context.mounted) _settingsError(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppPreferences>();
    if (!settings.supportsHotkeys) {
      return Text(context.tr('Глобальные горячие клавиши доступны в Windows.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('Глобальные горячие клавиши')),
          subtitle: Text(context.tr(
              'Управляйте музыкой и виджетом из других приложений Windows. Для страницы YouTube используйте её кнопки.')),
          value: settings.hotkeysEnabled,
          onChanged: settings.busy
              ? null
              : (value) async {
                  try {
                    await settings.setHotkeysEnabled(value);
                  } catch (_) {
                    if (context.mounted) _settingsError(context);
                  }
                },
        ),
        const SizedBox(height: 8),
        for (final action in HotkeyAction.values)
          Builder(builder: (context) {
            final binding = settings.binding(action);
            final keys =
                '${AppPreferences.modifierChoices[binding.modifiers]} + '
                '${AppPreferences.keyLabel(binding.key)}';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr(label(action))),
              subtitle: Text(settings.unavailable(action)
                  ? context.tr('Сочетание занято')
                  : keys),
              trailing: TextButton(
                onPressed: settings.busy
                    ? null
                    : () => _edit(context, settings, action),
                child: Text(context.tr('Изменить')),
              ),
            );
          }),
      ],
    );
  }
}

class _BindingDialog extends StatefulWidget {
  const _BindingDialog({required this.title, required this.initial});
  final String title;
  final HotkeyBinding initial;

  @override
  State<_BindingDialog> createState() => _BindingDialogState();
}

class _BindingDialogState extends State<_BindingDialog> {
  late int _modifiers = widget.initial.modifiers;
  late int _key = widget.initial.key;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(context.tr(widget.title)),
        content: Wrap(
          spacing: 16,
          children: [
            DropdownButton<int>(
              value: _modifiers,
              items: [
                for (final entry in AppPreferences.modifierChoices.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _modifiers = value!),
            ),
            DropdownButton<int>(
              value: _key,
              items: [
                for (final value in AppPreferences.keyChoices)
                  DropdownMenuItem(
                      value: value,
                      child: Text(AppPreferences.keyLabel(value))),
              ],
              onChanged: (value) => setState(() => _key = value!),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Отмена')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, (modifiers: _modifiers, key: _key)),
            child: Text(context.tr('Сохранить')),
          ),
        ],
      );
}

void _settingsError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('Не удалось сохранить настройки.'))));
}

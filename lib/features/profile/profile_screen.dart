import '../../core/localization.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/appearance_editor.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _bio;
  @override
  void initState() {
    super.initState();
    final theme = context.read<ThemeProvider>();
    _name = TextEditingController(text: theme.profileName);
    _bio = TextEditingController(text: theme.profileBio);
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _avatar() async {
    final file = await openFile(acceptedTypeGroups: [
      XTypeGroup(
          label: context.tr('Аватар'),
          extensions: ['jpg', 'jpeg', 'png', 'webp'])
    ]);
    if (file == null || !mounted) return;
    await context.read<ThemeProvider>().change({'avatar': file.path});
  }

  Future<void> _save() async {
    try {
      await context
          .read<ThemeProvider>()
          .change({'name': _name.text, 'bio': _bio.text});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Профиль сохранён'))));
    } catch (e) {
      if (mounted) {
        debugPrint('Save profile: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.tr('Не удалось сохранить профиль.'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return ListView(padding: const EdgeInsets.all(28), children: [
      Text(context.tr('Ваше пространство'),
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const SizedBox(height: 24),
      Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .24),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              ProfileAvatar(path: theme.avatarPath, size: 72),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        theme.profileName == ThemeProvider.defaultProfileName
                            ? context.tr(theme.profileName)
                            : theme.profileName,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                        theme.profileBio == ThemeProvider.defaultProfileBio
                            ? context.tr(theme.profileBio)
                            : theme.profileBio,
                        style: const TextStyle(color: Colors.white70)),
                  ]))
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              TextButton.icon(
                  onPressed: _avatar,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(context.tr('Выбрать аватар'))),
              if (theme.avatarPath != null)
                TextButton(
                    onPressed: () => theme.change({'avatar': ''}),
                    child: Text(context.tr('Убрать аватар')))
            ]),
            const SizedBox(height: 10),
            TextField(
                controller: _name,
                maxLength: 40,
                decoration: InputDecoration(labelText: context.tr('Имя'))),
            const SizedBox(height: 10),
            TextField(
                controller: _bio,
                maxLength: 140,
                maxLines: 2,
                decoration: InputDecoration(
                    labelText: context.tr('О себе или о своём настроении'))),
            FilledButton(
                onPressed: _save, child: Text(context.tr('Сохранить профиль'))),
          ])),
    ]);
  }
}

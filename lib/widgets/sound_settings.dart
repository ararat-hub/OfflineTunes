import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/localization.dart';
import '../data/models/equalizer.dart';
import '../data/services/audio_player_service.dart';
import 'player_controls.dart';

class SoundSettings extends StatelessWidget {
  const SoundSettings({super.key});

  static const presets = <String, Equalizer>{
    'Ровный': flatEqualizer,
    'Больше баса': (bass: 5, mid: 0, treble: 0),
    'Голос': (bass: -2, mid: 4, treble: 1),
    'Яркий': (bass: 1, mid: -1, treble: 4),
  };

  @override
  Widget build(BuildContext context) {
    final audio = context.read<AudioPlayerService>();
    return Selector<AudioPlayerService, Equalizer>(
      selector: (_, service) => service.equalizer,
      builder: (context, value, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('Эквалайзер для аудиотреков'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final preset in presets.entries)
                ChoiceChip(
                  label: Text(context.tr(preset.key)),
                  selected: value == preset.value,
                  onSelected: audio.supportsEqualizer
                      ? (_) => audio.setEqualizer(preset.value)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _Band(
              label: context.tr('Низкие частоты'),
              value: value.bass,
              change: (gain) => audio.setEqualizer((
                    bass: gain,
                    mid: audio.equalizer.mid,
                    treble: audio.equalizer.treble
                  ))),
          _Band(
              label: context.tr('Средние частоты'),
              value: value.mid,
              change: (gain) => audio.setEqualizer((
                    bass: audio.equalizer.bass,
                    mid: gain,
                    treble: audio.equalizer.treble
                  ))),
          _Band(
              label: context.tr('Высокие частоты'),
              value: value.treble,
              change: (gain) => audio.setEqualizer((
                    bass: audio.equalizer.bass,
                    mid: audio.equalizer.mid,
                    treble: gain
                  ))),
        ],
      ),
    );
  }
}

class _Band extends StatelessWidget {
  const _Band({required this.label, required this.value, required this.change});
  final String label;
  final int value;
  final ValueChanged<int> change;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(label)),
        PlayerControlButton(
            tooltip: '$label −',
            icon: const Icon(Icons.remove),
            onPressed: value > -6 ? () => change(value - 1) : null),
        SizedBox(
            width: 52,
            child: Text('${value > 0 ? '+' : ''}$value dB',
                textAlign: TextAlign.center)),
        PlayerControlButton(
            tooltip: '$label +',
            icon: const Icon(Icons.add),
            onPressed: value < 6 ? () => change(value + 1) : null),
      ]);
}

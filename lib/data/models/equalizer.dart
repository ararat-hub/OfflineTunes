import 'dart:math' as math;

typedef Equalizer = ({int bass, int mid, int treble});

const flatEqualizer = (bass: 0, mid: 0, treble: 0);

String equalizerFilter(Equalizer value) {
  final bass = value.bass.clamp(-6, 6);
  final mid = value.mid.clamp(-6, 6);
  final treble = value.treble.clamp(-6, 6);
  if (bass == 0 && mid == 0 && treble == 0) return '';
  final filters = [
    if (bass != 0) 'equalizer=f=110:t=o:w=2:g=$bass',
    if (mid != 0) 'equalizer=f=1000:t=o:w=2:g=$mid',
    if (treble != 0) 'equalizer=f=6500:t=o:w=2:g=$treble',
  ];
  return 'lavfi=[${filters.join(',')}]';
}

double equalizerHeadroom(Equalizer value) {
  final boost =
      math.max(0, math.max(value.bass, math.max(value.mid, value.treble)));
  return math.pow(10, -boost / 20).toDouble();
}

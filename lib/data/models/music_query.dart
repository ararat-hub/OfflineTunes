class MusicQuery {
  MusicQuery(String input) : text = input.trim();

  final String text;
  static final _punctuation = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
  static final _marks = RegExp(r'\p{M}+', unicode: true);
  static final _cyrillic = RegExp('[а-яё]', caseSensitive: false);
  static const _transliteration = {
    'а': 'a',
    'б': 'b',
    'в': 'v',
    'г': 'g',
    'д': 'd',
    'е': 'e',
    'ё': 'e',
    'ж': 'zh',
    'з': 'z',
    'и': 'i',
    'й': 'y',
    'к': 'k',
    'л': 'l',
    'м': 'm',
    'н': 'n',
    'о': 'o',
    'п': 'p',
    'р': 'r',
    'с': 's',
    'т': 't',
    'у': 'u',
    'ф': 'f',
    'х': 'kh',
    'ц': 'ts',
    'ч': 'ch',
    'ш': 'sh',
    'щ': 'shch',
    'ъ': '',
    'ы': 'y',
    'ь': '',
    'э': 'e',
    'ю': 'yu',
    'я': 'ya',
  };
  static const _artistNames = {
    'виктор цой': 'viktor tsoi',
    'кино': 'kino',
    'земфира': 'zemfira',
    'сплин': 'splean',
    'оксимирон': 'oxxxymiron',
    'баста': 'basta',
    'монеточка': 'monetochka',
    'би 2': 'bi 2',
    'ленинград': 'leningrad',
    'агата кристи': 'agata kristi',
    'алиса': 'alisa',
    'король и шут': 'korol i shut',
    'руки вверх': 'ruki vverh',
    'сектор газа': 'sektor gaza',
    'гражданская оборона': 'grazhdanskaya oborona',
    'люмен': 'lumen',
    'макsим': 'maksim',
    'любе': 'lyube',
    'мияги': 'miyagi',
    'шаман': 'shaman',
  };

  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll(_marks, '')
      .replaceAll('ё', 'е')
      .replaceAll(_punctuation, ' ')
      .trim();

  static String _latin(String value) => value
      .split('')
      .map((letter) => _transliteration[letter] ?? letter)
      .join();

  bool get hasArtistAlias => _artistNames.entries.any((entry) =>
      _beginsWith(_normalized, entry.key) ||
      _beginsWith(_normalized, entry.value));

  late final _normalized = normalize(text);

  static bool _beginsWith(String text, String prefix) =>
      text == prefix || text.startsWith('$prefix ');

  List<String> get variants {
    final normal = _normalized;
    if (normal.isEmpty) return const [];
    final spellings = <String>{text};
    for (final entry in _artistNames.entries) {
      if (_beginsWith(normal, entry.key)) {
        spellings.add(entry.value + _latin(normal.substring(entry.key.length)));
      }
      if (_beginsWith(normal, entry.value)) {
        spellings.add(entry.key + normal.substring(entry.value.length));
      }
    }
    for (final name in ['виктор цой', 'viktor tsoi', 'viktor tsoy']) {
      if (_beginsWith(normal, name)) {
        spellings.add('Кино${normal.substring(name.length)}');
      }
    }
    if (_cyrillic.hasMatch(normal) && normal.length >= 3) {
      spellings.add(_latin(normal));
      if (text.toLowerCase().contains('ё')) spellings.add(normal);
    }
    return spellings.toList();
  }

  String? get cyrillicVariant =>
      variants.where((variant) => _cyrillic.hasMatch(variant)).firstOrNull;

  static String recordingArtist(String artist) {
    final normalized = normalize(artist);
    if (const {
      'кино',
      'виктор цой',
      'viktor tsoi',
      'viktor tsoy',
      'кино и виктор цой'
    }.contains(normalized)) {
      return 'кино';
    }
    return _latin(normalized);
  }

  late final _terms = variants
      .map((value) => _latin(normalize(value)))
      .toSet()
      .map((value) => value.split(' '))
      .toList();

  bool matches(String title, String artist) => score(title, artist) > 0;

  int score(String title, String artist) {
    if (_terms.isEmpty) return 0;
    final artistKey = _latin(normalize(artist));
    final titleKey = _latin(normalize(title));
    final words = '$titleKey $artistKey'.split(' ');
    var best = 0;
    for (final term in _terms) {
      if (!term.every((part) => words.any((word) => word.startsWith(part)))) {
        continue;
      }
      final whole = term.join(' ');
      final score = artistKey == whole
          ? 4
          : titleKey == whole
              ? 3
              : titleKey.contains(whole) || artistKey.contains(whole)
                  ? 2
                  : 1;
      if (score > best) best = score;
    }
    return best;
  }
}

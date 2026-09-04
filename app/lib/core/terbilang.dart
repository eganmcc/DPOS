/// Indonesian number-to-words ("terbilang"), for spoken payment confirmations.
///
/// terbilang(1352400) == "satu juta tiga ratus lima puluh dua ribu empat ratus".
/// Handles the special forms: se- for one ("seratus", "seribu", "sepuluh",
/// "sebelas") and the belasan (11..19) row. Supports up to triliun.
library;

const List<String> _units = [
  '', 'satu', 'dua', 'tiga', 'empat', 'lima',
  'enam', 'tujuh', 'delapan', 'sembilan', 'sepuluh', 'sebelas',
];

String _below1000(int n) {
  if (n < 12) return _units[n];
  if (n < 20) return '${_units[n - 10]} belas';
  if (n < 100) {
    final tens = n ~/ 10, rest = n % 10;
    return rest > 0 ? '${_units[tens]} puluh ${_units[rest]}' : '${_units[tens]} puluh';
  }
  final hundreds = n ~/ 100, rest = n % 100;
  final head = hundreds == 1 ? 'seratus' : '${_units[hundreds]} ratus';
  return rest > 0 ? '$head ${_below1000(rest)}' : head;
}

/// Non-negative amounts only in practice; negatives handled defensively.
String terbilang(int n) {
  if (n == 0) return 'nol';
  if (n < 0) return 'minus ${terbilang(-n)}';

  const scales = <List<Object>>[
    [1000000000000, 'triliun'],
    [1000000000, 'miliar'],
    [1000000, 'juta'],
    [1000, 'ribu'],
  ];

  final parts = <String>[];
  var rest = n;
  for (final s in scales) {
    final div = s[0] as int;
    final word = s[1] as String;
    if (rest >= div) {
      final count = rest ~/ div;
      // "seribu" only for exactly one thousand; higher scales say "satu juta" etc.
      if (div == 1000 && count == 1) {
        parts.add('seribu');
      } else {
        parts.add('${_below1000(count)} $word');
      }
      rest %= div;
    }
  }
  if (rest > 0) parts.add(_below1000(rest));
  return parts.join(' ');
}

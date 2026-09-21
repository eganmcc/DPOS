/// What the server read off a photographed nota. Mirrors `NotaReadResult` on the server.
///
/// Every field can be null: the reader is told to leave a blank rather than guess, and the
/// screen shows a blank as "not readable" instead of a fake zero.
class NotaLine {
  const NotaLine({
    required this.rawText,
    this.qty,
    this.unitPrice,
    this.lineTotal,
    this.edited = false,
  });

  /// Exactly as written on the paper, abbreviations included.
  final String rawText;
  final num? qty;
  final int? unitPrice;
  final int? lineTotal;

  /// A person corrected this line after the reading. Shown on screen, because what a human typed
  /// and what the camera understood should never look the same.
  final bool edited;

  /// A corrected line. The total is always recomputed from quantity × price rather than carried
  /// over: a hand-corrected line that still totals to the misread figure is worse than no
  /// correction at all.
  NotaLine corrected({String? rawText, num? qty, int? unitPrice}) {
    final q = qty ?? this.qty;
    final p = unitPrice ?? this.unitPrice;
    return NotaLine(
      rawText: rawText ?? this.rawText,
      qty: q,
      unitPrice: p,
      lineTotal: (q == null || p == null) ? null : (q * p).round(),
      edited: true,
    );
  }

  factory NotaLine.fromJson(Map<String, dynamic> j) => NotaLine(
        rawText: (j['rawText'] as String?) ?? '',
        qty: j['qty'] as num?,
        unitPrice: (j['unitPrice'] as num?)?.toInt(),
        lineTotal: (j['lineTotal'] as num?)?.toInt(),
      );
}

/// What a cashier typed into the price box, as rupiah.
///
/// Digits only: on a nota the price is written "28.000", and a dot there is a thousands separator,
/// never a decimal point. Reading it as 28.0 would undercharge by a factor of a thousand.
/// An empty or digitless box is null — "still not readable" — and never zero.
int? parseRupiahInput(String s) {
  final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : int.tryParse(digits);
}

/// What a cashier typed into the quantity box.
///
/// Here a comma or a dot IS a decimal point, because a nota can say 1,5 kg. Null when it is not a
/// number at all, so a typo cannot quietly become a quantity.
num? parseQtyInput(String s) {
  final t = s.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final n = num.tryParse(t);
  return (n == null || n < 0) ? null : n;
}

class NotaReading {
  const NotaReading({
    required this.items,
    required this.unclear,
    required this.confidence,
    required this.model,
    required this.latencyMs,
    required this.raw,
    this.notaNumber,
    this.notaDate,
    this.customerName,
    this.total,
  });

  final String? notaNumber;

  /// Parsed from the server's ISO `yyyy-mm-dd`; null if the date wasn't readable.
  final DateTime? notaDate;
  final String? customerName;
  final List<NotaLine> items;

  /// The total as written — null when it isn't on the paper.
  final int? total;

  /// Fields the reader flagged as uncertain, in its own words.
  final List<String> unclear;
  final int confidence;
  final String model;
  final int latencyMs;

  /// The untouched response, shown in the debug panel.
  final Map<String, dynamic> raw;

  /// Sum of the line totals that could be read — shown next to the written total so a mismatch is
  /// visible, never used in place of it.
  int? get linesSum {
    final totals = items.map((l) => l.lineTotal).whereType<int>().toList();
    if (totals.isEmpty) return null;
    return totals.fold<int>(0, (a, b) => a + b);
  }

  /// What the lines come to, minus what the paper claims. Positive means the paper under-totals
  /// its own lines, which is the common direction: whoever added it up dropped an item.
  ///
  /// Null when there is nothing to compare, and null when they agree — a difference of zero is
  /// not a difference worth a word on screen.
  int? get totalDifference {
    final sum = linesSum;
    if (sum == null || total == null || sum == total) return null;
    return sum - total!;
  }

  /// Whether a human has corrected any line of this reading.
  bool get hasEdits => items.any((l) => l.edited);

  /// The same reading with one line replaced.
  NotaReading withLine(int index, NotaLine line) {
    final next = [...items];
    next[index] = line;
    return NotaReading(
      items: next,
      unclear: unclear,
      confidence: confidence,
      model: model,
      latencyMs: latencyMs,
      raw: raw,
      notaNumber: notaNumber,
      notaDate: notaDate,
      customerName: customerName,
      total: total,
    );
  }

  factory NotaReading.fromJson(Map<String, dynamic> j) => NotaReading(
        notaNumber: j['notaNumber'] as String?,
        notaDate: j['notaDate'] == null ? null : DateTime.tryParse(j['notaDate'] as String),
        customerName: j['customerName'] as String?,
        items: ((j['items'] as List?) ?? const [])
            .map((e) => NotaLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (j['total'] as num?)?.toInt(),
        unclear: ((j['unclear'] as List?) ?? const []).map((e) => e.toString()).toList(),
        confidence: (j['confidence'] as num?)?.toInt() ?? 0,
        model: (j['model'] as String?) ?? '',
        latencyMs: (j['latencyMs'] as num?)?.toInt() ?? 0,
        raw: j,
      );
}

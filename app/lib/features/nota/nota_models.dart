/// What the server read off a photographed nota. Mirrors `NotaReadResult` on the server.
///
/// Every field can be null: the reader is told to leave a blank rather than guess, and the
/// screen shows a blank as "not readable" instead of a fake zero.
class NotaLine {
  const NotaLine({required this.rawText, this.qty, this.unitPrice, this.lineTotal});

  /// Exactly as written on the paper, abbreviations included.
  final String rawText;
  final num? qty;
  final int? unitPrice;
  final int? lineTotal;

  factory NotaLine.fromJson(Map<String, dynamic> j) => NotaLine(
        rawText: (j['rawText'] as String?) ?? '',
        qty: j['qty'] as num?,
        unitPrice: (j['unitPrice'] as num?)?.toInt(),
        lineTotal: (j['lineTotal'] as num?)?.toInt(),
      );
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

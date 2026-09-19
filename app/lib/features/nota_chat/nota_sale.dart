/// Turning a nota reading into a sale (specs/009-nota-reading-mode), as pure Dart.
///
/// No Flutter imports: what gets charged from a given reading is a money rule, so it is decided
/// here and tested directly — the chat screen only shows it.
library;

import '../calculator/nota_calculator.dart' show kMaxNotaAmount;
import '../nota/nota_models.dart';

/// Server limits, mirrored so a long reading is trimmed here instead of refused there.
const int kNotaLabelMax = 120; // MAX_OPEN_AMOUNT_LABEL in server/src/common/business-size.ts
const int kNotaNumberMax = 40;
const int kNotaCustomerMax = 80;
const int kNotaNoteMax = 1000;

/// One line that will be charged: the words as written, and the price as written.
class NotaSaleLine {
  final String label;
  final int amount;
  const NotaSaleLine(this.label, this.amount);
}

/// What confirming a reading would record.
class NotaSalePlan {
  /// The charged lines, one open-amount line each.
  final List<NotaSaleLine> lines;

  /// Lines as written that carry no price ("A/J FREE", "31 pc") — shown, never charged.
  final List<String> notCharged;

  /// The total written on the paper, if it was readable.
  final int? writtenTotal;

  /// True when no line carried a price and the sale is the written total as a single line.
  final bool usesWrittenTotal;

  /// When [usesWrittenTotal], the lines as written: they describe what the total paid for.
  final List<String> describedByTotal;

  /// What the reader flagged as unclear ("tanggal", "jumlah pc").
  final List<String> unclear;

  const NotaSalePlan({
    required this.lines,
    required this.notCharged,
    required this.writtenTotal,
    required this.usesWrittenTotal,
    this.describedByTotal = const [],
    this.unclear = const [],
  });

  /// The transaction note: everything on the paper that is NOT a charged line, so none of it is
  /// silently lost — lines without a price, the lines a written total covers, and whatever the
  /// reader could not make out. Null when there is nothing to keep.
  ///
  /// Written in Indonesian whatever the app's language: it is part of the merchant's record, read
  /// later in Riwayat and on the portal, not a label in the current UI.
  String? get note {
    final parts = [
      if (notCharged.isNotEmpty) 'Tidak dihitung: ${notCharged.join("; ")}',
      if (describedByTotal.isNotEmpty) 'Rincian: ${describedByTotal.join("; ")}',
      if (unclear.isNotEmpty) 'Kurang jelas: ${unclear.join("; ")}',
    ];
    return parts.isEmpty ? null : _clip(parts.join('\n'), kNotaNoteMax);
  }

  int get linesTotal => lines.fold(0, (s, l) => s + l.amount);

  /// Nothing priced and no total: there is nothing to charge.
  bool get canRecord => lines.isNotEmpty;

  /// The paper's own arithmetic disagrees with its lines. Shown to the cashier before confirming;
  /// the server always totals the lines (Constitution III), so the lines win and that is said.
  bool get totalsDisagree =>
      !usesWrittenTotal && writtenTotal != null && lines.isNotEmpty && writtenTotal != linesTotal;

  factory NotaSalePlan.from(NotaReading r) {
    final lines = <NotaSaleLine>[];
    final notCharged = <String>[];
    for (var i = 0; i < r.items.length; i++) {
      final item = r.items[i];
      final text = item.rawText.trim();
      final amount = notaLineAmount(item);
      if (amount == null) {
        if (text.isNotEmpty) notCharged.add(text);
        continue;
      }
      lines.add(NotaSaleLine(_clip(text.isEmpty ? 'Baris ${i + 1}' : text, kNotaLabelMax), amount));
    }

    // Some notas price only the whole: the lines say what was done, the total says what it costs.
    // Then the sale is that total as one line, rather than a nota nobody can charge.
    final total = r.total;
    final unclear = [for (final u in r.unclear) if (u.trim().isNotEmpty) u.trim()];
    if (lines.isEmpty && total != null && total > 0 && total <= kMaxNotaAmount) {
      final label = r.notaNumber == null ? 'Total nota' : 'Nota #${r.notaNumber}';
      return NotaSalePlan(
        lines: [NotaSaleLine(_clip(label, kNotaLabelMax), total)],
        notCharged: const [],
        writtenTotal: total,
        usesWrittenTotal: true,
        describedByTotal: notCharged,
        unclear: unclear,
      );
    }
    return NotaSalePlan(
      lines: lines,
      notCharged: notCharged,
      writtenTotal: total,
      usesWrittenTotal: false,
      unclear: unclear,
    );
  }

  /// The `POST /orders` body. No `payment` key on purpose: that is what makes it an OPEN
  /// transaction, settled later through the ordinary settle flow. Totals are never sent — the
  /// server computes them from the lines.
  Map<String, dynamic> payload({
    required String clientOrderId,
    required String outletId,
    required String openAmountVariantId,
    String? deviceId,
    String? notaNumber,
    String? customerName,
  }) {
    final number = notaNumber?.trim();
    final customer = customerName?.trim();
    return {
      'clientOrderId': clientOrderId,
      'outletId': outletId,
      if (deviceId != null) 'deviceId': deviceId,
      'type': 'RETAIL',
      if (number != null && number.isNotEmpty) 'notaNumber': _clip(number, kNotaNumberMax),
      if (customer != null && customer.isNotEmpty) 'customerName': _clip(customer, kNotaCustomerMax),
      if (note != null) 'note': note,
      'lines': [
        for (final l in lines)
          {'variantId': openAmountVariantId, 'qty': 1, 'amount': l.amount, 'label': l.label},
      ],
    };
  }
}

/// A line's price as written: its line total, or — when only the unit price and quantity were
/// written — their product. Anything unreadable, zero, or beyond the ceiling is not a price.
int? notaLineAmount(NotaLine l) {
  final written = l.lineTotal ??
      (l.unitPrice != null && l.qty != null ? (l.unitPrice! * l.qty!).round() : null);
  if (written == null || written <= 0 || written > kMaxNotaAmount) return null;
  return written;
}

String _clip(String s, int max) => s.length <= max ? s : s.substring(0, max);

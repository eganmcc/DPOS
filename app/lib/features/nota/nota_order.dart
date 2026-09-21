/// Turning a photographed nota into catalogue lines — pure Dart, no Flutter.
///
/// The nota is read, then every line is checked against the catalogue exactly the way a spoken
/// line is (`checkItem`, the voice matcher), so the till has one notion of "is this on the menu,
/// and is there enough of it" whatever the lines arrived by.
///
/// **The shop's price is what gets charged, not the paper's.** A catalogue merchant cannot be
/// charged a written amount — the server refuses open amounts outside calculator and nota-reading
/// merchants — so the handwritten price is only compared, and a difference is shown on the line.
/// It does not block Selesai, for the same reason short stock doesn't: the cashier can see both.
library;

import '../../data/models.dart';
import '../stt/stt_stock_check.dart';
import 'nota_models.dart';

/// One line of a nota, checked against the catalogue.
class NotaOrderLine {
  const NotaOrderLine({
    required this.check,
    required this.rawText,
    this.writtenUnitPrice,
    this.qtyUnreadable = false,
  });

  /// The catalogue's verdict — same type, same statuses as a spoken line.
  final SttStockCheck check;

  /// Exactly as written on the paper; shown when the line matched nothing, so the cashier can see
  /// what the reader saw.
  final String rawText;

  /// The price of one, as written on the nota — null when none was written or it can't be derived.
  /// Compared, never charged.
  final int? writtenUnitPrice;

  /// The quantity on the paper was not a whole number of at least one. The line is kept (so it is
  /// visible) but blocks Selesai: a catalogue line cannot be sold as 1.5 of something.
  final bool qtyUnreadable;

  int get qty => check.qty;

  /// The shop's price — what is charged.
  int get unitPrice => check.variant?.price ?? 0;
  int get lineTotal => unitPrice * qty;

  bool get notFound => check.status == SttStockStatus.notFound;

  /// A line nobody can be charged for. Same rule as voice (not in the catalogue), plus a quantity
  /// that can't be sold. Unavailable and short-stock lines are flagged but do not block — as in voice.
  bool get blocks => qtyUnreadable || notFound;

  /// The paper's price is not the shop's. Shown, never charged, never blocking.
  bool get priceDiffers =>
      writtenUnitPrice != null && check.variant != null && writtenUnitPrice != unitPrice;
}

/// Tokens that are how a price or count is written, not part of an item's name.
const _notNameWords = {'rp', 'x', 'rb', 'ribu', 'k', 'pc', 'pcs'};

/// A written count or price: "2", "30", "000" (from "30.000"), "4rb", "15k", "2x", "x2", "3pcs".
final _countOrPrice = RegExp(r'^(\d+(rb|k|ribu|x|pc|pcs)?|x\d+)$');

/// The item words of a nota line: the reader returns qty and price in their own fields, but the
/// raw text is "exactly as written" and still carries them ("2 nasgor 30.000"). Numbers and money
/// shorthand are dropped so they cannot sway the match; if nothing is left, the text is kept as is.
String notaItemWords(String rawText) {
  final words = normaliseSpoken(rawText).split(' ').where((w) => w.isNotEmpty);
  final kept = words
      .where((w) => !_countOrPrice.hasMatch(w) && !_notNameWords.contains(w))
      .toList();
  return kept.isEmpty ? normaliseSpoken(rawText) : kept.join(' ');
}

/// A whole quantity of at least one, or null. A line with no count written is one of it.
int? _wholeQty(num? q) {
  if (q == null) return 1;
  if (q < 1 || q != q.roundToDouble()) return null;
  return q.toInt();
}

/// The unit price as written: the unit price itself, or the line total divided by a whole quantity
/// when that divides exactly. Anything else is not a price we can compare against.
int? _writtenUnitPrice(NotaLine l, int? qty) {
  final unit = l.unitPrice;
  if (unit != null && unit > 0) return unit;
  final total = l.lineTotal;
  if (total == null || total <= 0 || qty == null || qty < 1) return null;
  return total % qty == 0 ? total ~/ qty : null;
}

/// Every readable line of [reading], checked against [products]. Blank lines are dropped; every
/// other line is kept, matched or not, so nothing on the paper silently disappears.
List<NotaOrderLine> stageNotaReading(NotaReading reading, List<Product> products) {
  final out = <NotaOrderLine>[];
  for (final l in reading.items) {
    if (l.rawText.trim().isEmpty) continue;
    final qty = _wholeQty(l.qty);
    out.add(NotaOrderLine(
      check: checkItem(qty: qty ?? 1, item: notaItemWords(l.rawText), products: products),
      rawText: l.rawText.trim(),
      writtenUnitPrice: _writtenUnitPrice(l, qty),
      qtyUnreadable: qty == null,
    ));
  }
  return out;
}

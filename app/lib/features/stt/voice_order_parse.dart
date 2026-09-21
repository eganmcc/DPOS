/// Reading a spoken line as an item and a PRICE — the calculator half of voice ordering.
///
/// Pure Dart, no Flutter, because this decides what a customer is charged.
///
/// The rule here is the opposite of the inventory mode's, which is worth saying out loud: there,
/// "nasi goreng dua" means two of them and the price comes from the catalogue. Here there is no
/// catalogue, so "Pecel lele 100" means one pecel lele at a hundred — the number is the money.
library;

import 'stt_stock_check.dart' show normaliseSpoken, numberRuns, spokenNumber;

/// Below this, a bare number is heard as thousands: a cashier says "seratus" and means 100.000.
/// At or above it the number is taken as spoken, so "25000" and "dua puluh lima ribu" both mean
/// 25.000 and are not multiplied again.
const int kThousandsBelow = 1000;

/// The server's ceiling for an open-amount line (`MAX_OPEN_AMOUNT`). Mirrored so a misheard
/// number is visible on screen as an impossible price rather than as a rejected order.
const int kMaxSpokenPrice = 100000000;

/// One line of a spoken bill: what it is, how many, and what each costs.
class PricedLine {
  /// The words that named the item — what the receipt will say, via the line's `label`.
  final String label;
  final int qty;

  /// Rupiah each, already resolved from how it was said.
  final int price;

  const PricedLine({required this.label, required this.qty, required this.price});

  int get total => qty * price;

  /// A line nobody can be charged for: no name, or no price said. Shown, not dropped — a line
  /// that vanishes is how an order quietly loses an item.
  bool get isIncomplete => label.trim().isEmpty || price <= 0;

  @override
  bool operator ==(Object other) =>
      other is PricedLine && other.label == label && other.qty == qty && other.price == price;

  @override
  int get hashCode => Object.hash(label, qty, price);

  @override
  String toString() => 'PricedLine($label, $qty × $price)';
}

/// The submit payload for a spoken open-amount sale.
///
/// A sibling of `buildNotaPayload` (the keypad) and the nota chat's own builder: each surface
/// owns the shape it sends, and all three land on the same server that recomputes every figure.
///
/// **Quantity is expanded into separate lines**, because the server requires `qty: 1` on an
/// open-amount line ([money.ts:139]) — an amount is a price for ONE thing. Two pecel lele at
/// 100.000 is two lines of 100.000, which is also what the receipt should read.
Map<String, dynamic> buildVoiceSalePayload({
  required String clientOrderId,
  required String outletId,
  required String openAmountVariantId,
  required List<PricedLine> lines,
  required int tendered,
  String? deviceId,
}) =>
    {
      'clientOrderId': clientOrderId,
      'outletId': outletId,
      if (deviceId != null) 'deviceId': deviceId,
      'type': 'RETAIL',
      'lines': [
        for (final l in lines)
          if (!l.isIncomplete)
            for (var i = 0; i < l.qty; i++)
              {
                'variantId': openAmountVariantId,
                'qty': 1,
                'amount': l.price,
                'label': clipLabel(l.label),
              },
      ],
      'payment': {'method': 'CASH', 'tendered': tendered},
    };

/// `MAX_OPEN_AMOUNT_LABEL` in server/src/common/business-size.ts.
const int kVoiceLabelMax = 120;

String clipLabel(String s) {
  final t = s.trim();
  return t.length <= kVoiceLabelMax ? t : t.substring(0, kVoiceLabelMax);
}

/// Turns a number as it was SAID into rupiah.
///
/// "seratus" and "100" are both 100.000 in a warung; "seratus ribu" and "100000" are the same
/// amount said the long way, and must not be multiplied twice.
int spokenPrice(int number) {
  final rupiah = number < kThousandsBelow ? number * 1000 : number;
  return rupiah > kMaxSpokenPrice ? kMaxSpokenPrice : rupiah;
}

/// Reads one spoken utterance as one or more priced lines.
///
/// The shape it expects is how an order is actually read out: `[qty] item price`, repeated.
/// A number where a NAME should start is a quantity; a number that ends a name is its price.
/// So "dua pecel lele 100" is two at a hundred, and "pecel lele 100 es teh 5" is two lines.
List<PricedLine> parsePricedLines(String utterance) {
  final words = normaliseSpoken(utterance).split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const [];

  final runs = numberRuns(words);
  // Nothing numeric at all: they named an item and no price. Kept, and shown as incomplete —
  // the cashier says the price again rather than wondering where the item went.
  if (runs.isEmpty) {
    return [PricedLine(label: words.join(' '), qty: 1, price: 0)];
  }

  final out = <PricedLine>[];
  var start = 0;
  int? pendingQty;

  for (final r in runs) {
    final value = spokenNumber(words.sublist(r[0], r[1])) ?? 0;
    // A number standing where a name should begin is how many, not how much.
    if (r[0] == start) {
      pendingQty = value < 1 ? 1 : value;
      start = r[1];
      continue;
    }
    out.add(PricedLine(
      label: words.sublist(start, r[0]).join(' '),
      qty: pendingQty ?? 1,
      price: spokenPrice(value),
    ));
    pendingQty = null;
    start = r[1];
  }

  // Words after the last price named an item whose price never arrived.
  if (start < words.length) {
    out.add(PricedLine(
      label: words.sublist(start).join(' '),
      qty: pendingQty ?? 1,
      price: 0,
    ));
  }
  return out;
}

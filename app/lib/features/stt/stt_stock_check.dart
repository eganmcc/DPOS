/// Checking a spoken line against the catalog — pure Dart, no Flutter.
///
/// "nasi goreng dua" has to become a quantity, an item, and an answer: is it on the menu at all,
/// and is there enough of it? Getting that wrong in a till is worse than not hearing it, so the
/// rules live here where they are tested directly rather than through a microphone.
library;

import '../../data/models.dart';

enum SttStockStatus {
  /// Nothing in the catalog resembles what was said.
  notFound,

  /// Found, but the merchant has switched it off.
  unavailable,

  /// Tracked and nothing left.
  outOfStock,

  /// Tracked, some left, but fewer than were asked for.
  insufficient,

  /// Can be sold.
  ok,
}

/// What the catalog says about one spoken line.
class SttStockCheck {
  final SttStockStatus status;

  /// How many were asked for — 1 when no number was said.
  final int qty;

  /// The words taken to be the item, after the number was removed.
  final String spokenItem;

  /// The catalog item matched, when one was.
  final Product? product;
  final Variant? variant;

  const SttStockCheck({
    required this.status,
    required this.qty,
    required this.spokenItem,
    this.product,
    this.variant,
  });

  bool get isProblem => status != SttStockStatus.ok;

  /// What to call this on screen. A product with several variants is named WITH its variant,
  /// because "Ayam Geprek" alone does not say which one is about to be rung up.
  String get displayName {
    final p = product;
    if (p == null) return spokenItem;
    if (variant == null || p.variants.length < 2) return p.name;
    return '${p.name} ${variant!.name}';
  }

  /// On hand now; null when the item is not stock-tracked (i.e. unlimited).
  int? get remaining =>
      (variant == null || !variant!.trackInventory) ? null : (variant!.stock ?? 0);
}

/// Indonesian number words, enough for the quantities a cashier says out loud.
const Map<String, int> _units = {
  'nol': 0, 'satu': 1, 'se': 1, 'dua': 2, 'tiga': 3, 'empat': 4, 'lima': 5,
  'enam': 6, 'tujuh': 7, 'delapan': 8, 'sembilan': 9,
};

/// Reads a run of number words: "dua puluh lima" → 25, "sebelas" → 11, "seratus" → 100.
///
/// The mirror of `core/terbilang.dart`, which only goes the other way. Returns null when the words
/// are not a number at all — a wrong quantity is worse than no quantity.
int? spokenNumber(List<String> words) {
  if (words.isEmpty) return null;
  // Indonesian numbers are built in groups, not digit by digit: "dua puluh lima" is (2×10)+5.
  // `pending` is the bare unit just heard, `tens` the tens of the group, `total` what is settled.
  var total = 0;
  var tens = 0;
  var pending = 0;
  var sawAny = false;

  for (final raw in words) {
    final w = raw.toLowerCase();
    if (w.isEmpty) continue;

    if (_units.containsKey(w)) {
      pending = _units[w]!;
      sawAny = true;
      continue;
    }
    if (w == 'sepuluh') {
      tens = 10;
      pending = 0;
      sawAny = true;
      continue;
    }
    if (w == 'sebelas') {
      tens = 11;
      pending = 0;
      sawAny = true;
      continue;
    }
    if (w == 'belas') {
      if (!sawAny) return null;
      tens = 10 + pending; // "lima belas" = 15
      pending = 0;
      continue;
    }
    if (w == 'puluh') {
      if (!sawAny) return null;
      tens = (pending == 0 ? 1 : pending) * 10; // "dua puluh" = 20
      pending = 0;
      continue;
    }
    if (w == 'seratus' || w == 'ratus') {
      final base = w == 'seratus' ? 1 : (pending == 0 ? 1 : pending);
      total += base * 100;
      tens = 0;
      pending = 0;
      sawAny = true;
      continue;
    }
    if (w == 'seribu' || w == 'ribu') {
      final group = total + tens + pending;
      total = (w == 'seribu' || group == 0 ? 1 : group) * 1000;
      tens = 0;
      pending = 0;
      sawAny = true;
      continue;
    }
    final digits = int.tryParse(w);
    if (digits != null) {
      pending = digits;
      sawAny = true;
      continue;
    }
    return null; // not a number word
  }
  if (!sawAny) return null;
  return total + tens + pending;
}

/// Lowercase, punctuation out, single spaces. Shared with the voice order parser, which has to
/// see exactly the same words this does.
String normaliseSpoken(String s) => _normalise(s);

/// Every maximal run of number words in [words], as `[start, endExclusive)`.
///
/// A run, not a word, because "dua puluh lima" is one number. Shared: splitting an order into
/// items and splitting one into a price both turn on where the numbers are.
List<List<int>> numberRuns(List<String> words) {
  final runs = <List<int>>[];
  var i = 0;
  while (i < words.length) {
    if (spokenNumber([words[i]]) == null) {
      i++;
      continue;
    }
    var j = i + 1;
    while (j < words.length && spokenNumber(words.sublist(i, j + 1)) != null) {
      j++;
    }
    runs.add([i, j]);
    i = j;
  }
  return runs;
}

String _normalise(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Splits "nasi goreng dua" or "2 nasi goreng" into a quantity and the item words.
///
/// A number is only taken from the ENDS. "es teh dua" is two teas, but nobody orders a "dua" of
/// anything in the middle of a name, and grabbing one there would mangle items like "kopi 3 in 1".
({int qty, String item}) splitQuantity(String text) {
  final words = _normalise(text).split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return (qty: 1, item: '');

  // The LONGEST run of number words at the end wins: "dua puluh lima" is twenty-five, not five
  // with "dua puluh" left stuck on the item. Hence the ascending `from`, i.e. longest suffix first.
  for (var from = 1; from < words.length; from++) {
    final n = spokenNumber(words.sublist(from));
    if (n != null && n > 0) {
      return (qty: n, item: words.sublist(0, from).join(' '));
    }
  }
  // Then the start, longest prefix first for the same reason.
  for (var take = words.length - 1; take >= 1; take--) {
    final n = spokenNumber(words.sublist(0, take));
    if (n != null && n > 0) {
      return (qty: n, item: words.sublist(take).join(' '));
    }
  }
  return (qty: 1, item: words.join(' '));
}

/// Splits one spoken line into the several items it may hold.
///
/// A cashier does not pause between items: "air mineral 1 ayam bakar 2" arrives from the
/// recognizer as ONE utterance, and read as one it becomes a nonsense item called "air mineral 1
/// ayam bakar". The quantities are the punctuation — each number closes an item (or opens one,
/// when the speaker puts the number first), so they are what this splits on.
List<({int qty, String item})> splitUtterance(String text) {
  final words = _normalise(text).split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const [];

  final runs = numberRuns(words);

  // No number at all means nothing to split on, and the single-item rules still apply. ONE number
  // is not enough to stay out of here, though: "air mineral 2 ayam bakar" is two items.
  if (runs.isEmpty) {
    final one = splitQuantity(text);
    return one.item.isEmpty ? const [] : [one];
  }

  final out = <({int qty, String item})>[];
  int qtyOf(List<int> r) {
    final n = spokenNumber(words.sublist(r[0], r[1])) ?? 1;
    return n < 1 ? 1 : n; // "nol nasi goreng" is not an order for none of it
  }

  if (runs.first[0] == 0) {
    // "dua nasi goreng satu es teh" — the number opens each item.
    for (var k = 0; k < runs.length; k++) {
      final end = k + 1 < runs.length ? runs[k + 1][0] : words.length;
      final item = words.sublist(runs[k][1], end);
      if (item.isNotEmpty) out.add((qty: qtyOf(runs[k]), item: item.join(' ')));
    }
  } else {
    // "air mineral satu ayam bakar dua" — the number closes each item.
    var start = 0;
    for (final r in runs) {
      final item = words.sublist(start, r[0]);
      if (item.isNotEmpty) out.add((qty: qtyOf(r), item: item.join(' ')));
      start = r[1];
    }
    // A trailing item with no number said is one of it.
    if (start < words.length) out.add((qty: 1, item: words.sublist(start).join(' ')));
  }
  return out.isEmpty ? [splitQuantity(text)] : out;
}

/// The best catalog match for some spoken words, or null.
///
/// Exact first, then one containing the other, then the item sharing the most words. The threshold
/// exists so a stray word does not "match" an unrelated product: half of the item's own name must
/// be present, otherwise it is reported as not found and a human decides.
Product? matchProduct(String spokenItem, List<Product> products) {
  final spoken = _normalise(spokenItem);
  if (spoken.isEmpty || products.isEmpty) return null;
  final spokenWords = spoken.split(' ').toSet();

  Product? best;
  var bestScore = 0.0;
  var bestShared = 0;
  for (final p in products) {
    final name = _normalise(p.name);
    if (name.isEmpty) continue;
    if (name == spoken) return p;

    final nameWords = name.split(' ').toSet();
    final shared = nameWords.intersection(spokenWords).length;
    var score = shared / nameWords.length;
    // A containment either way is strong evidence, whatever the word counts say — but only when
    // the contained side is substantial. "in" sits inside "Kopi 3 in 1" and means nothing by it.
    final shorter = name.length <= spoken.length ? name : spoken;
    final contained = spoken.contains(name) || name.contains(spoken);
    if (contained && (shorter.contains(' ') || shorter.length >= 5)) {
      score = score < 0.9 ? 0.9 : score;
    }
    // On a tie the MORE SPECIFIC name wins — more of the spoken words accounted for. Otherwise
    // "Ayam Geprek" and "Ayam Geprek Keju" both score 1.0 and catalogue order decides, which is
    // not a decision anybody made.
    if (score > bestScore || (score == bestScore && shared > bestShared)) {
      bestScore = score;
      bestShared = shared;
      best = p;
    }
  }
  return bestScore >= 0.5 ? best : null;
}

/// The variant the cashier actually named, if they named one.
///
/// "ayam geprek keju" is a product AND a variant: the product's own words identify the dish, and
/// what is left over — "keju" — says which one. Dropping the leftovers and taking the first
/// available variant is how an Ayam Geprek Keju quietly became an Ayam Geprek Original, at a
/// different price and out of a different stock count.
Variant? matchVariant(String spokenItem, Product product) {
  if (product.variants.length < 2) return null;
  final spoken = _normalise(spokenItem).split(' ').where((w) => w.isNotEmpty).toSet();
  final residual = spoken.difference(_normalise(product.name).split(' ').toSet());
  if (residual.isEmpty) return null;

  Variant? best;
  var bestScore = 0.0;
  for (final v in product.variants) {
    final words = _normalise(v.name).split(' ').where((w) => w.isNotEmpty).toSet();
    if (words.isEmpty) continue;
    final score = words.intersection(residual).length / words.length;
    if (score > bestScore) {
      bestScore = score;
      best = v;
    }
  }
  // Below the threshold the leftovers were not a variant name at all — filler, a modifier, a
  // misheard word — and inventing a variant from them would be worse than using the default.
  return bestScore >= 0.5 ? best : null;
}

/// The sellable variant of a product: the first available one. Used when the cashier named no
/// variant, in which case this is the one the till would ring up anyway.
Variant? sellableVariant(Product p) {
  for (final v in p.variants) {
    if (v.isAvailable) return v;
  }
  return p.variants.isEmpty ? null : p.variants.first;
}

/// Check a whole spoken line, which may hold several items, against the catalog.
///
/// Where the split is ambiguous the CATALOG decides, because it is the only evidence available.
/// "kopi 3 in 1" reads as two items by the rule above, but neither half is anything the shop
/// sells while the whole line is — so the whole line wins. Two real items, on the other hand,
/// beat one imaginary one.
List<SttStockCheck> checkUtterance(String utterance, List<Product> products) {
  final single = checkAgainstCatalog(utterance, products);
  final parts = splitUtterance(utterance);
  if (parts.length < 2) return [single];

  final multi = [
    for (final p in parts) _check(qty: p.qty, item: p.item, products: products),
  ];
  final matched = multi.where((c) => c.status != SttStockStatus.notFound).length;
  if (matched >= 2) return multi;
  return single.status == SttStockStatus.notFound ? multi : [single];
}

/// Check one spoken line, read as a single item, against the catalog.
SttStockCheck checkAgainstCatalog(String utterance, List<Product> products) {
  final split = splitQuantity(utterance);
  return _check(qty: split.qty, item: split.item, products: products);
}

/// One item and one quantity, already separated, against the catalog.
///
/// Public because a quantity can arrive AFTER its item: the recognizer sometimes resets its
/// buffer between the two, and the line then has to be rebuilt with the number that followed —
/// rebuilt, not patched, because the verdict depends on the quantity.
SttStockCheck checkItem({
  required int qty,
  required String item,
  required List<Product> products,
}) =>
    _check(qty: qty, item: item, products: products);

SttStockCheck _check({
  required int qty,
  required String item,
  required List<Product> products,
}) {
  final split = (qty: qty, item: item);
  final product = matchProduct(split.item, products);
  if (product == null) {
    return SttStockCheck(
      status: SttStockStatus.notFound,
      qty: split.qty,
      spokenItem: split.item,
    );
  }
  // What they said beats what is first in the list — and if they named an unavailable variant,
  // the answer is "not available", not a silent swap to one that is.
  final variant = matchVariant(split.item, product) ?? sellableVariant(product);
  if (!product.isAvailable || variant == null || !variant.isAvailable) {
    return SttStockCheck(
      status: SttStockStatus.unavailable,
      qty: split.qty,
      spokenItem: split.item,
      product: product,
      variant: variant,
    );
  }
  if (variant.trackInventory) {
    final left = variant.stock ?? 0;
    if (left <= 0) {
      return SttStockCheck(
        status: SttStockStatus.outOfStock,
        qty: split.qty,
        spokenItem: split.item,
        product: product,
        variant: variant,
      );
    }
    if (left < split.qty) {
      return SttStockCheck(
        status: SttStockStatus.insufficient,
        qty: split.qty,
        spokenItem: split.item,
        product: product,
        variant: variant,
      );
    }
  }
  return SttStockCheck(
    status: SttStockStatus.ok,
    qty: split.qty,
    spokenItem: split.item,
    product: product,
    variant: variant,
  );
}

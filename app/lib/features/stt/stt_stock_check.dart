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
  for (final p in products) {
    final name = _normalise(p.name);
    if (name.isEmpty) continue;
    if (name == spoken) return p;

    final nameWords = name.split(' ').toSet();
    final shared = nameWords.intersection(spokenWords).length;
    var score = shared / nameWords.length;
    // A containment either way is strong evidence, whatever the word counts say.
    if (spoken.contains(name) || name.contains(spoken)) score = score < 0.9 ? 0.9 : score;
    if (score > bestScore) {
      bestScore = score;
      best = p;
    }
  }
  return bestScore >= 0.5 ? best : null;
}

/// The sellable variant of a product: the first available one, since the lab is checking whether
/// the ITEM can be sold, not which size was meant.
Variant? sellableVariant(Product p) {
  for (final v in p.variants) {
    if (v.isAvailable) return v;
  }
  return p.variants.isEmpty ? null : p.variants.first;
}

/// Check one spoken line against the catalog.
SttStockCheck checkAgainstCatalog(String utterance, List<Product> products) {
  final split = splitQuantity(utterance);
  final product = matchProduct(split.item, products);
  if (product == null) {
    return SttStockCheck(
      status: SttStockStatus.notFound,
      qty: split.qty,
      spokenItem: split.item,
    );
  }
  final variant = sellableVariant(product);
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

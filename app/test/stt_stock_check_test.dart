import 'package:dpos/data/models.dart';
import 'package:dpos/features/stt/stt_stock_check.dart';
import 'package:flutter_test/flutter_test.dart';

/// Turning a spoken line into "can I sell this?" — the rules, without a microphone.
void main() {
  Variant v(String name, {bool tracked = true, int? stock, bool available = true}) => Variant(
        id: 'v-$name',
        name: name,
        price: 10000,
        sku: null,
        isAvailable: available,
        trackInventory: tracked,
        stock: stock,
      );

  Product p(String name, List<Variant> variants, {bool available = true}) => Product(
        id: 'p-$name',
        name: name,
        categoryName: 'Cat',
        isAvailable: available,
        variants: variants,
        modifierGroups: const [],
      );

  final catalog = [
    p('Nasi Goreng', [v('Porsi', stock: 5)]),
    p('Es Teh Manis', [v('Gelas', stock: 0)]),
    p('Kopi Tubruk', [v('Gelas', tracked: false)]),
    p('Ayam Goreng', [v('Porsi', stock: 2)], available: false),
    // The shape that actually ships (server/prisma/menu-data.ts): one product, several variants,
    // the first of them the default.
    p('Ayam Geprek', [v('Original', stock: 4), v('Keju', stock: 9)]),
    p('Bakso', [v('Biasa', stock: 6), v('Spesial', stock: 0)]),
  ];

  group('hearing a quantity', () {
    test('reads Indonesian number words', () {
      expect(spokenNumber(['dua']), 2);
      expect(spokenNumber(['sepuluh']), 10);
      expect(spokenNumber(['sebelas']), 11);
      expect(spokenNumber(['lima', 'belas']), 15);
      expect(spokenNumber(['dua', 'puluh', 'lima']), 25);
      expect(spokenNumber(['seratus']), 100);
      expect(spokenNumber(['dua', 'ratus', 'lima', 'puluh']), 250);
    });

    test('reads digits, because the recognizer often returns those instead', () {
      expect(spokenNumber(['3']), 3);
      expect(splitQuantity('nasi goreng 2').qty, 2);
    });

    test('is not a number at all when the words are not numbers', () {
      expect(spokenNumber(['nasi']), isNull);
      expect(spokenNumber([]), isNull);
    });

    test('takes the quantity from either end and leaves the item behind', () {
      expect(splitQuantity('nasi goreng dua'), (qty: 2, item: 'nasi goreng'));
      expect(splitQuantity('dua nasi goreng'), (qty: 2, item: 'nasi goreng'));
      expect(splitQuantity('es teh manis dua puluh lima'), (qty: 25, item: 'es teh manis'));
    });

    test('no number said means one', () {
      expect(splitQuantity('nasi goreng'), (qty: 1, item: 'nasi goreng'));
    });

    test('leaves a number INSIDE a name alone', () {
      // "kopi 3 in 1" is a product, not three coffees.
      expect(splitQuantity('kopi 3 in 1').item, contains('3'));
    });
  });

  group('several items said in one breath', () {
    // The phrase from the 20 Sep device run that arrived as a single nonsense item.
    test('a number closes each item', () {
      expect(splitUtterance('air mineral 1 ayam bakar 2'), [
        (qty: 1, item: 'air mineral'),
        (qty: 2, item: 'ayam bakar'),
      ]);
    });

    test('a number opens each item, when that is how it was said', () {
      expect(splitUtterance('2 nasi goreng 1 es teh'), [
        (qty: 2, item: 'nasi goreng'),
        (qty: 1, item: 'es teh'),
      ]);
    });

    test('spelled-out numbers split the same way', () {
      expect(splitUtterance('air mineral satu ayam bakar dua'), [
        (qty: 1, item: 'air mineral'),
        (qty: 2, item: 'ayam bakar'),
      ]);
    });

    test('a last item with no number said is one of it', () {
      expect(splitUtterance('air mineral 2 ayam bakar'), [
        (qty: 2, item: 'air mineral'),
        (qty: 1, item: 'ayam bakar'),
      ]);
    });

    test('one item stays one item', () {
      expect(splitUtterance('es teh manis dua puluh lima'), [
        (qty: 25, item: 'es teh manis'),
      ]);
      expect(splitUtterance('nasi goreng'), [(qty: 1, item: 'nasi goreng')]);
    });

    test('each item gets its own verdict', () {
      final checks = checkUtterance('nasi goreng 2 es teh manis 1', catalog);
      expect(checks.length, 2);
      expect(checks[0].product!.name, 'Nasi Goreng');
      expect(checks[0].status, SttStockStatus.ok);
      expect(checks[1].product!.name, 'Es Teh Manis');
      expect(checks[1].status, SttStockStatus.outOfStock, reason: 'sold out, said in the same breath');
    });

    test('the catalog decides when the split is ambiguous', () {
      // "kopi 3 in 1" reads as two items by the rule, but neither half is anything the shop
      // sells and the whole line is — so a product name that happens to contain numbers survives.
      final withBrand = [...catalog, p('Kopi 3 in 1', [v('Sachet', tracked: false)])];
      final checks = checkUtterance('kopi 3 in 1', withBrand);
      expect(checks.length, 1);
      expect(checks.single.product!.name, 'Kopi 3 in 1');
    });
  });

  group('naming a variant, not just a dish', () {
    test('the variant said is the variant checked', () {
      final c = checkAgainstCatalog('ayam geprek keju satu', catalog);
      expect(c.variant!.name, 'Keju', reason: 'not the default, which is Original');
      expect(c.remaining, 9, reason: "and its OWN stock, not the default variant's");
      expect(c.displayName, 'Ayam Geprek Keju');
    });

    test('the default is still the default when no variant is named', () {
      final c = checkAgainstCatalog('ayam geprek dua', catalog);
      expect(c.variant!.name, 'Original');
      expect(c.displayName, 'Ayam Geprek Original',
          reason: 'say which one is about to be rung up, even when nobody named it');
    });

    test('naming the default explicitly also works', () {
      expect(checkAgainstCatalog('ayam geprek original satu', catalog).variant!.name, 'Original');
    });

    test('a sold-out variant is sold out, even when another variant has stock', () {
      final c = checkAgainstCatalog('bakso spesial dua', catalog);
      expect(c.status, SttStockStatus.outOfStock);
      expect(c.displayName, 'Bakso Spesial');
    });

    test('leftover words that name no variant fall back to the default', () {
      // "mas" is talking to a person, not naming a cheese.
      final c = checkAgainstCatalog('bakso mas satu', catalog);
      expect(c.variant!.name, 'Biasa');
    });

    test('a single-variant product is named on its own', () {
      expect(checkAgainstCatalog('nasi goreng dua', catalog).displayName, 'Nasi Goreng');
    });

    test('two variants of the same dish in one breath stay apart', () {
      final checks = checkUtterance('ayam geprek keju 1 ayam geprek original 2', catalog);
      expect(checks.length, 2);
      expect(checks[0].variant!.name, 'Keju');
      expect(checks[1].variant!.name, 'Original');
      expect(checks[1].qty, 2);
    });
  });

  group('matching what was said to the catalog', () {
    test('finds the item however it was cased or punctuated', () {
      expect(matchProduct('NASI, GORENG', catalog)?.name, 'Nasi Goreng');
    });

    test('finds an item named inside a longer phrase', () {
      expect(matchProduct('satu nasi goreng spesial', catalog)?.name, 'Nasi Goreng');
    });

    test('refuses a weak match rather than guessing wrong', () {
      // "goreng" alone is half of two different products — too thin to bill someone for.
      expect(matchProduct('roti bakar', catalog), isNull);
    });

    test('an empty catalog matches nothing', () {
      expect(matchProduct('nasi goreng', const []), isNull);
    });
  });

  group('the answer a cashier needs', () {
    test('sellable, with stock left', () {
      final c = checkAgainstCatalog('nasi goreng dua', catalog);
      expect(c.status, SttStockStatus.ok);
      expect(c.qty, 2);
      expect(c.product!.name, 'Nasi Goreng');
      expect(c.remaining, 5);
      expect(c.isProblem, false);
    });

    test('not on the menu at all', () {
      // Not "bakso urat": this shop sells Bakso, so that is a real match with an unknown extra
      // word, which is a different case. Roti bakar it does not sell at all.
      final c = checkAgainstCatalog('roti bakar tiga', catalog);
      expect(c.status, SttStockStatus.notFound);
      expect(c.qty, 3);
      expect(c.product, isNull);
    });

    test('on the menu but sold out — and says how many are left', () {
      final c = checkAgainstCatalog('es teh manis dua', catalog);
      expect(c.status, SttStockStatus.outOfStock);
      expect(c.remaining, 0);
    });

    test('some left, but fewer than asked for', () {
      final c = checkAgainstCatalog('nasi goreng sepuluh', catalog);
      expect(c.status, SttStockStatus.insufficient);
      expect(c.qty, 10);
      expect(c.remaining, 5, reason: 'the cashier needs the real number, not just a refusal');
    });

    test('an untracked item is always sellable and reports no number', () {
      final c = checkAgainstCatalog('kopi tubruk lima', catalog);
      expect(c.status, SttStockStatus.ok);
      expect(c.remaining, isNull);
    });

    test('an item the merchant switched off is not sellable', () {
      final c = checkAgainstCatalog('ayam goreng satu', catalog);
      expect(c.status, SttStockStatus.unavailable);
    });

    test('exactly the remaining stock is still sellable', () {
      final c = checkAgainstCatalog('nasi goreng lima', catalog);
      expect(c.status, SttStockStatus.ok);
    });
  });
}

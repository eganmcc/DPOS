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
      final c = checkAgainstCatalog('bakso urat tiga', catalog);
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

import 'package:dpos/data/models.dart';
import 'package:dpos/features/nota/nota_models.dart';
import 'package:dpos/features/nota/nota_order.dart';
import 'package:dpos/features/stt/stt_stock_check.dart';
import 'package:flutter_test/flutter_test.dart';

/// A photographed nota becoming catalogue lines — the rules that decide what is charged.
void main() {
  Variant v(String name, int price, {bool tracked = false, int? stock, bool available = true}) =>
      Variant(
        id: 'v-$name-$price',
        name: name,
        price: price,
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
    p('Nasi Goreng', [v('Porsi', 15000)]),
    p('Es Teh Manis', [v('Gelas', 4000)]),
    p('Air Mineral', [v('Botol', 4000, tracked: true, stock: 1)]),
    p('Teh Botol', [v('Botol', 6000, tracked: true, stock: 0)]),
    p('Ayam Geprek', [v('Original', 18000), v('Keju', 22000)]),
    p('Bakwan', [v('Biji', 2000)], available: false),
  ];

  NotaReading nota(List<NotaLine> items) => NotaReading(
        items: items,
        unclear: const [],
        confidence: 90,
        model: 'test',
        latencyMs: 0,
        raw: const {},
      );

  List<NotaOrderLine> stage(List<NotaLine> items) => stageNotaReading(nota(items), catalog);

  group('what gets charged', () {
    test("the shop's price, never the paper's", () {
      final l = stage([const NotaLine(rawText: 'Nasi Goreng', qty: 2, unitPrice: 20000)]).single;
      expect(l.check.status, SttStockStatus.ok);
      expect(l.qty, 2);
      expect(l.unitPrice, 15000);
      expect(l.lineTotal, 30000);
    });

    test('a different written price is flagged, and does not block', () {
      final l = stage([const NotaLine(rawText: 'Nasi Goreng', qty: 2, unitPrice: 20000)]).single;
      expect(l.writtenUnitPrice, 20000);
      expect(l.priceDiffers, isTrue);
      expect(l.blocks, isFalse);
    });

    test('the same written price is not flagged', () {
      final l = stage([const NotaLine(rawText: 'Es Teh Manis', qty: 1, unitPrice: 4000)]).single;
      expect(l.priceDiffers, isFalse);
    });

    test('a unit price is derived from the line total when only that was written', () {
      final l = stage([const NotaLine(rawText: 'Es Teh Manis', qty: 3, lineTotal: 15000)]).single;
      expect(l.writtenUnitPrice, 5000);
      expect(l.priceDiffers, isTrue);
    });

    test('a line total that does not divide by the quantity is not a price to compare', () {
      final l = stage([const NotaLine(rawText: 'Es Teh Manis', qty: 3, lineTotal: 10000)]).single;
      expect(l.writtenUnitPrice, isNull);
      expect(l.priceDiffers, isFalse);
    });

    test('the variant the paper names is the variant charged', () {
      final l = stage([const NotaLine(rawText: 'Ayam Geprek Keju', qty: 1)]).single;
      expect(l.check.variant?.name, 'Keju');
      expect(l.unitPrice, 22000);
    });
  });

  group('quantities', () {
    test('a line with no count written is one of it', () {
      final l = stage([const NotaLine(rawText: 'Nasi Goreng')]).single;
      expect(l.qty, 1);
      expect(l.qtyUnreadable, isFalse);
    });

    test('a fraction cannot be sold from a catalogue — kept, flagged, and blocking', () {
      final l = stage([const NotaLine(rawText: 'Nasi Goreng', qty: 1.5)]).single;
      expect(l.qtyUnreadable, isTrue);
      expect(l.blocks, isTrue);
    });

    test('zero is not a quantity either', () {
      expect(stage([const NotaLine(rawText: 'Nasi Goreng', qty: 0)]).single.blocks, isTrue);
    });
  });

  group('matching the paper to the menu', () {
    test('counts and prices written into the line do not sway the match', () {
      expect(notaItemWords('2 Nasi Goreng 30.000'), 'nasi goreng');
      expect(notaItemWords('Es Teh Manis 2x 4rb'), 'es teh manis');
      expect(notaItemWords('x3 Ayam Geprek Rp 54.000'), 'ayam geprek');
      final l = stage([const NotaLine(rawText: '2 Nasi Goreng 30.000', qty: 2, lineTotal: 30000)])
          .single;
      expect(l.check.product?.name, 'Nasi Goreng');
    });

    test('a line only of numbers keeps its text rather than vanishing', () {
      expect(notaItemWords('30.000'), '30 000');
    });

    test('not in the catalogue: kept with the words as written, and blocking — as in voice', () {
      final l = stage([const NotaLine(rawText: 'Soto Betawi', qty: 1, unitPrice: 25000)]).single;
      expect(l.notFound, isTrue);
      expect(l.rawText, 'Soto Betawi');
      expect(l.blocks, isTrue);
      expect(l.unitPrice, 0);
    });

    test('out of stock and short stock block — the server refuses them', () {
      final lines = stage(const [
        NotaLine(rawText: 'Teh Botol', qty: 1), // 0 on hand
        NotaLine(rawText: 'Air Mineral', qty: 3), // 1 on hand
        NotaLine(rawText: 'Air Mineral', qty: 1), // 1 on hand — fine
      ]);
      expect(lines.map((l) => l.check.status), [
        SttStockStatus.outOfStock,
        SttStockStatus.insufficient,
        SttStockStatus.ok,
      ]);
      expect(lines.map((l) => l.blocks), [true, true, false]);
    });

    test('a switched-off item only warns — the server does not refuse it', () {
      final l = stage([const NotaLine(rawText: 'Bakwan', qty: 1)]).single;
      expect(l.check.status, SttStockStatus.unavailable);
      expect(l.blocks, isFalse);
    });

    test('blank lines are dropped; every other line is kept, matched or not', () {
      final lines = stage(const [
        NotaLine(rawText: '   '),
        NotaLine(rawText: 'Nasi Goreng', qty: 1),
        NotaLine(rawText: 'Tulisan tidak terbaca'),
      ]);
      expect(lines, hasLength(2));
      expect(lines.last.notFound, isTrue);
    });
  });

  /// The nota's name field does double duty in a warung: a customer's name, or the table they are
  /// sitting at. A number there means dine-in.
  group('where the customer is sitting', () {
    test('a bare number is a table', () {
      expect(notaSeating('7'), (type: 'DINE_IN', tableLabel: '7'));
    });

    test('a number inside a phrase is the table, and stays one number', () {
      expect(notaSeating('Meja 12'), (type: 'DINE_IN', tableLabel: '12'),
          reason: 'twelve, not one and two');
    });

    test('a name with no number is carried out', () {
      // Nota #07's own name field, which is a person.
      expect(notaSeating('Ahmad'), (type: 'TAKEAWAY', tableLabel: null));
    });

    test('nothing written is carried out too', () {
      expect(notaSeating(null), (type: 'TAKEAWAY', tableLabel: null));
      expect(notaSeating(''), (type: 'TAKEAWAY', tableLabel: null));
      expect(notaSeating('   '), (type: 'TAKEAWAY', tableLabel: null));
    });

    test('a leading zero is how a nota writes a table, not a different table', () {
      expect(notaSeating('07').tableLabel, '7');
      expect(notaSeating('Meja 007').tableLabel, '7');
    });

    test('the FIRST number wins when a nota carries two', () {
      expect(notaSeating('Meja 4 / 2 orang').tableLabel, '4');
    });

    test('a name that happens to carry a digit is still read as a table', () {
      // Blunt on purpose: the cashier sees the result on screen before anything is charged, and a
      // wrong dine-in is one tap to fix on the till. The opposite mistake leaves an open bill at a
      // table nobody is sitting at.
      expect(notaSeating('Ahmad 2'), (type: 'DINE_IN', tableLabel: '2'));
    });
  });
}

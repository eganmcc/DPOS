import 'package:dpos/core/theme.dart';
import 'package:dpos/data/models.dart';
import 'package:dpos/features/nota/nota_models.dart';
import 'package:dpos/features/nota/nota_order.dart';
import 'package:dpos/features/nota/nota_order_screen.dart';
import 'package:dpos/features/stt/stt_stock_check.dart';
import 'package:dpos/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The nota order list: it behaves like voice's, and hands Selesai exactly what it shows.
void main() {
  Variant v(String name, int price) => Variant(
        id: 'v-$name',
        name: name,
        price: price,
        sku: null,
        isAvailable: true,
        trackInventory: false,
      );
  Product p(String name, int price) => Product(
        id: 'p-$name',
        name: name,
        categoryName: 'Cat',
        isAvailable: true,
        variants: [v(name, price)],
        modifierGroups: const [],
      );

  final catalog = [p('Nasi Goreng', 15000), p('Es Teh Manis', 4000)];

  List<NotaOrderLine> read(List<NotaLine> items) => stageNotaReading(
        NotaReading(
          items: items,
          unclear: const [],
          confidence: 90,
          model: 'test',
          latencyMs: 0,
          raw: const {},
        ),
        catalog,
      );

  late List<List<SttStockCheck>> finished;
  late List<List<SttStockCheck>> addedToCart;
  late bool finishSucceeds;

  setUp(() {
    finished = [];
    addedToCart = [];
    finishSucceeds = true;
  });

  Future<void> pump(WidgetTester tester, List<NotaOrderLine> lines, {TaxRule? tax}) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildLightTheme(),
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: NotaOrderBody(
          lines: lines,
          notaNumber: '1234',
          taxRule: tax,
          onAddToCart: (checks) => addedToCart.add(checks),
          onFinish: (checks) async {
            finished.add(checks);
            return finishSucceeds;
          },
        ),
      ),
    ));
    await tester.pump();
  }

  FilledButton selesai(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(const ValueKey('nota-order-selesai')));
  OutlinedButton addToCart(WidgetTester tester) =>
      tester.widget<OutlinedButton>(find.byKey(const ValueKey('nota-order-add-to-cart')));

  testWidgets("shows the shop's price and totals, and the paper's price beside it", (tester) async {
    await pump(tester, read(const [
      NotaLine(rawText: 'Nasi Goreng', qty: 2, unitPrice: 20000),
      NotaLine(rawText: 'Es Teh Manis', qty: 2, unitPrice: 4000),
    ]));
    // 2 x 15.000 + 2 x 4.000, at the shop's prices — the paper's 20.000 is not charged.
    expect(find.text('Rp 38.000'), findsOneWidget);
    expect(find.textContaining('Di nota Rp 20.000'), findsOneWidget);
    expect(find.text('Dibaca dari nota #1234'), findsOneWidget);
    expect(selesai(tester).onPressed, isNotNull, reason: 'a price difference does not block');
  });

  testWidgets('a line not in the catalogue blocks, and removing it unblocks', (tester) async {
    await pump(tester, read(const [
      NotaLine(rawText: 'Nasi Goreng', qty: 1),
      NotaLine(rawText: 'Soto Betawi', qty: 1),
    ]));
    expect(find.text('Soto Betawi'), findsOneWidget, reason: "the paper's words are shown");
    expect(find.byKey(const ValueKey('nota-order-blocked')), findsOneWidget);
    expect(selesai(tester).onPressed, isNull);
    expect(addToCart(tester).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('nota-order-remove-1')));
    await tester.pump();

    expect(find.byKey(const ValueKey('nota-order-blocked')), findsNothing);
    expect(selesai(tester).onPressed, isNotNull);
  });

  testWidgets('Selesai hands over exactly the lines on screen', (tester) async {
    await pump(tester, read(const [
      NotaLine(rawText: 'Nasi Goreng', qty: 2),
      NotaLine(rawText: 'Es Teh Manis', qty: 3),
    ]));
    await tester.tap(find.byKey(const ValueKey('nota-order-remove-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('nota-order-selesai')));
    await tester.pump();

    expect(finished, hasLength(1));
    final sent = finished.single;
    expect(sent, hasLength(1), reason: 'the removed line never reaches the order');
    expect(sent.single.product?.name, 'Nasi Goreng');
    expect(sent.single.variant?.price, 15000);
    expect(sent.single.qty, 2);
  });

  testWidgets('a failed Selesai leaves the bill on screen', (tester) async {
    finishSucceeds = false;
    await pump(tester, read(const [NotaLine(rawText: 'Nasi Goreng', qty: 1)]));
    await tester.tap(find.byKey(const ValueKey('nota-order-selesai')));
    await tester.pump();

    expect(finished, hasLength(1));
    expect(find.text('Nasi Goreng'), findsOneWidget, reason: 'nothing was recorded, so nothing is cleared');
    expect(selesai(tester).onPressed, isNotNull);
  });

  testWidgets('Tambah ke keranjang hands the lines to the cart', (tester) async {
    await pump(tester, read(const [NotaLine(rawText: 'Es Teh Manis', qty: 2)]));
    await tester.tap(find.byKey(const ValueKey('nota-order-add-to-cart')));
    await tester.pump();

    expect(addedToCart, hasLength(1));
    expect(addedToCart.single.single.qty, 2);
    expect(finished, isEmpty);
  });

  testWidgets('a fractional quantity blocks, with its reason on the line', (tester) async {
    await pump(tester, read(const [NotaLine(rawText: 'Nasi Goreng', qty: 1.5)]));
    expect(find.text('Jumlah di nota bukan bilangan bulat'), findsOneWidget);
    expect(selesai(tester).onPressed, isNull);
  });

  testWidgets('tax is shown when the outlet has a rule', (tester) async {
    await pump(
      tester,
      read(const [NotaLine(rawText: 'Nasi Goreng', qty: 1)]),
      tax: const TaxRule(label: 'PBJT', rateBps: 1000, serviceChargeBps: null),
    );
    expect(find.text('Pajak'), findsOneWidget);
    expect(find.text('Rp 16.500'), findsOneWidget);
  });
}

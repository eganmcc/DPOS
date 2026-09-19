import 'package:dpos/data/models.dart';
import 'package:dpos/features/calculator/nota_calculator.dart' show kMaxNotaAmount;
import 'package:dpos/features/nota/nota_models.dart';
import 'package:dpos/features/nota_chat/nota_sale.dart';
import 'package:flutter_test/flutter_test.dart';

/// What confirming a nota reading records (specs/009) — money rules, tested without a screen.
void main() {
  NotaReading reading({
    String? number = '2237',
    String? customer = 'Edward',
    required List<Map<String, dynamic>> items,
    int? total,
  }) =>
      NotaReading.fromJson({
        'notaNumber': number,
        'customerName': customer,
        'items': items,
        'total': total,
        'unclear': <String>[],
        'confidence': 90,
        'model': 'claude-opus-5',
        'latencyMs': 1,
      });

  Map<String, dynamic> line(String raw, {int? lineTotal, int? unitPrice, num? qty}) =>
      {'rawText': raw, 'lineTotal': lineTotal, 'unitPrice': unitPrice, 'qty': qty};

  test('slip 2237: the priced line is charged as written, the free line is shown but not charged',
      () {
    final plan = NotaSalePlan.from(reading(
      items: [line('1 M BESAR', lineTotal: 130000), line('A/J FREE')],
      total: 130000,
    ));
    expect(plan.lines.map((l) => (l.label, l.amount)), [('1 M BESAR', 130000)]);
    expect(plan.notCharged, ['A/J FREE']);
    expect(plan.linesTotal, 130000);
    expect(plan.totalsDisagree, false);
    expect(plan.canRecord, true);
  });

  test('when the written total disagrees with the lines, that is flagged — the lines are charged',
      () {
    final plan = NotaSalePlan.from(reading(
      items: [line('Cuci', lineTotal: 65000), line('Setrika', lineTotal: 20000)],
      total: 80000,
    ));
    expect(plan.linesTotal, 85000);
    expect(plan.totalsDisagree, true);
  });

  test('a nota that prices only the whole becomes one line at the written total', () {
    final plan = NotaSalePlan.from(reading(
      number: '0357',
      items: [line('1 M KECIL'), line('31 pc')],
      total: 60000,
    ));
    expect(plan.usesWrittenTotal, true);
    expect(plan.lines.map((l) => (l.label, l.amount)), [('Nota #0357', 60000)]);
    expect(plan.notCharged, isEmpty);
    expect(plan.totalsDisagree, false);
  });

  test('nothing priced and no total means nothing can be charged', () {
    final plan = NotaSalePlan.from(reading(items: [line('1 M BESAR')], total: null));
    expect(plan.canRecord, false);
  });

  test('a line with only a unit price and a quantity is charged at their product', () {
    final plan = NotaSalePlan.from(
        reading(items: [line('2 kg setrika', unitPrice: 5000, qty: 2)], total: null));
    expect(plan.lines.single.amount, 10000);
  });

  test('zero, negative or impossibly large figures are not prices', () {
    final plan = NotaSalePlan.from(reading(items: [
      line('gratis', lineTotal: 0),
      line('salah baca', lineTotal: kMaxNotaAmount + 1),
      line('Cuci', lineTotal: 15000),
    ], total: null));
    expect(plan.lines.map((l) => l.label), ['Cuci']);
    expect(plan.notCharged, ['gratis', 'salah baca']);
  });

  test('the payload is an OPEN transaction: no payment, no totals, one labelled line per price', () {
    final plan = NotaSalePlan.from(reading(
      items: [line('1 M BESAR', lineTotal: 130000), line('A/J FREE')],
      total: 130000,
    ));
    final body = plan.payload(
      clientOrderId: 'c-1',
      outletId: 'o-1',
      openAmountVariantId: 'v-open',
      deviceId: 'd-1',
      notaNumber: ' 2237 ',
      customerName: 'Edward',
    );
    // No payment key is what makes the server record AWAITING_PAYMENT.
    expect(body.containsKey('payment'), false);
    expect(body.containsKey('grandTotal'), false);
    expect(body['notaNumber'], '2237');
    expect(body['customerName'], 'Edward');
    expect(body['lines'], [
      {'variantId': 'v-open', 'qty': 1, 'amount': 130000, 'label': '1 M BESAR'},
    ]);
  });

  test('an over-long line is trimmed to what the server accepts rather than refused', () {
    final plan =
        NotaSalePlan.from(reading(items: [line('x' * 300, lineTotal: 1000)], total: null));
    expect(plan.lines.single.label.length, kNotaLabelMax);
  });

  group('Catalog.isNotaReading', () {
    Catalog of(Map<String, dynamic> extra) =>
        Catalog.fromJson({'outletId': 'o', 'products': [], ...extra});

    test('the new business type with its variant opens the nota chat', () {
      final c = of({'businessType': 'HIGH_HUMAN_INTERACTION', 'openAmountVariantId': 'v'});
      expect(c.isNotaReading, true);
      expect(c.sellsWithoutCatalog, true);
      expect(c.isFnb || c.isGrocery, false);
    });

    test('without the variant it falls back to the till, never a chat that cannot record', () {
      expect(of({'businessType': 'HIGH_HUMAN_INTERACTION'}).isNotaReading, false);
    });

    test('F&B and grocery merchants are untouched', () {
      expect(of({'businessType': 'FNB', 'openAmountVariantId': 'v'}).isNotaReading, false);
      expect(of({'businessType': 'GROCERY'}).sellsWithoutCatalog, false);
    });
  });
}

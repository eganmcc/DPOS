import 'package:dpos/core/order_math.dart';
import 'package:dpos/data/models.dart';
import 'package:dpos/features/calculator/nota_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Calculator-only mode (specs/008): every rule a cashier's thumb can hit, tested without a widget.
void main() {
  NotaCalculatorState typed(List<String> keys, [NotaCalculatorState from = const NotaCalculatorState()]) =>
      keys.fold(from, (s, k) => s.key(k));

  group('keying an amount', () {
    test('digits build the entry and 00 / 000 append zeros', () {
      final s = typed(['2', '5', '000']);
      expect(s.entry, '25000');
      expect(s.currentValue, 25000);
      expect(typed(['7', '00']).currentValue, 700);
    });

    test('zero keys on an empty entry do nothing — an amount never starts with 0', () {
      // Otherwise "000" could stand alone as an entry, and ↵ would have to decide what it means.
      for (final k in ['0', '00', '000']) {
        expect(typed([k]).entry, '', reason: '$k on empty');
      }
      expect(typed(['0', '5']).entry, '5');
    });

    test('a keystroke past the ceiling is refused whole, never truncated', () {
      // 100.000.000 is the ceiling; one more 0 would make it a billion. The entry must stay put
      // rather than silently becoming some other number.
      final atMax = typed(['1', '000', '000', '00']);
      expect(atMax.currentValue, kMaxNotaAmount);
      expect(atMax.key('0').currentValue, kMaxNotaAmount);
      expect(typed(['9', '9', '000', '000']).key('000').currentValue, 99000000);
    });

    test('⌫ removes one character, not one keypress', () {
      // Pinned so a later switch to per-keypress undo is a decision, not an accident.
      final s = typed(['5', '00']).backspace();
      expect(s.entry, '50');
      expect(const NotaCalculatorState().backspace().entry, '');
    });
  });

  group('committing and clearing', () {
    test('↵ commits the entry as a line and resets it; ↵ on nothing does nothing', () {
      final s = typed(['1', '5', '000']).commit();
      expect(s.amounts, [15000]);
      expect(s.entry, '');
      expect(s.commit().amounts, [15000]);
    });

    test('C clears only what is being typed — the committed list survives', () {
      // One stray tap must never wipe a nota; only Batal (behind a confirmation) does that.
      final s = typed(['9', '000'], typed(['2', '000']).commit()).clear();
      expect(s.entry, '');
      expect(s.amounts, [2000]);
    });

    test('subtotal and count follow the committed lines', () {
      var s = const NotaCalculatorState();
      for (final a in ['25', '12', '3']) {
        s = typed([a, '000'], s).commit();
      }
      expect(s.amounts, [25000, 12000, 3000]);
      expect(s.subtotal, 40000);
      expect(s.count, 3);
      expect(s.reset().isEmpty, true);
    });

    test('Selesai charges an amount still being typed — forgetting ↵ must not under-charge', () {
      final s = typed(['5', '000'], typed(['2', '000']).commit());
      expect(s.amounts, [2000]);
      expect(s.pendingAmounts, [2000, 5000]);
      expect(s.canFinish, true);
      expect(const NotaCalculatorState().canFinish, false);
    });
  });

  group('totals — the same engine as the cart', () {
    test('no tax rule: the total is the plain sum', () {
      expect(previewTotals(subtotal: 40000, tax: null).grandTotal, 40000);
    });

    test('a tax rule applies with no code change — the same figures as the server test', () {
      // server/test/orders.open-amount.e2e-spec.ts asserts 4000 / 2000 / 46000 for this nota.
      // Identical numbers here are what keep the keypad's total and the server's in step.
      const rule = TaxRule(label: 'PBJT', rateBps: 1000, serviceChargeBps: 500);
      final p = previewTotals(subtotal: 40000, tax: rule);
      expect(p.taxTotal, 4000);
      expect(p.serviceChargeTotal, 2000);
      expect(p.grandTotal, 46000);
    });
  });

  test('the payload is one qty-1 line per amount, paid in cash', () {
    final body = buildNotaPayload(
      clientOrderId: 'c-1',
      outletId: 'o-1',
      deviceId: 'd-1',
      openAmountVariantId: 'v-open',
      amounts: [25000, 3000],
      tendered: 30000,
    );
    expect(body['type'], 'RETAIL');
    expect(body['lines'], [
      {'variantId': 'v-open', 'qty': 1, 'amount': 25000},
      {'variantId': 'v-open', 'qty': 1, 'amount': 3000},
    ]);
    expect(body['payment'], {'method': 'CASH', 'tendered': 30000});
    // Totals are the server's job; the client never sends one.
    expect(body.containsKey('grandTotal'), false);
  });

  test('header labels are Indonesian without needing intl locale data', () {
    // 19 Sep 2026 is a Saturday.
    expect(notaDateLabel(DateTime(2026, 9, 19)), 'Sab, 19 Sep');
    expect(notaDateLabel(DateTime(2026, 8, 17)), 'Sen, 17 Agu');
    expect(notaTimeLabel(DateTime(2026, 9, 19, 9, 5)), '09:05');
  });

  group('Catalog.isCalculatorOnly', () {
    Catalog of(Map<String, dynamic> extra) =>
        Catalog.fromJson({'outletId': 'o', 'products': [], ...extra});

    test('absent flag means the normal till', () {
      expect(of({}).isCalculatorOnly, false);
    });

    test('flagged with a variant opens the keypad', () {
      expect(of({'calculatorOnly': true, 'openAmountVariantId': 'v'}).isCalculatorOnly, true);
    });

    test('flagged but with no variant falls back to the till rather than a keypad that cannot sell', () {
      // A cached catalog from before openAmountVariantId shipped: a keypad here could not post a
      // single line, so the till is the safe place to land until the catalog refetches.
      expect(of({'calculatorOnly': true}).isCalculatorOnly, false);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:dpos/core/money.dart';
import 'package:dpos/data/models.dart';
import 'package:dpos/features/order/cart.dart';
import 'package:dpos/features/payment/payment_tenders.dart';

void main() {
  test('formatRupiah renders Indonesian rupiah', () {
    expect(formatRupiah(41400), 'Rp 41.400');
    expect(formatRupiah(0), 'Rp 0');
  });

  test('cart preview mirrors the backend money engine', () {
    const product = Product(
      id: 'p1', name: 'Kopi Susu', categoryName: 'Minuman', isAvailable: true,
      variants: [], modifierGroups: [],
    );
    const variant = Variant(
      id: 'v1', name: 'Regular', price: 18000, sku: null, isAvailable: true, trackInventory: true,
    );
    const tax = TaxRule(label: 'PBJT', rateBps: 1000, serviceChargeBps: 500);

    final ctrl = CartController();
    ctrl.addItem(product, variant, const []);
    ctrl.changeQty(0, 1); // qty -> 2

    final p = ctrl.state.preview(tax);
    expect(p.subtotal, 36000);
    expect(p.taxTotal, 3600); // 10%
    expect(p.serviceChargeTotal, 1800); // 5%
    expect(p.grandTotal, 41400); // matches the verified backend sale
  });
  test('DashboardSummary decodes a server that has no P/L keys yet', () {
    // An app built against a newer server must still read an older one: the profit
    // fields default to 0 rather than throwing, and hasProfitData hides the card.
    final d = DashboardSummary.fromJson(const {
      'netSales': 41400,
      'orderCount': 1,
      'avgTicket': 41400,
    });
    expect(d.netSales, 41400);
    expect(d.netRevenue, 0);
    expect(d.cogs, 0);
    expect(d.grossProfit, 0);
    expect(d.linesMissingCost, 0);
    expect(d.itemsMissingCost, isEmpty);
    expect(d.hasProfitData, isFalse);
  });

  test('DashboardSummary reads gross margin and the missing-cost flag', () {
    final d = DashboardSummary.fromJson(const {
      'netSales': 100000,
      'netRevenue': 90000,
      'cogs': 35000,
      'grossProfit': 55000,
      'grossMarginBps': 6111,
      'costCoverage': {'linesTotal': 3, 'linesMissingCost': 1, 'itemsMissingCost': ['Es Teh']},
    });
    expect(d.grossProfit, 55000);
    expect(d.grossMarginBps, 6111);
    expect(d.linesMissingCost, 1);
    expect(d.itemsMissingCost, ['Es Teh']);
    expect(d.hasProfitData, isTrue);
  });

  test('Catalog from a stale cache has no businessSize and is NOT treated as UMI', () {
    // The drift cache stores the whole catalog response as an opaque blob, so a device
    // that hasn't refetched since deploy decodes this field as absent. It must fail
    // closed — suppressing a PIN prompt the server still enforces would be a 403.
    final c = Catalog.fromJson(const {'outletId': 'o1', 'taxRule': null, 'products': []});
    expect(c.businessSize, 'GENERAL');
    expect(c.isUmi, isFalse);
    expect(c.businessType, 'FNB'); // the same discipline, already shipped
  });

  test('Catalog reads businessSize; only UMI is UMI', () {
    Catalog of(String size) => Catalog.fromJson({
          'outletId': 'o1',
          'businessSize': size,
          'taxRule': null,
          'products': const [],
        });
    expect(of('UMI').isUmi, isTrue);
    expect(of('UMKM').isUmi, isFalse); // UMKM behaves as GENERAL today
    expect(of('GENERAL').isUmi, isFalse);
  });

  group('Card and e-wallet tenders are offered only to a confirmed non-UMI merchant', () {
    Catalog of(Map<String, dynamic> extra) => Catalog.fromJson({
          'outletId': 'o1',
          'taxRule': null,
          'products': const [],
          ...extra,
        });

    test('UMI never gets them', () {
      expect(cardTendersAllowed(of({'businessSize': 'UMI'})), isFalse);
    });

    test('a confirmed GENERAL/UMKM merchant does', () {
      expect(cardTendersAllowed(of({'businessSize': 'GENERAL'})), isTrue);
      expect(cardTendersAllowed(of({'businessSize': 'UMKM'})), isTrue);
    });

    test('unknown fails CLOSED — no catalog yet, stale cache, or an API without the field', () {
      // No catalog loaded (cold start / offline).
      expect(cardTendersAllowed(null), isFalse);
      // Catalog with no businessSize: a cache written before the field shipped, or a server
      // still on main. Defaulting to GENERAL here is what put card buttons on a UMI till.
      expect(cardTendersAllowed(of(const {})), isFalse);
      expect(of(const {}).businessSizeKnown, isFalse);
      expect(of({'businessSize': 'UMI'}).businessSizeKnown, isTrue);
    });
  });
}

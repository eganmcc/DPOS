import 'package:flutter_test/flutter_test.dart';
import 'package:dpos/core/money.dart';
import 'package:dpos/data/models.dart';
import 'package:dpos/features/order/cart.dart';

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
}

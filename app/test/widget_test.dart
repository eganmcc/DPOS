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
}

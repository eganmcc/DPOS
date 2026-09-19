import '../data/models.dart';

/// Display-only totals that mirror the backend money engine. The server recomputes on submit
/// and its figures are authoritative (Constitution III) — these are for the cashier's preview.
class CartPreview {
  final int subtotal;
  final int discountTotal;
  final int taxTotal;
  final int serviceChargeTotal;
  final int grandTotal;
  const CartPreview(this.subtotal, this.discountTotal, this.taxTotal, this.serviceChargeTotal, this.grandTotal);
}

/// The one client-side copy of `computeOrder`'s order-level arithmetic (server/src/common/money.ts):
/// discount off the subtotal, then tax and service charge on what remains.
///
/// Shared by the catalog cart and the calculator so the two can never drift. It is also what keeps
/// the calculator's zero tax FLEXIBLE: a calculator merchant is provisioned with no tax rule, so
/// `tax` is null and the result is the plain sum. Add a `TaxRule` on the server and this starts
/// charging it — on the keypad total and in the payment sheet's change — with no code change.
CartPreview previewTotals({required int subtotal, int discountTotal = 0, TaxRule? tax}) {
  final base = subtotal - discountTotal;
  final taxTotal = tax == null ? 0 : ((base * tax.rateBps) / 10000).round();
  final serviceChargeTotal =
      tax?.serviceChargeBps == null ? 0 : ((base * tax!.serviceChargeBps!) / 10000).round();
  return CartPreview(
      subtotal, discountTotal, taxTotal, serviceChargeTotal, base + taxTotal + serviceChargeTotal);
}

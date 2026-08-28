import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models.dart';

class CartLine {
  final Product product;
  final Variant variant;
  final int qty;
  final List<Modifier> modifiers;
  final String? note;
  const CartLine({
    required this.product,
    required this.variant,
    required this.qty,
    required this.modifiers,
    this.note,
  });

  int get unitPrice => variant.price + modifiers.fold(0, (s, m) => s + m.priceDelta);
  int get lineTotal => unitPrice * qty;

  /// Identity of an orderable line, independent of quantity: same variant, same
  /// SET of modifiers (order-independent), same note. Adding an item that matches
  /// an existing line's key bumps its qty instead of spawning a duplicate row.
  String get mergeKey {
    final modIds = modifiers.map((m) => m.id).toList()..sort();
    return '${variant.id}|${modIds.join(',')}|${note ?? ''}';
  }

  CartLine copyWith({int? qty}) => CartLine(
        product: product,
        variant: variant,
        qty: qty ?? this.qty,
        modifiers: modifiers,
        note: note,
      );
}

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

class CartState {
  final List<CartLine> lines;
  final String type; // DINE_IN | TAKEAWAY
  final String? tableLabel;
  final int orderDiscountPercentBps; // 0..10000
  const CartState({
    this.lines = const [],
    this.type = 'TAKEAWAY',
    this.tableLabel,
    this.orderDiscountPercentBps = 0,
  });

  bool get isEmpty => lines.isEmpty;

  CartState copyWith({
    List<CartLine>? lines,
    String? type,
    String? tableLabel,
    int? orderDiscountPercentBps,
  }) =>
      CartState(
        lines: lines ?? this.lines,
        type: type ?? this.type,
        tableLabel: tableLabel ?? this.tableLabel,
        orderDiscountPercentBps: orderDiscountPercentBps ?? this.orderDiscountPercentBps,
      );

  CartPreview preview(TaxRule? tax) {
    final subtotal = lines.fold(0, (s, l) => s + l.lineTotal);
    final discountTotal = ((subtotal * orderDiscountPercentBps) / 10000).round();
    final base = subtotal - discountTotal;
    final taxTotal = tax == null ? 0 : ((base * tax.rateBps) / 10000).round();
    final serviceChargeTotal =
        tax?.serviceChargeBps == null ? 0 : ((base * tax!.serviceChargeBps!) / 10000).round();
    return CartPreview(subtotal, discountTotal, taxTotal, serviceChargeTotal,
        base + taxTotal + serviceChargeTotal);
  }
}

class CartController extends StateNotifier<CartState> {
  CartController() : super(const CartState());

  void addItem(Product product, Variant variant, List<Modifier> modifiers, {String? note}) {
    final incoming =
        CartLine(product: product, variant: variant, qty: 1, modifiers: modifiers, note: note);
    final lines = [...state.lines];
    final i = lines.indexWhere((l) => l.mergeKey == incoming.mergeKey);
    if (i >= 0) {
      lines[i] = lines[i].copyWith(qty: lines[i].qty + 1);
    } else {
      lines.add(incoming);
    }
    state = state.copyWith(lines: lines);
  }

  void changeQty(int index, int delta) {
    final lines = [...state.lines];
    final next = lines[index].qty + delta;
    if (next <= 0) {
      lines.removeAt(index);
    } else {
      lines[index] = lines[index].copyWith(qty: next);
    }
    state = state.copyWith(lines: lines);
  }

  void removeAt(int index) {
    final lines = [...state.lines]..removeAt(index);
    state = state.copyWith(lines: lines);
  }

  void setType(String type) => state = state.copyWith(type: type);
  void setTableLabel(String? label) => state = state.copyWith(tableLabel: label);
  void setDiscountPercent(int percent) =>
      state = state.copyWith(orderDiscountPercentBps: (percent.clamp(0, 100)) * 100);

  void clear() => state = const CartState();

  /// Build the submit payload consumed by POST /orders.
  Map<String, dynamic> buildPayload({
    required String clientOrderId,
    required String outletId,
    String? deviceId,
    required String method, // CASH | QRIS_SIMULATED
    int? tendered,
  }) {
    return {
      'clientOrderId': clientOrderId,
      'outletId': outletId,
      if (deviceId != null) 'deviceId': deviceId,
      'type': state.type,
      if (state.tableLabel != null && state.tableLabel!.isNotEmpty) 'tableLabel': state.tableLabel,
      if (state.orderDiscountPercentBps > 0)
        'orderDiscount': {'kind': 'PERCENT', 'value': state.orderDiscountPercentBps},
      'lines': state.lines
          .map((l) => {
                'variantId': l.variant.id,
                'qty': l.qty,
                if (l.modifiers.isNotEmpty) 'modifierIds': l.modifiers.map((m) => m.id).toList(),
                if (l.note != null && l.note!.isNotEmpty) 'note': l.note,
              })
          .toList(),
      'payment': {'method': method, if (tendered != null) 'tendered': tendered},
    };
  }
}

final cartProvider = StateNotifierProvider<CartController, CartState>((ref) => CartController());

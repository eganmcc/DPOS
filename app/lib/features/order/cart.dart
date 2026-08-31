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
  final String? revisingOrderId; // set when editing an existing open bill
  const CartState({
    this.lines = const [],
    this.type = 'TAKEAWAY',
    this.tableLabel,
    this.orderDiscountPercentBps = 0,
    this.revisingOrderId,
  });

  bool get isEmpty => lines.isEmpty;
  bool get isRevising => revisingOrderId != null;

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
        revisingOrderId: revisingOrderId, // preserved across edits; cleared by clear()
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

  void addItem(Product product, Variant variant, List<Modifier> modifiers,
      {String? note, int qty = 1}) {
    final incoming =
        CartLine(product: product, variant: variant, qty: qty, modifiers: modifiers, note: note);
    final lines = [...state.lines];
    final i = lines.indexWhere((l) => l.mergeKey == incoming.mergeKey);
    if (i >= 0) {
      // Bump qty and move the just-touched line to the top.
      final existing = lines.removeAt(i);
      lines.insert(0, existing.copyWith(qty: existing.qty + qty));
    } else {
      lines.insert(0, incoming); // newest on top
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

  /// Load an open bill's items back into the cart for editing. Resolves each line's
  /// variant + modifiers from the catalog (lines whose variant is no longer in the
  /// catalog are skipped). Sets revisingOrderId so confirming calls revise, not create.
  void loadFromOrder(OrderResult order, Catalog catalog) {
    final variants = <String, (Product, Variant)>{};
    final mods = <String, Modifier>{};
    for (final prod in catalog.products) {
      for (final v in prod.variants) {
        variants[v.id] = (prod, v);
      }
      for (final g in prod.modifierGroups) {
        for (final m in g.modifiers) {
          mods[m.id] = m;
        }
      }
    }
    final lines = <CartLine>[];
    for (final ol in order.lines) {
      final vid = ol.variantId;
      if (vid == null) continue;
      final pv = variants[vid];
      if (pv == null) continue;
      final lineMods = ol.modifierIds.map((id) => mods[id]).whereType<Modifier>().toList();
      lines.add(CartLine(
        product: pv.$1,
        variant: pv.$2,
        qty: num.tryParse(ol.qty)?.toInt() ?? 1,
        modifiers: lineMods,
      ));
    }
    state = CartState(
      lines: lines,
      type: order.type ?? 'TAKEAWAY',
      tableLabel: order.tableLabel,
      revisingOrderId: order.id,
    );
  }

  /// Payload for POST /orders/:id/revise — same line shape as a submit, without a
  /// clientOrderId or payment.
  Map<String, dynamic> buildRevisePayload() {
    final isDineIn = state.type == 'DINE_IN';
    final table = state.tableLabel?.trim().toUpperCase();
    return {
      'type': state.type,
      // Only a dine-in bill carries a table; switching to takeaway clears it server-side.
      if (isDineIn && table != null && table.isNotEmpty) 'tableLabel': table,
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
    };
  }

  /// Build the submit payload consumed by POST /orders.
  ///
  /// [method] null → confirm an open bill (no payment; the server stores it
  /// AWAITING_PAYMENT and reserves stock). Non-null → settle immediately.
  Map<String, dynamic> buildPayload({
    required String clientOrderId,
    required String outletId,
    String? deviceId,
    String? method, // CASH | QRIS_SIMULATED, or null for an open bill
    int? tendered,
  }) {
    final table = state.tableLabel?.trim().toUpperCase();
    return {
      'clientOrderId': clientOrderId,
      'outletId': outletId,
      if (deviceId != null) 'deviceId': deviceId,
      'type': state.type,
      if (table != null && table.isNotEmpty) 'tableLabel': table,
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
      if (method != null)
        'payment': {'method': method, if (tendered != null) 'tendered': tendered},
    };
  }
}

final cartProvider = StateNotifierProvider<CartController, CartState>((ref) => CartController());

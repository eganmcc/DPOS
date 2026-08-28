// Plain data models decoded from the API. All money fields are integer rupiah.

class Modifier {
  final String id;
  final String name;
  final int priceDelta;
  const Modifier({required this.id, required this.name, required this.priceDelta});

  factory Modifier.fromJson(Map<String, dynamic> j) =>
      Modifier(id: j['id'], name: j['name'], priceDelta: j['priceDelta'] ?? 0);
}

class ModifierGroup {
  final String id;
  final String name;
  final int minSelect;
  final int maxSelect;
  final bool required;
  final List<Modifier> modifiers;
  const ModifierGroup({
    required this.id,
    required this.name,
    required this.minSelect,
    required this.maxSelect,
    required this.required,
    required this.modifiers,
  });

  factory ModifierGroup.fromJson(Map<String, dynamic> j) => ModifierGroup(
        id: j['id'],
        name: j['name'],
        minSelect: j['minSelect'] ?? 0,
        maxSelect: j['maxSelect'] ?? 1,
        required: j['required'] ?? false,
        modifiers: ((j['modifiers'] ?? []) as List)
            .map((m) => Modifier.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}

class Variant {
  final String id;
  final String name;
  final int price;
  final String? sku;
  final bool isAvailable;
  final bool trackInventory;
  final int? stock; // remaining on-hand; null = not tracked (unlimited)
  const Variant({
    required this.id,
    required this.name,
    required this.price,
    required this.sku,
    required this.isAvailable,
    required this.trackInventory,
    this.stock,
  });

  /// Can be ordered: not tracked, or tracked with stock remaining.
  bool get inStock => !trackInventory || (stock ?? 0) > 0;

  factory Variant.fromJson(Map<String, dynamic> j) => Variant(
        id: j['id'],
        name: j['name'],
        price: j['price'],
        sku: j['sku'],
        isAvailable: j['isAvailable'] ?? true,
        trackInventory: j['trackInventory'] ?? false,
        stock: j['stock'] as int?,
      );
}

class Product {
  final String id;
  final String name;
  final String categoryName;
  final String? imageUrl;
  final bool isAvailable;
  final List<Variant> variants;
  final List<ModifierGroup> modifierGroups;
  const Product({
    required this.id,
    required this.name,
    required this.categoryName,
    this.imageUrl,
    required this.isAvailable,
    required this.variants,
    required this.modifierGroups,
  });

  /// Orderable if any available variant still has stock.
  bool get anyInStock => isAvailable && variants.any((v) => v.isAvailable && v.inStock);

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'],
        name: j['name'],
        categoryName: j['categoryName'] ?? '',
        imageUrl: j['imageUrl'] as String?,
        isAvailable: j['isAvailable'] ?? true,
        variants: ((j['variants'] ?? []) as List)
            .map((v) => Variant.fromJson(v as Map<String, dynamic>))
            .toList(),
        modifierGroups: ((j['modifierGroups'] ?? []) as List)
            .map((g) => ModifierGroup.fromJson(g as Map<String, dynamic>))
            .toList(),
      );
}

class TaxRule {
  final String label;
  final int rateBps;
  final int? serviceChargeBps;
  const TaxRule({required this.label, required this.rateBps, required this.serviceChargeBps});

  factory TaxRule.fromJson(Map<String, dynamic> j) => TaxRule(
        label: j['label'] ?? 'Tax',
        rateBps: j['rateBps'] ?? 0,
        serviceChargeBps: j['serviceChargeBps'],
      );
}

class Catalog {
  final String outletId;
  final String? outletName;
  final TaxRule? taxRule;
  final List<Product> products;
  const Catalog(
      {required this.outletId, this.outletName, required this.taxRule, required this.products});

  factory Catalog.fromJson(Map<String, dynamic> j) => Catalog(
        outletId: j['outletId'],
        outletName: j['outletName'],
        taxRule: j['taxRule'] != null ? TaxRule.fromJson(j['taxRule']) : null,
        products: ((j['products'] ?? []) as List)
            .map((p) => Product.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}

class PaymentResult {
  final String method;
  final int amount;
  final String status;
  final int? change;
  final String? qrPayload;

  /// CHARGE (the sale) or REVERSAL (a void/refund compensating record). The original charge is
  /// never rewritten — a reversal is always a new row (Constitution IV).
  final String direction;

  /// VOID or REFUND for a REVERSAL; null for a CHARGE.
  final String? reversalType;

  const PaymentResult({
    required this.method,
    required this.amount,
    required this.status,
    required this.change,
    required this.qrPayload,
    this.direction = 'CHARGE',
    this.reversalType,
  });

  bool get isReversal => direction == 'REVERSAL';

  factory PaymentResult.fromJson(Map<String, dynamic> j) => PaymentResult(
        method: j['method'],
        amount: j['amount'],
        status: j['status'],
        change: j['change'],
        qrPayload: j['qrPayload'],
        direction: j['direction'] ?? 'CHARGE',
        reversalType: j['reversalType'],
      );
}

/// Append-only full-void record. Its existence is what makes an order effectively VOIDED.
class OrderVoidResult {
  final String id;
  final String? reason;
  final String voidedById;
  final DateTime createdAt;
  const OrderVoidResult({
    required this.id,
    required this.reason,
    required this.voidedById,
    required this.createdAt,
  });

  factory OrderVoidResult.fromJson(Map<String, dynamic> j) => OrderVoidResult(
        id: j['id'],
        reason: j['reason'],
        voidedById: j['voidedById'] ?? '',
        createdAt: DateTime.tryParse(j['createdAt'] ?? '')?.toLocal() ?? DateTime.now(),
      );
}

class OrderLineResult {
  final String productNameSnapshot;
  final String qty;
  final int unitPriceSnapshot;
  final int lineTotal;
  const OrderLineResult({
    required this.productNameSnapshot,
    required this.qty,
    required this.unitPriceSnapshot,
    required this.lineTotal,
  });

  factory OrderLineResult.fromJson(Map<String, dynamic> j) => OrderLineResult(
        productNameSnapshot: j['productNameSnapshot'],
        qty: j['qty'].toString(),
        unitPriceSnapshot: j['unitPriceSnapshot'],
        lineTotal: j['lineTotal'],
      );
}

class OrderResult {
  final String id;
  final String status;
  final String? type;
  final String? tableLabel;
  final int subtotal;
  final int discountTotal;
  final int taxTotal;
  final int serviceChargeTotal;
  final int grandTotal;
  final String? taxLabelSnapshot;
  final String effectiveStatus;
  final DateTime createdAt;
  final List<OrderLineResult> lines;
  final List<PaymentResult> payments;
  final List<OrderVoidResult> voids;
  const OrderResult({
    required this.id,
    this.status = 'COMPLETED',
    this.type,
    this.tableLabel,
    required this.subtotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.serviceChargeTotal,
    required this.grandTotal,
    required this.taxLabelSnapshot,
    required this.effectiveStatus,
    required this.createdAt,
    required this.lines,
    required this.payments,
    this.voids = const [],
  });

  /// Derived, never stored — the server sends it and the app only displays it.
  bool get isVoided => effectiveStatus == 'VOIDED';
  bool get isRefunded => effectiveStatus == 'REFUNDED';
  bool get canBeVoided => effectiveStatus == 'COMPLETED';

  factory OrderResult.fromJson(Map<String, dynamic> j) => OrderResult(
        id: j['id'],
        status: j['status'] ?? 'COMPLETED',
        type: j['type'],
        tableLabel: j['tableLabel'],
        subtotal: j['subtotal'],
        discountTotal: j['discountTotal'] ?? 0,
        taxTotal: j['taxTotal'] ?? 0,
        serviceChargeTotal: j['serviceChargeTotal'] ?? 0,
        grandTotal: j['grandTotal'],
        taxLabelSnapshot: j['taxLabelSnapshot'],
        effectiveStatus: j['effectiveStatus'] ?? j['status'] ?? 'COMPLETED',
        createdAt: DateTime.tryParse(j['createdAt'] ?? '')?.toLocal() ?? DateTime.now(),
        lines: ((j['lines'] ?? []) as List)
            .map((l) => OrderLineResult.fromJson(l as Map<String, dynamic>))
            .toList(),
        payments: ((j['payments'] ?? []) as List)
            .map((p) => PaymentResult.fromJson(p as Map<String, dynamic>))
            .toList(),
        voids: ((j['voids'] ?? []) as List)
            .map((v) => OrderVoidResult.fromJson(v as Map<String, dynamic>))
            .toList(),
      );
}

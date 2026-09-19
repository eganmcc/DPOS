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
  final String? merchantName; // company name (receipt header)
  final String businessType; // 'FNB' | 'GROCERY' | 'HIGH_HUMAN_INTERACTION'
  final String businessSize; // 'GENERAL' | 'UMKM' | 'UMI'

  /// Whether the catalog actually CARRIED `businessSize`, as opposed to defaulting to GENERAL.
  ///
  /// False means the answer is unknown: an API that predates the field, or a catalog cached
  /// before it shipped. Anything gated on "this merchant is not UMI" must treat unknown as
  /// "don't offer it" — defaulting to GENERAL would hand a UMI till card and e-wallet buttons.
  final bool businessSizeKnown;

  final String paymentMode; // 'IMMEDIATE' | 'OPEN_BILL'

  /// Sells with no catalog: the cashier keys bare amounts on a keypad (specs/008).
  final bool calculatorOnly;

  /// The provisioned variant every keyed amount is posted against. Null for every other merchant.
  final String? openAmountVariantId;

  final TaxRule? taxRule;
  final List<Product> products;
  const Catalog(
      {required this.outletId,
      this.outletName,
      this.merchantName,
      this.businessType = 'FNB',
      this.businessSize = 'GENERAL',
      this.businessSizeKnown = false,
      this.paymentMode = 'IMMEDIATE',
      this.calculatorOnly = false,
      this.openAmountVariantId,
      required this.taxRule,
      required this.products});

  /// F&B shows dine-in/takeaway + tables + open bills; other types don't.
  bool get isFnb => businessType == 'FNB';

  /// Grocery/retail: enables the barcode-scanner POS mode.
  bool get isGrocery => businessType == 'GROCERY';

  /// UMI ("Ultra Mikro") is a one-person business: corrections need no approver PIN,
  /// items are managed in-app, and attendance is pointless. UI ONLY — every UMI rule is
  /// enforced server-side, because this value can come from a stale cached catalog.
  bool get isUmi => businessSize == 'UMI';

  /// Restaurant flow: confirm the order now (reserves stock), settle later.
  bool get isOpenBill => paymentMode == 'OPEN_BILL';

  /// Whether the app should open on the calculator instead of the till.
  ///
  /// Fails the OPPOSITE way to [businessSizeKnown], deliberately. A stale cache that lands a
  /// calculator merchant on the normal till is harmless — an empty grid, with Riwayat still one
  /// tap away. A keypad that cannot finish a sale is not: without [openAmountVariantId] there is no
  /// variant to post a line against, so a flagged merchant whose cached catalog predates that field
  /// falls back to the till until the catalog refetches.
  bool get isCalculatorOnly => calculatorOnly && openAmountVariantId != null;

  /// High Human Interactions (specs/009): the sale is written by hand on a nota, and the app opens
  /// on the nota chat. Like [isCalculatorOnly], it also needs [openAmountVariantId] — without it a
  /// confirmed nota has no variant to post against — so a stale cache falls back to the till.
  bool get isNotaReading =>
      businessType == 'HIGH_HUMAN_INTERACTION' && openAmountVariantId != null;

  /// The merchant has no product catalog to sell from, so catalog surfaces (the product-grid till,
  /// the item manager, editing an open bill back into a cart) have nothing to show it.
  bool get sellsWithoutCatalog => isCalculatorOnly || isNotaReading;

  factory Catalog.fromJson(Map<String, dynamic> j) => Catalog(
        outletId: j['outletId'],
        outletName: j['outletName'],
        merchantName: j['merchantName'] as String?,
        // Fallbacks keep catalogs cached before these fields shipped valid.
        businessType: j['businessType'] ?? 'FNB',
        // Fails CLOSED on a stale cache: a device that hasn't refetched still prompts
        // for an approver PIN (which the server then ignores) rather than suppressing
        // one the server would still enforce.
        businessSize: j['businessSize'] ?? 'GENERAL',
        businessSizeKnown: j['businessSize'] != null,
        paymentMode: j['paymentMode'] ?? 'IMMEDIATE',
        calculatorOnly: j['calculatorOnly'] == true,
        openAmountVariantId: j['openAmountVariantId'] as String?,
        taxRule: j['taxRule'] != null ? TaxRule.fromJson(j['taxRule']) : null,
        products: ((j['products'] ?? []) as List)
            .map((p) => Product.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}

/// A variant as the ADMIN endpoints return it — same sellable unit as [Variant] but
/// carrying `costPrice`, which `GET /catalog` deliberately omits.
class AdminVariant {
  final String id;
  final String name;
  final int price;
  final int? costPrice;
  final String? sku;
  final bool isAvailable;
  final bool trackInventory;
  const AdminVariant({
    required this.id,
    required this.name,
    required this.price,
    required this.costPrice,
    required this.sku,
    required this.isAvailable,
    required this.trackInventory,
  });

  /// Margin per unit, or null when no cost has been set (which is what makes the
  /// gross-profit report read high until it is).
  int? get marginPerUnit => costPrice == null ? null : price - costPrice!;

  factory AdminVariant.fromJson(Map<String, dynamic> j) => AdminVariant(
        id: j['id'],
        name: j['name'] ?? '',
        price: _asInt(j['price']),
        costPrice: (j['costPrice'] as num?)?.toInt(),
        sku: j['sku'] as String?,
        isAvailable: j['isAvailable'] ?? true,
        trackInventory: j['trackInventory'] ?? false,
      );
}

/// A product as the admin endpoints return it (GET /admin/products).
class AdminProduct {
  final String id;
  final String name;
  final String categoryName;
  final bool isAvailable;
  final List<AdminVariant> variants;
  const AdminProduct({
    required this.id,
    required this.name,
    required this.categoryName,
    required this.isAvailable,
    required this.variants,
  });

  AdminVariant? get defaultVariant => variants.isEmpty ? null : variants.first;

  factory AdminProduct.fromJson(Map<String, dynamic> j) => AdminProduct(
        id: j['id'],
        name: j['name'] ?? '',
        categoryName: j['categoryName'] ?? '',
        isAvailable: j['isAvailable'] ?? true,
        variants: ((j['variants'] ?? []) as List)
            .map((v) => AdminVariant.fromJson(v as Map<String, dynamic>))
            .toList(),
      );
}

class PaymentResult {
  final String method;
  final int amount;
  final String status;
  final int? tendered; // cash handed over (cash payments only)
  final int? change;
  final String? qrPayload;

  /// CHARGE (the sale) or REVERSAL (a void/refund compensating record). The original charge is
  /// never rewritten — a reversal is always a new row (Constitution IV).
  final String direction;

  /// VOID or REFUND for a REVERSAL; null for a CHARGE.
  final String? reversalType;

  /// Tender-specific evidence the server stored: EDC approval code / RRN / masked PAN /
  /// scheme for a card, or the wallet reference. Display and reconciliation only.
  final Map<String, dynamic>? providerMeta;

  const PaymentResult({
    required this.method,
    required this.amount,
    required this.status,
    required this.change,
    required this.qrPayload,
    this.tendered,
    this.direction = 'CHARGE',
    this.reversalType,
    this.providerMeta,
  });

  bool get isReversal => direction == 'REVERSAL';

  /// "VISA · 4*** **** **** 1234 · CHIP" when the payment came from a card terminal.
  String? get cardSummary {
    final m = providerMeta;
    if (m == null || m['maskedPan'] == null) return null;
    return [m['scheme'], m['maskedPan'], m['entryMode']].where((x) => x != null).join(' · ');
  }

  String? get approvalCode => providerMeta?['approvalCode'] as String?;

  factory PaymentResult.fromJson(Map<String, dynamic> j) => PaymentResult(
        method: j['method'],
        amount: j['amount'],
        status: j['status'],
        change: j['change'],
        tendered: j['tendered'],
        qrPayload: j['qrPayload'],
        direction: j['direction'] ?? 'CHARGE',
        reversalType: j['reversalType'],
        providerMeta: (j['providerMeta'] as Map?)?.cast<String, dynamic>(),
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
  final String? id; // order line id — needed to refund specific lines
  final String productNameSnapshot;
  final String qty;
  final int unitPriceSnapshot;
  final int lineTotal;
  final String? variantId; // for reconstructing an open bill into the cart
  final List<String> modifierIds;
  const OrderLineResult({
    this.id,
    required this.productNameSnapshot,
    required this.qty,
    required this.unitPriceSnapshot,
    required this.lineTotal,
    this.variantId,
    this.modifierIds = const [],
  });

  double get qtyNum => double.tryParse(qty) ?? 0;

  factory OrderLineResult.fromJson(Map<String, dynamic> j) => OrderLineResult(
        id: j['id'] as String?,
        productNameSnapshot: j['productNameSnapshot'],
        qty: j['qty'].toString(),
        unitPriceSnapshot: j['unitPriceSnapshot'],
        lineTotal: j['lineTotal'],
        variantId: j['variantId'],
        modifierIds: ((j['selectedModifiersSnapshot'] ?? const []) as List)
            .map((m) => (m is Map ? m['id'] : null) as String?)
            .whereType<String>()
            .toList(),
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
  // Sales channel + online-delivery metadata (POS / null for in-store sales).
  final String channel;
  final String? onlineStatus;
  final String? externalOrderRef;
  final String? customerName;
  // Refunds: total money returned + how much of each line has been refunded.
  final int refundedAmount;
  final Map<String, double> refundedQtyByLine;
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
    this.channel = 'POS',
    this.onlineStatus,
    this.externalOrderRef,
    this.customerName,
    this.refundedAmount = 0,
    this.refundedQtyByLine = const {},
  });

  /// Derived, never stored — the server sends it and the app only displays it.
  bool get isVoided => effectiveStatus == 'VOIDED';
  bool get isRefunded => effectiveStatus == 'REFUNDED';
  bool get canBeVoided => effectiveStatus == 'COMPLETED';
  /// A completed in-store sale with money still refundable (partial refunds allowed).
  bool get canBeRefunded => effectiveStatus == 'COMPLETED' && !isOnline && refundedAmount < grandTotal;
  bool get isPartiallyRefunded => refundedAmount > 0 && !isRefunded && !isVoided;
  /// Quantity of a given line already refunded across prior refunds.
  double refundedQty(String? lineId) => lineId == null ? 0 : (refundedQtyByLine[lineId] ?? 0);

  /// Online-delivery (GoFood/GrabFood/ShopeeFood) vs an in-store POS sale.
  bool get isOnline => channel != 'POS';
  /// A just-arrived online order the cashier has not acknowledged yet.
  bool get isUnprocessed => onlineStatus == 'NEW';

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
        channel: j['channel'] ?? 'POS',
        onlineStatus: j['onlineStatus'],
        externalOrderRef: j['externalOrderRef'],
        customerName: j['customerName'],
        lines: ((j['lines'] ?? []) as List)
            .map((l) => OrderLineResult.fromJson(l as Map<String, dynamic>))
            .toList(),
        payments: ((j['payments'] ?? []) as List)
            .map((p) => PaymentResult.fromJson(p as Map<String, dynamic>))
            .toList(),
        voids: ((j['voids'] ?? []) as List)
            .map((v) => OrderVoidResult.fromJson(v as Map<String, dynamic>))
            .toList(),
        refundedAmount: (j['refundedAmount'] as num?)?.toInt() ?? 0,
        refundedQtyByLine: _refundedQty(j['refunds']),
      );
}

/// Sum refunded quantity per order line across all refund records.
/// qty may arrive as a number or a Decimal-as-string, so parse defensively.
Map<String, double> _refundedQty(dynamic refunds) {
  final map = <String, double>{};
  for (final r in (refunds ?? const []) as List) {
    for (final l in ((r as Map)['lines'] ?? const []) as List) {
      final id = (l as Map)['orderLineId'] as String?;
      if (id == null) continue;
      final q = l['qty'];
      final qd = q is num ? q.toDouble() : double.tryParse(q?.toString() ?? '') ?? 0;
      map[id] = (map[id] ?? 0) + qd;
    }
  }
  return map;
}

int _asInt(dynamic v) => (v as num?)?.toInt() ?? 0;

/// The caller's own clock-in span (from /attendance/me, clock-in, clock-out).
class AttendanceRecord {
  final String id;
  final DateTime clockInAt;
  final DateTime? clockOutAt;
  const AttendanceRecord({required this.id, required this.clockInAt, this.clockOutAt});
  bool get open => clockOutAt == null;

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        id: j['id'] as String,
        clockInAt: DateTime.parse(j['clockInAt'] as String).toLocal(),
        clockOutAt:
            j['clockOutAt'] == null ? null : DateTime.parse(j['clockOutAt'] as String).toLocal(),
      );
}

/// One attendance row in the owner/manager report.
class AttendanceRow {
  final String staffName;
  final String role;
  final DateTime clockInAt;
  final DateTime? clockOutAt;
  final int? minutes;
  final bool open;
  const AttendanceRow({
    required this.staffName,
    required this.role,
    required this.clockInAt,
    required this.clockOutAt,
    required this.minutes,
    required this.open,
  });

  factory AttendanceRow.fromJson(Map<String, dynamic> j) => AttendanceRow(
        staffName: j['staffName'] as String,
        role: j['role'] as String,
        clockInAt: DateTime.parse(j['clockInAt'] as String).toLocal(),
        clockOutAt:
            j['clockOutAt'] == null ? null : DateTime.parse(j['clockOutAt'] as String).toLocal(),
        minutes: (j['minutes'] as num?)?.toInt(),
        open: j['open'] as bool? ?? false,
      );
}

/// Owner/manager sales summary from GET /admin/dashboard (merchant-wide).
class DashboardSummary {
  final int netSales;
  final int orderCount;
  final int avgTicket;
  final String? from;
  final String? to;
  final List<({String method, int amount})> paymentBreakdown;
  final List<({String name, int sales, int count})> byOutlet;
  final List<({String name, int qty, int sales})> topItems;
  final List<({String day, int sales})> salesByDay;

  /// Gross margin. Revenue here EXCLUDES tax and service charge (unlike [netSales]),
  /// so the margin is not inflated for a merchant that charges them.
  final int netRevenue;
  final int cogs;
  final int grossProfit;
  final int grossMarginBps;

  /// Sales lines with no cost price: they contribute 0 COGS, so profit reads high
  /// until they're filled in. Surfaced in the UI, never swallowed.
  final int linesMissingCost;
  final List<String> itemsMissingCost;

  const DashboardSummary({
    required this.netSales,
    required this.orderCount,
    required this.avgTicket,
    required this.from,
    required this.to,
    required this.paymentBreakdown,
    required this.byOutlet,
    required this.topItems,
    required this.salesByDay,
    this.netRevenue = 0,
    this.cogs = 0,
    this.grossProfit = 0,
    this.grossMarginBps = 0,
    this.linesMissingCost = 0,
    this.itemsMissingCost = const [],
  });

  /// A margin can only be shown once there is revenue to measure it against.
  bool get hasProfitData => netRevenue > 0;

  factory DashboardSummary.fromJson(Map<String, dynamic> j) {
    final range = j['range'] as Map<String, dynamic>?;
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        ((j[key] ?? []) as List).map((e) => f(e as Map<String, dynamic>)).toList();
    return DashboardSummary(
      netSales: _asInt(j['netSales']),
      orderCount: _asInt(j['orderCount']),
      avgTicket: _asInt(j['avgTicket']),
      from: range?['from'] as String?,
      to: range?['to'] as String?,
      paymentBreakdown:
          list('paymentBreakdown', (e) => (method: e['method'] as String, amount: _asInt(e['amount']))),
      byOutlet: list('byOutlet',
          (e) => (name: e['name'] as String, sales: _asInt(e['sales']), count: _asInt(e['count']))),
      topItems: list('topItems',
          (e) => (name: e['name'] as String, qty: _asInt(e['qty']), sales: _asInt(e['sales']))),
      salesByDay: list('salesByDay', (e) => (day: e['day'] as String, sales: _asInt(e['sales']))),
      // Defaulted, so an app built against a newer server still decodes an older
      // server's response instead of crashing (same discipline as businessType).
      netRevenue: _asInt(j['netRevenue']),
      cogs: _asInt(j['cogs']),
      grossProfit: _asInt(j['grossProfit']),
      grossMarginBps: _asInt(j['grossMarginBps']),
      linesMissingCost: _asInt((j['costCoverage'] ?? const {})['linesMissingCost']),
      itemsMissingCost:
          (((j['costCoverage'] ?? const {})['itemsMissingCost'] ?? const []) as List)
              .map((e) => e.toString())
              .toList(),
    );
  }
}
